"""Fit the modular eyes and their moving lids to the prepared face (pack 10 -> 15)."""

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
from scipy.interpolate import PchipInterpolator
from scipy.spatial import cKDTree

REFERENCE = (
    Path(__file__).resolve().parents[2]
    / "assets/avatar/approved/face-2026-10-29/source-surface.npz"
)


def smooth(t):
    t = np.clip(t, 0, 1)
    return t * t * (3 - 2 * t)


# Distances along the model's +Z axis, in metres. The lids need to travel
# over the painted iris even at half blink; keep the whole stack close to skin.
WHITE_DEPTH = 0.00085
IRIS_DEPTH = 0.00175
LID_DEPTH = 0.00255
LASH_DEPTH = 0.00330


def fair_sockets(p, n, triangles):
    """Resurface the painted eye inside its orbit, preserving the surrounding head."""
    original = Surface(p, n, triangles)
    # Fill a local elliptical hole using its perimeter depth and radial slope.
    # The biharmonic disk solution interpolates both without copying the old
    # painted-eye relief into the transition at the cheek or temple.
    rx, ry = 0.037, 0.0345
    cx, cy = 0.0525, 0.7945
    tilt = 0.11
    samples = 128
    angle = 2 * np.pi * np.arange(samples) / samples
    ring = np.column_stack([rx * np.cos(angle), ry * np.sin(angle)])
    ring[:, 1] += tilt * ring[:, 0]

    modes = np.arange(9)

    def harmonics(values):
        coefficients = np.fft.rfft(values)[modes] / samples
        coefficients[1:] *= 2
        return coefficients

    q, nn = p.copy(), n.copy()
    for side in (-1, 1):
        boundary = (ring + [cx, cy]) * [side, 1]
        depth, normal = original.sample(boundary)
        radial_slope = -np.sum(normal[:, :2] * ring * [side, 1], axis=1) / normal[:, 2]
        # For each harmonic k the regular radial solution is (a + b*r²)*r^k.
        # Retain the broad cranial shape while filtering individual facets.
        g = harmonics(depth)
        b = (harmonics(radial_slope) - modes * g) / 2
        a = g - b
        # Preserve the established eye-seat depth at the centre. The correction
        # and its first derivative vanish at the junction with the original skin.
        centre_offset = 0.0908 - a[0].real

        def patch(x, y):
            z = (x + 1j * y)[:, None]
            r2 = x*x + y*y
            interpolated = np.real(np.sum(z**modes * (a + r2[:, None]*b), axis=1))
            return interpolated + centre_offset * (1-r2)**2

        x = (side*p[:, 0] - cx) / rx
        y = (p[:, 1] - cy - tilt*(side*p[:, 0]-cx)) / ry
        r = np.hypot(x, y)
        selected = (r < 1) & (p[:, 2] > 0.036)
        x, y, r = x[selected], y[selected], r[selected]
        t = np.clip((1-r) / 0.18, 0, 1)
        w = t*t*t*(10 - 15*t + 6*t*t)
        dw = -30*t*t*(1-t)**2 / (0.18*np.maximum(r, 1e-8))
        dz = patch(x, y) - p[selected, 2]
        q[selected, 2] += w*dz
        # Include the falloff derivative so grazing light follows the surface.
        eps = 0.0001
        dx = (patch(x + eps, y) - patch(x - eps, y)) / (2 * eps)
        dy = (patch(x, y + eps) - patch(x, y - eps)) / (2 * eps)
        dx = (w*dx + dz*dw*x) / rx
        dy = 1/ry * (w*dy + dz*dw*y)
        dx = side * (dx - tilt*dy)
        normal = n[selected].copy()
        normal[:, :2] = (1-w[:, None])*normal[:, :2] - normal[:, 2:] * np.column_stack([dx, dy])
        nn[selected] = normal / np.linalg.norm(normal, axis=1)[:, None]
    return q, nn


class Aperture:
    """One upper and lower edge shared by the white, lash and both lids."""

    def __init__(self, white, faces, style):
        self.style = style
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
        # Preserve the authored lid attitude of each variant. Grade the arch
        # against the outer and inner corners, rather than stretching the iris
        # to fill its white. The profile comes from the approved neutral drawing.
        self.openness = np.clip((tops.max() - 0.795) / 0.017, 0, 1)
        self.tilt = np.clip((tops[-3] - tops[2]) / 0.011, -0.7, 0.7)
        self.shape_x = np.array([0, 0.1, 0.25, 0.43, 0.62, 0.8, 0.92, 1])
        self.top = PchipInterpolator(
            self.shape_x, [0, 0.13, 0.28, 0.365, 0.395, 0.34, 0.27, 0.18]
        )
        self.bottom = PchipInterpolator(
            self.shape_x, [0, -0.115, -0.184, -0.205, -0.172, -0.085, 0.048, 0.18]
        )

    def eye_x(self, x):
        return 0.022 + (x - self.left) * (0.054 / (self.right - self.left))

    def edges(self, x):
        u = np.clip((x - self.left) / (self.right - self.left), 0, 1)
        chord = 0.791 + 0.004 * self.tilt * (u - 0.5)
        bow = np.sin(np.pi * u)
        top = chord + 0.057 * self.top(u) - (0.013 * (1 - self.openness)) * bow
        if self.style == "round":
            top += 0.0012 * bow**2
        bottom = chord + 0.057 * self.bottom(u) + 0.002 * (1 - self.openness) * bow
        return bottom, top

    def fit(self, p, part):
        q = p.copy()
        x = abs(p[:, 0])
        q[:, 0] = np.sign(p[:, 0]) * self.eye_x(x)
        lo, hi = self.edges(x)
        old_lo = np.interp(x, self.x, self.low)
        old_hi = np.interp(x, self.x, self.high)
        if part == "iris":
            # Keep the round pupil and painted glints rigid through every blink.
            q[:, 0] = np.sign(p[:, 0]) * (0.045 + 0.85 * (x - 0.053))
            q[:, 1] = 0.7975 + 0.90 * (p[:, 1] - 0.786)
        else:
            height = old_hi - old_lo
            t = np.clip((p[:, 1] - old_lo) / np.maximum(height, 0.00001), 0, 1)
            q[:, 1] = lo + (hi - lo) * t + p[:, 1] - np.clip(p[:, 1], old_lo, old_hi)
        return q


def fit_lash(builder, mesh, aperture, surface, material, joint, wing):
    """Draw both contour strokes along the opening, tapering down to each corner."""
    u = np.linspace(0, 1, 65)
    x = aperture.left + u * (aperture.right - aperture.left)
    lo, hi = aperture.edges(x)
    seam = lo + 0.28 * (hi - lo)
    taper = np.sin(np.pi * u) ** 0.65
    upper_width = (0.0020 + 0.0065 * u) * taper + 0.0024 * smooth((u - 0.65) / 0.30)
    lower_width = (0.00027 + 0.00025 * u) * taper
    faces = []

    def pose(control):
        vertices = []
        for side in [-1, 1]:
            for upper in [True, False]:
                edge = hi if upper else lo
                width = upper_width if upper else lower_width
                edge = edge.copy()
                width = width.copy()
                xx = aperture.eye_x(x)
                if control == "eyes_closed":
                    edge = seam.copy()
                    width *= 0.48 if upper else 0.06
                if control in ("eyes_soft", "eyes_wide"):
                    edge += (edge - 0.797) * (-0.18 if control == "eyes_soft" else 0.12)
                if upper:
                    # A single brush-like flick inherits each style's original lash length.
                    xx = np.r_[xx, xx[-1] + 0.0017 + wing]
                    edge = np.r_[edge, edge[-1] + 0.0008 + wing * 0.50]
                    width = np.r_[width, 0.0]
                low = edge - width * (0.48 if upper else 0.85)
                high = low + width
                points = np.c_[
                    np.repeat(side * xx, 2),
                    np.stack([low, high], axis=1).ravel(),
                    np.zeros(len(xx) * 2),
                ].astype("<f4")
                if control in ("eyes_hearts", "eyes_squeezed", "eyes_shocked"):
                    points[:, 0] = side * 0.044
                    points[:, 1] = 0.797
                if control is None:
                    start = sum(len(p) for p in vertices)
                    for i in range(0, len(points) - 2, 2):
                        a = start + i
                        pair = [[a, a + 2, a + 1], [a + 2, a + 3, a + 1]]
                        if side < 0:
                            pair = [tri[::-1] for tri in pair]
                        faces.extend(pair)
                vertices.append(points)
        return surface.fit(np.concatenate(vertices), LASH_DEPTH)

    p, n = pose(None)
    closed_p, closed_n = pose("eyes_closed")
    zeros = np.zeros((len(p), 4), dtype="<u2")
    zeros[:, 0] = joint
    weights = np.zeros((len(p), 4), dtype="<f4")
    weights[:, 0] = 1
    prim = {
        "material": material,
        "indices": builder.acc(np.array(faces, dtype="<u4").ravel()),
        "attributes": {
            "POSITION": builder.acc(p),
            "NORMAL": builder.acc(n),
            "JOINTS_0": builder.acc(zeros),
            "WEIGHTS_0": builder.acc(weights),
        },
        "targets": [],
    }
    for name in mesh["extras"]["targetNames"]:
        if name.startswith("brow"):
            q, nn = p, n
        elif name == "eyes_half":
            q, nn = p + 0.53 * (closed_p - p), n + 0.53 * (closed_n - n)
        elif name == "eyes_closed":
            q, nn = closed_p, closed_n
        else:
            q, nn = pose(name)
        prim["targets"].append(
            {
                "POSITION": builder.acc(q - p, sparse=True),
                "NORMAL": builder.acc(nn - n, sparse=True),
            }
        )
    mesh["primitives"] = [prim]


def add_lids(builder, mesh, aperture, surface, colours, material, joint, manifest):
    # Roll the fixed edge into the surrounding skin. Keep this transition
    # narrow even at full closure so the iris cannot poke through the fold.
    t = np.linspace(0.0, 1.0, 17)
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
            x = aperture.eye_x(xx)
            opened = hi + 0.0001 if upper else lo - 0.0002
            edge = opened + (0.012 if upper else -0.009)
            depth = -0.00025 + (LID_DEPTH + 0.00025) * smooth(t / 0.20)
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
        color = builder.acc(colours(p))
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
    for material in b.g["materials"]:
        if material.get("name") == "Eye white":
            material["pbrMetallicRoughness"]["baseColorFactor"] = [0.79, 0.75, 0.70, 1]
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
            out[:, 0] = np.sign(pts[:, 0]) * aperture.eye_x(abs(pts[:, 0]))
            out[:, 1] += -0.004 if part == "brow" else 0.009
        else:
            out = aperture.fit(pts, part)
        if part == "reactions":
            old_depth, _ = old_surface.sample(pts)
            offset = pts[:, 2] - old_depth
        else:
            offset = {
                "white": WHITE_DEPTH,
                "iris": IRIS_DEPTH,
                "rim": LASH_DEPTH,
                "brow": 0.003,
            }[part]
        return surface.fit(out, offset)

    done = set()
    # +Z is forward and +X points right in the frontal camera.
    gaze = {"gaze_left": (-0.004, 0), "gaze_right": (0.004, 0),
            "gaze_up": (0, 0.0025), "gaze_down": (0, -0.0025)}
    b.g["extras"]["trainerFace"]["controls"].extend(gaze)
    for style, nodes in manifest["eyeNodes"].items():
        parts = {
            b.g["nodes"][i]["name"].rsplit("-", 1)[-1]: b.g["nodes"][i]["mesh"]
            for i in nodes
        }
        white_points, white_faces = [], []
        for prim in b.g["meshes"][parts["white"]]["primitives"]:
            start = sum(len(points) for points in white_points)
            white_faces.append(start + model.acc(prim["indices"]).reshape(-1, 3))
            white_points.append(model.acc(prim["attributes"]["POSITION"]))
        aperture = Aperture(np.concatenate(white_points), np.concatenate(white_faces), style)
        for part, mesh_id in parts.items():
            if mesh_id in done:
                continue
            done.add(mesh_id)
            mesh = b.g["meshes"][mesh_id]
            if part == "rim":
                original_rim = mesh["primitives"][0]
                joint = int(model.acc(original_rim["attributes"]["JOINTS_0"])[0, 0])
                wing = max(
                    0.0,
                    abs(model.acc(original_rim["attributes"]["POSITION"])[:, 0]).max()
                    - aperture.right,
                )
                fit_lash(
                    b,
                    mesh,
                    aperture,
                    surface,
                    original_rim["material"],
                    joint,
                    wing * 0.75 if style != "almond" else wing * 0.30 - 0.0007,
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
                continue
            for prim in mesh["primitives"]:
                orig = model.acc(prim["attributes"]["POSITION"])

                moved, norm = relocate(orig, part, aperture)
                prim["attributes"].update(POSITION=b.acc(moved), NORMAL=b.acc(norm))
                for name, target in zip(mesh["extras"]["targetNames"], prim["targets"]):
                    if name in ("eyes_closed", "eyes_half") and part != "brow":
                        posed, pn = moved.copy(), norm
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
                if part == "iris":
                    for dx, dy in gaze.values():
                        shifted = moved.copy()
                        shifted[:, 0] += dx
                        shifted[:, 1] += dy
                        posed, pn = surface.fit(shifted, IRIS_DEPTH)
                        prim["targets"].append({
                            "POSITION": b.acc(posed - moved, sparse=True),
                            "NORMAL": b.acc(pn - norm, sparse=True),
                        })
            if part == "iris":
                mesh["extras"]["targetNames"].extend(gaze)
                mesh["weights"].extend([0.0] * len(gaze))
    with tempfile.TemporaryDirectory(dir=destination.parent) as scratch:
        folder = Path(scratch)
        shutil.copytree(source, folder / "pack")
        b.save(folder / "working.glb")
        template = folder / "pack/template.glb"
        compact(GLB(folder / "working.glb"), manifest, template)
        manifest["revision"] = 15
        manifest["eyeHeight"] += 0.012
        manifest["faceSurface"]["eyePlacement"] = "bounded-orbit-2"
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
