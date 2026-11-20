"""Fit the modular eyes and their moving lids to the prepared face (pack 10 -> 11)."""

import argparse
import copy
import hashlib
import json
import shutil
import tempfile
from pathlib import Path

import numpy as np
from build_pack import GLB, Builder
from package_face_bridge import compact
from restore_painted_face import Surface
from scipy.interpolate import CubicSpline, PchipInterpolator
from scipy.spatial import cKDTree

REFERENCE = (
    Path(__file__).resolve().parents[2]
    / "assets/avatar/approved/face-2026-10-29/source-surface.npz"
)


def smooth(t):
    t = np.clip(t, 0, 1)
    return t * t * (3 - 2 * t)


def fair_sockets(p, n, triangles):
    """Blend cheek to brow where the old painted eye had a raised oval."""
    original = Surface(p, n, triangles)
    x, y, z = p.T
    w = (
        smooth((abs(x) - 0.007) / 0.013)
        * smooth((0.097 - abs(x)) / 0.013)
        * smooth((y - 0.748) / 0.016)
        * smooth((0.833 - y) / 0.014)
        * (z > 0.036)
    )
    # Sample the approved cheek and forehead either side of the obsolete relief.
    # Use the same mirrored sweep on both sides and ease into untouched skin.
    xs = np.linspace(0.002, 0.087, 18)
    curves = []
    for level in [0.757, 0.826]:
        depths = [
            original.sample(np.c_[side * xs, np.full_like(xs, level)])[0]
            for side in [-1, 1]
        ]
        curves.append(CubicSpline(xs, np.mean(depths, axis=0), bc_type="natural"))
    selected = w > 0
    xx, yy = abs(x[selected]), y[selected]
    t = (yy - 0.757) / (0.826 - 0.757)
    lower, upper = curves
    depth = lower(xx) * (1 - t) + upper(xx) * t
    dx = (lower(xx, 1) * (1 - t) + upper(xx, 1) * t) * np.sign(x[selected])
    dy = (upper(xx) - lower(xx)) / (0.826 - 0.757)
    normal = np.stack([-dx, -dy, np.ones_like(dx)], axis=1)
    normal /= np.linalg.norm(normal, axis=1)[:, None]
    q, nn = p.copy(), n.copy()
    weight = w[selected]
    q[selected, 2] += weight * (depth - z[selected])
    nn[selected] += weight[:, None] * (normal - n[selected])
    nn[selected] /= np.linalg.norm(nn[selected], axis=1)[:, None]
    return q, nn


class Aperture:
    """One upper and lower edge shared by the white, lash and both lids."""

    def __init__(self, white, faces):
        w = white[white[:, 0] > 0]
        self.left, self.right = w[:, 0].min(), w[:, 0].max()
        # Sample the actual triangle edges. A vertex at a given X can belong
        # to the hole for the iris, so its Y alone is not a silhouette sample.
        tris = white[faces]
        edges = tris[:, [0, 1, 1, 2, 2, 0]].reshape(-1, 2, 3)
        left, right = edges[:, 0], edges[:, 1]
        span = right[:, 0] - left[:, 0]
        nonvertical = abs(span) > 1e-9
        self.x = np.linspace(self.left, self.right, 193)
        low, high = [], []
        for x in self.x:
            hits = (
                nonvertical
                & (np.minimum(left[:, 0], right[:, 0]) <= x + 1e-8)
                & (np.maximum(left[:, 0], right[:, 0]) >= x - 1e-8)
            )
            y = (
                left[hits, 1]
                + (x - left[hits, 0]) * (right[hits, 1] - left[hits, 1]) / span[hits]
            )
            if len(y):
                low.append(y.min())
                high.append(y.max())
            else:
                low.append(np.nan)
                high.append(np.nan)
        valid = np.isfinite(low)
        assert valid.mean() > 0.95, "Incomplete white silhouette"
        self.low = np.interp(self.x, self.x[valid], np.asarray(low)[valid])
        self.high = np.interp(self.x, self.x[valid], np.asarray(high)[valid])
        # The cut-out artwork has short vertical runs at the corners. Retain
        # the individual upper arch, sampling across the cut-out rather than
        # allowing individual cut triangles to produce a jagged outline.
        stations = np.linspace(0, 1, 15)
        u = (w[:, 0] - self.left) / (self.right - self.left)
        tops = np.array([w[abs(u - v) < 0.025, 1].max() for v in stations])
        tips = np.array([np.median(w[abs(u - v) < 0.008, 1]) for v in [0, 1]])
        tips = np.maximum(tips, [0.782, 0.786])
        tops[[0, -1]] = tips
        self.upper = PchipInterpolator(stations, tops)
        self.tips = tips
        self.floor = self.low.min() + 0.006

    def edges(self, x):
        u = np.clip((x - self.left) / (self.right - self.left), 0, 1)
        lift = 0.011 + 0.003 * u
        lo = self.floor + (self.tips[0] - self.floor) * np.maximum(1 - u / 0.30, 0) ** 2
        lo += (self.tips[1] - self.floor) * np.maximum((u - 0.68) / 0.32, 0) ** 2
        hi = np.maximum(self.upper(u), lo)
        return lo + lift, hi + lift

    def fit(self, p, part):
        q = p.copy()
        x = abs(p[:, 0])
        q[:, 0] *= 0.80
        lo, hi = self.edges(x)
        old_lo = np.interp(x, self.x, self.low)
        old_hi = np.interp(x, self.x, self.high)
        if part == "iris":
            # Keep the round pupil and painted glints rigid through every blink.
            q[:, 1] = p[:, 1] + 0.016
        else:
            height = old_hi - old_lo
            t = np.clip((p[:, 1] - old_lo) / np.maximum(height, 0.00001), 0, 1)
            q[:, 1] = lo + (hi - lo) * t + p[:, 1] - np.clip(p[:, 1], old_lo, old_hi)
        return q


def add_lids(builder, mesh, aperture, surface, colours, material, joint, manifest):
    # Roll the fixed edge into the surrounding skin. Keep this transition
    # narrow even at full closure so the iris cannot poke through the fold.
    t = np.array([0.0, 0.06, 0.18, 0.35, 0.55, 0.78, 1.0])
    rows = len(t)
    xx = np.r_[
        aperture.left - 0.005,
        np.linspace(aperture.left, aperture.right, 65),
        aperture.right + 0.005,
    ]
    lo, hi = aperture.edges(xx)
    seam = lo + 0.28 * (hi - lo)

    def strip(edge, inner, x, depth):
        ys = edge[:, None] + (inner - edge)[:, None] * t
        xy = np.c_[np.repeat(x, rows), ys.ravel(), np.zeros(ys.size)].astype("<f4")
        return surface.fit(xy, np.tile(depth, len(x)))

    for upper in [True, False]:
        base, closed, normals, closed_normals, indices = [], [], [], [], []
        retracted = []
        for side in [-1, 1]:
            # Slight overlap around the perimeter prevents a white fringe in profile.
            x = 0.8 * xx
            opened = hi + 0.0001 if upper else lo - 0.0002
            edge = opened + (0.012 if upper else -0.009)
            depth = -0.0004 + 0.0042 * smooth(t / 0.06)
            end = seam - 0.00035 if upper else seam + 0.00035

            p, n = strip(edge, opened, side * x, depth)
            q, nn = strip(edge, end, side * x, depth)
            start = sum(len(a) for a in base)
            for col in range(len(x) - 1):
                for row in range(rows - 1):
                    a = start + col * rows + row
                    pair = [[a, a + rows, a + 1], [a + 1, a + rows, a + rows + 1]]
                    if (side > 0) == upper:
                        pair = [tri[::-1] for tri in pair]
                    indices.extend(pair)
            retracted.append(strip(edge, edge, side * x, depth)[0])
            base.append(p)
            closed.append(q)
            normals.append(n)
            closed_normals.append(nn)
        p, q, n, nn = map(np.concatenate, [base, closed, normals, closed_normals])
        joints = np.zeros((len(p), 4), dtype="<u2")
        joints[:, 0] = joint
        weights = np.zeros((len(p), 4), dtype="<f4")
        weights[:, 0] = 1
        color = builder.acc(colours(q))
        manifest["vertexPalette"].append(
            dict(manifest["vertexPalette"][0], accessor=color)
        )
        attrs = {
            "POSITION": builder.acc(p),
            "NORMAL": builder.acc(n),
            "COLOR_0": color,
            "JOINTS_0": builder.acc(joints),
            "WEIGHTS_0": builder.acc(weights),
        }
        prim = {
            "attributes": attrs,
            "indices": builder.acc(np.asarray(indices, dtype="<u4").ravel()),
            "material": material,
            "targets": [],
        }
        for control in mesh["extras"]["targetNames"]:
            amount = {"eyes_closed": 1.0, "eyes_half": 0.53}.get(control, 0.0)
            delta = (q - p) * amount
            if control in (
                "eyes_squeezed",
                "eyes_hearts",
                "eyes_shocked",
                "eyes_wide",
                "eyes_soft",
            ):
                delta = np.concatenate(retracted) - p
            prim["targets"].append(
                {
                    "POSITION": builder.acc(delta, sparse=True),
                    "NORMAL": builder.acc((nn - n) * amount, sparse=True),
                }
            )
        mesh["primitives"].append(prim)


def build(source, destination):
    manifest = json.loads((source / "manifest.json").read_text())
    assert manifest["revision"] == 10 and not destination.exists()
    model = GLB(source / "template.glb")
    b = Builder.__new__(Builder)
    b.g = copy.deepcopy(model.g)
    b.b = bytearray(model.b)
    body = b.g["meshes"][manifest["preparedBodyMesh"]]["primitives"]
    a = body[0]["attributes"]
    p, n = (model.acc(a[k]) for k in ["POSITION", "NORMAL"])
    triangles = np.load(REFERENCE)["indices"].reshape(-1, 3)
    old_surface = Surface(p, n, triangles)
    q, nn = fair_sockets(p, n, triangles)
    surface = Surface(q, nn, triangles)
    position, normal = b.acc(q), b.acc(nn)
    for prim in body:
        prim["attributes"].update(POSITION=position, NORMAL=normal)
    skin = body[1]
    ids = np.unique(model.acc(skin["indices"]))
    ids = ids[(q[ids, 2] > 0.04) & (q[ids, 1] > 0.745) & (q[ids, 1] < 0.85)]
    tree = cKDTree(q[ids, :2])
    skin_colours = model.acc(skin["attributes"]["COLOR_0"])[ids]

    def colours(verts):
        dist, near = tree.query(verts[:, :2], k=4)
        weights = 1 / np.maximum(dist, 0.00001)
        return np.average(
            skin_colours[near],
            axis=1,
            weights=np.repeat(weights[:, :, None], 4, axis=2),
        ).astype("<f4")

    def relocate(pts, part, aperture):
        if part in ("brow", "reactions"):
            out = pts.copy()
            out[:, 0] *= 0.80
            out[:, 1] += 0.012
        else:
            out = aperture.fit(pts, part)
        if part == "reactions":
            old_depth, _ = old_surface.sample(pts)
            offset = pts[:, 2] - old_depth
        else:
            offset = {
                "white": 0.0012,
                "iris": 0.0025,
                "rim": 0.0043,
                "brow": 0.003,
            }[part]
        return surface.fit(out, offset)

    done = set()
    for nodes in manifest["eyeNodes"].values():
        parts = {
            b.g["nodes"][i]["name"].rsplit("-", 1)[-1]: b.g["nodes"][i]["mesh"]
            for i in nodes
        }
        white_points, white_faces = [], []
        for prim in b.g["meshes"][parts["white"]]["primitives"]:
            start = sum(len(points) for points in white_points)
            white_faces.append(start + model.acc(prim["indices"]).reshape(-1, 3))
            white_points.append(model.acc(prim["attributes"]["POSITION"]))
        aperture = Aperture(np.concatenate(white_points), np.concatenate(white_faces))
        for part, mesh_id in parts.items():
            if mesh_id in done:
                continue
            done.add(mesh_id)
            mesh = b.g["meshes"][mesh_id]
            for prim in mesh["primitives"]:
                orig = model.acc(prim["attributes"]["POSITION"])

                moved, norm = relocate(orig, part, aperture)
                prim["attributes"].update(POSITION=b.acc(moved), NORMAL=b.acc(norm))
                for name, target in zip(mesh["extras"]["targetNames"], prim["targets"]):
                    if name in ("eyes_closed", "eyes_half") and part != "brow":
                        posed, pn = moved.copy(), norm
                        if part == "rim":
                            x = abs(orig[:, 0])
                            lo, hi = aperture.edges(x)
                            upper = moved[:, 1] > (lo + hi) / 2
                            edge = np.where(upper, hi, lo)
                            posed[:, 1] += lo + 0.28 * (hi - lo) - edge
                            posed, pn = surface.fit(posed, 0.0047)
                        amount = 0.53 if name == "eyes_half" else 1.0
                        delta = (posed - moved) * amount
                        dn = (pn - norm) * amount
                    else:
                        old_delta = model.acc(target["POSITION"])
                        posed, pn = relocate(orig + old_delta, part, aperture)
                        delta = posed - moved
                        dn = pn - norm
                    target.update(
                        POSITION=b.acc(delta, sparse=True),
                        NORMAL=b.acc(dn, sparse=True),
                    )
            if part == "rim":
                joint = int(
                    model.acc(mesh["primitives"][0]["attributes"]["JOINTS_0"])[0, 0]
                )
                add_lids(
                    b,
                    mesh,
                    aperture,
                    surface,
                    colours,
                    skin["material"],
                    joint,
                    manifest,
                )
    with tempfile.TemporaryDirectory(dir=destination.parent) as scratch:
        folder = Path(scratch)
        shutil.copytree(source, folder / "pack")
        b.save(folder / "working.glb")
        template = folder / "pack/template.glb"
        compact(GLB(folder / "working.glb"), manifest, template)
        manifest["revision"] = 11
        manifest["eyeHeight"] += 0.012
        manifest["faceSurface"]["eyePlacement"] = "fitted-aperture-1"
        manifest["files"]["template.glb"] = hashlib.sha256(
            template.read_bytes()
        ).hexdigest()
        (folder / "pack/manifest.json").write_text(
            json.dumps(manifest, indent=2) + "\n"
        )
        (folder / "pack").rename(destination)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("destination", type=Path)
    args = parser.parse_args()
    build(args.source, args.destination)
