#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Bake the original Ship Home exterior. Metres, +Y up, bow toward -Z."""

import itertools
import json
import struct
from collections import defaultdict
from math import cos, pi, sin, sqrt, tau
from pathlib import Path

OUTPUT = Path(__file__).resolve().parents[2] / "experiences/ship-home/assets/ship/saucer.glb"
surfaces = defaultdict(list)
# sRGB paint, metallic, roughness, emission strength
finishes = {
    "Ceramic": ("e7d9b7", 0.28, 0.40, 0),
    "Champagne": ("c3ad81", 0.56, 0.34, 0),
    "Sea green": ("22696a", 0.39, 0.31, 0),
    "Deep enamel": ("233c47", 0.44, 0.38, 0),
    "Copper": ("cb8054", 0.60, 0.30, 0),
    "Heat shield": ("4e5c62", 0.46, 0.50, 0),
    "Canopy": ("244c65", 0.36, 0.20, 0.12),
    "Glass reflection": ("508596", 0.38, 0.25, 0.15),
    "Running lights": ("ffc680", 0.06, 0.28, 0.90),
    "Ion ceramic": ("83e6d3", 0.12, 0.23, 0.92),
}


def minus(a, b):
    return tuple(x - y for x, y in zip(a, b))


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def unit(v):
    length = sqrt(sum(x * x for x in v))
    return tuple(x / length for x in v)


def ring(rx, rz, y, z=0.26, x=0):
    return rx, rz, y, z, x


def point(row, a):
    rx, rz, y, z, x = row
    return (x + rx * sin(a), y, z - rz * cos(a))


def loft(rows, colors, start=0, end=tau, steps=96):
    """Smooth oval profiles. Row order runs from the underside to the roof."""
    rings = []
    for i, row in enumerate(rows):
        strip = []
        for j in range(steps + 1):
            a = start + (end - start) * j / steps
            tangent = (row[0] * cos(a), 0, row[1] * sin(a))
            slope = minus(point(rows[min(i + 1, len(rows) - 1)], a), point(rows[max(0, i - 1)], a))
            strip.append((point(row, a), unit(cross(slope, tangent))))
        rings.append(strip)
    for i, (low, high) in enumerate(itertools.pairwise(rings)):
        surface = surfaces[colors[i]]
        for j in range(steps):
            surface.extend((low[j], high[j], high[j + 1], low[j], high[j + 1], low[j + 1]))


def patch(rows, paint, start, span, steps):
    loft(rows, [paint] * (len(rows) - 1), start, start + span, steps)


def hull():
    # An open, lined shaft joins the physical dock lift at (0.56, -2.65, 1.14).
    rows = [
        ring(0.81, 0.81, -0.82, 1.14, 0.56),
        ring(0.81, 0.81, -2.68, 1.14, 0.56),
        ring(0.90, 0.90, -2.74, 1.14, 0.56),
        ring(1.48, 1.40, -2.66, 1.0, 0.33),
        ring(2.68, 2.90, -2.45, 0.66),
        ring(3.34, 3.60, -1.96, 0.46),
        ring(4.57, 4.77, -1.42),
        ring(5.80, 5.97, -1.07),
        ring(6.22, 6.38, -0.84),
        ring(6.37, 6.53, -0.66),
        ring(6.39, 6.55, -0.51),
        ring(6.34, 6.50, -0.42),
        ring(6.25, 6.41, -0.35),
        ring(5.96, 6.12, -0.25),
        ring(4.52, 4.88, 0.12),
        ring(3.20, 3.72, 0.33),
        ring(1.58, 2.18, 0.45),
        ring(0.001, 0.001, 0.47),
    ]
    loft(
        rows,
        [
            "Deep enamel",
            "Copper",
            "Deep enamel",
            "Heat shield",
            "Sea green",
            "Ceramic",
            "Champagne",
            "Sea green",
            "Deep enamel",
            "Deep enamel",
            "Copper",
            "Ceramic",
            "Ceramic",
            "Ceramic",
            "Champagne",
            "Ceramic",
            "Ceramic",
        ],
    )
    for i in range(24):
        a = i * tau / 24
        # Recessed belt, lit position markers and copper joints.
        patch(
            [ring(6.388, 6.548, -0.619), ring(6.402, 6.562, -0.567)],
            "Ion ceramic" if i % 6 else "Running lights",
            a + 0.032,
            0.166,
            6,
        )
        patch([ring(6.38, 6.54, -0.638), ring(6.39, 6.55, -0.525)], "Copper", a + 0.228, 0.018, 2)
    for i in range(12):
        a = i * tau / 12
        patch(
            [ring(3.27, 3.79, 0.324), ring(4.52, 4.88, 0.136), ring(5.90, 6.06, -0.22)][::-1],
            "Champagne",
            a,
            0.013,
            2,
        )
        # Each underside petal has a turbine bay separated by a painted reveal.
        patch(
            [ring(2.7, 2.92, -2.465, 0.66), ring(3.36, 3.62, -1.977, 0.46), ring(4.46, 4.67, -1.48)],
            "Deep enamel",
            a + 0.012,
            0.038,
            3,
        )
        patch([ring(4.68, 4.88, -1.408), ring(5.65, 5.83, -1.136)], "Sea green", a + 0.055, 0.24, 7)
        patch([ring(5.06, 5.26, -1.31), ring(5.48, 5.67, -1.19)], "Copper", a + 0.31, 0.025, 2)


def triangle(paint, a, b, c):
    normal = unit(cross(minus(b, a), minus(c, a)))
    surfaces[paint].extend(((a, normal), (b, normal), (c, normal)))


def dorsal_markings():
    # Long tapered shoulder flashes sweep aft as they approach the rim.
    rows = [ring(3.18, 3.70, 0.353), ring(4.52, 4.88, 0.148), ring(5.93, 6.09, -0.212)]
    for side in (-1, 1):
        for outset, width, paint in ((0, 0.32, "Sea green"), (0.39, 0.042, "Copper")):
            bands = []
            for row, angle, taper in zip(rows, (0.62, 0.91, 1.31), (1, 1, 0.63)):
                bands.append(
                    [point(row, side * (angle + outset + width * taper * j / 16)) for j in range(17)]
                )
            for inner, outer in itertools.pairwise(bands):
                for j in range(16):
                    # Upper faces point skyward on either wing.
                    face = [inner[j], inner[j + 1], outer[j + 1], outer[j]]
                    if side < 0:
                        face.reverse()
                    triangle(paint, face[0], face[1], face[2])
                    triangle(paint, face[0], face[2], face[3])

    # Enamel fox-head inlay on the swept front panel, contoured to the paint.
    def nose(x, z):
        radius = sqrt(x * x + ((z - 0.26) * 0.96) ** 2)
        return (x, 0.165 - (radius - 4.52) * 0.25, z)

    emblem = [
        (-0.49, -4.40),
        (-0.18, -4.66),
        (0, -4.61),
        (0.18, -4.66),
        (0.49, -4.40),
        (0.40, -4.97),
        (0, -5.29),
        (-0.40, -4.97),
    ]
    center = nose(0, -4.85)
    for i, p in enumerate(emblem):
        a, b = nose(*p), nose(*emblem[(i + 1) % len(emblem)])
        triangle("Copper" if i in (1, 2, 5, 6) else "Deep enamel", center, a, b)


def bridge():
    def canopy(rx, rz, y):
        return ring(rx, rz, y, -1.55)

    rows = [
        canopy(3.18, 2.58, 0.05),
        canopy(3.14, 2.54, 0.30),
        canopy(3.03, 2.43, 0.43),
        canopy(2.94, 2.34, 0.51),
        canopy(2.62, 2.04, 0.91),
        canopy(2.16, 1.70, 1.23),
        canopy(2.10, 1.64, 1.27),
        canopy(1.81, 1.44, 1.40),
        canopy(0.9, 0.76, 1.51),
        canopy(0.001, 0.001, 1.53),
    ]
    loft(
        rows,
        [
            "Sea green",
            "Copper",
            "Deep enamel",
            "Canopy",
            "Canopy",
            "Copper",
            "Sea green",
            "Ceramic",
            "Ceramic",
        ],
    )
    for i in range(14):
        a = (i + 0.5) * tau / 14
        patch(
            [canopy(2.96, 2.36, 0.51), canopy(2.64, 2.06, 0.92), canopy(2.18, 1.72, 1.23)],
            "Champagne",
            a,
            0.037,
            2,
        )
        patch([canopy(2.69, 2.11, 0.865), canopy(2.64, 2.06, 0.923)], "Glass reflection", a + 0.066, 0.32, 7)


def gravity_emitters():
    # Four diagonals near the rim leave the boarding shaft and its approach clear.
    anchors = {}
    for side, side_name in ((-1, "Port"), (1, "Starboard")):
        for direction, end in ((-1, "Fore"), (1, "Aft")):
            x, z = side * 3.92, 0.26 + direction * 3.98
            y = -1.49
            anchors["Gravity" + end + side_name] = (x, y, z)
            rows = [
                ring(r, r, y + dy, z, x)
                for r, dy in (
                    (0.001, 0.10),
                    (0.28, 0.10),
                    (0.38, 0.018),
                    (0.49, 0),
                    (0.55, 0.035),
                    (0.67, 0.15),
                    (0.72, 0.29),
                    (0.60, 0.53),
                )
            ]
            loft(
                rows,
                [
                    "Ion ceramic",
                    "Deep enamel",
                    "Ion ceramic",
                    "Copper",
                    "Heat shield",
                    "Sea green",
                    "Champagne",
                ],
                steps=48,
            )
    for i in range(8):
        angle = i * tau / 8
        patch(
            [ring(1.02, 1.02, -2.74, 1.13, 0.54), ring(1.24, 1.22, -2.72, 1.09, 0.48)],
            "Running lights",
            angle + 0.08,
            0.27,
            6,
        )

    return anchors


def foil(sections, paints):
    """Solid swept spar. Each section specifies an x, y, z, chord and thickness."""
    profile = [
        (-0.57, 0),
        (-0.43, 0.37),
        (-0.11, 0.57),
        (0.48, 0.21),
        (0.55, -0.1),
        (-0.05, -0.51),
        (-0.43, -0.33),
    ]
    contours = [
        [(x, y + v * thickness, z + u * chord) for u, v in profile] for x, y, z, chord, thickness in sections
    ]
    for left, right in itertools.pairwise(contours):
        for i, paint in enumerate(paints):
            j = (i + 1) % len(profile)
            triangle(paint, left[i], right[j], right[i])
            triangle(paint, left[i], left[j], right[j])
    for k in range(1, len(profile) - 1):
        triangle("Heat shield", contours[0][0], contours[0][k + 1], contours[0][k])
        triangle("Heat shield", contours[-1][0], contours[-1][k], contours[-1][k + 1])


def engine_pod(x):
    # Front intake lip, ceramic fairing, insulated collar and recessed exhaust bell.
    profile = [
        (0.01, 0.01, 3.78),
        (0.36, 0.26, 3.76),
        (0.52, 0.41, 3.52),
        (0.63, 0.49, 3.49),
        (0.72, 0.59, 3.76),
        (0.83, 0.68, 4.37),
        (0.87, 0.69, 5.55),
        (0.80, 0.65, 6.18),
        (0.83, 0.68, 6.24),
        (0.82, 0.68, 6.35),
        (0.70, 0.58, 6.55),
        (0.68, 0.56, 6.86),
        (0.72, 0.60, 7.05),
        (0.69, 0.56, 7.12),
        (0.53, 0.43, 7.12),
        (0.46, 0.37, 6.91),
        (0.36, 0.29, 6.87),
        (0.24, 0.19, 6.87),
        (0.16, 0.13, 6.95),
        (0.01, 0.01, 7.01),
    ]
    colors = [
        "Deep enamel",
        "Heat shield",
        "Copper",
        "Sea green",
        "Ceramic",
        "Sea green",
        "Sea green",
        "Heat shield",
        "Copper",
        "Heat shield",
        "Deep enamel",
        "Champagne",
        "Copper",
        "Heat shield",
        "Deep enamel",
        "Ion ceramic",
        "Champagne",
        "Heat shield",
        "Deep enamel",
    ]

    def rim(index, angle):
        rx, ry, z = profile[index]
        return (x + rx * cos(angle), 1.42 + ry * sin(angle), z)

    for i, paint in enumerate(colors):
        for j in range(48):
            a0, a1 = tau * j / 48, tau * (j + 1) / 48
            verts = [rim(i, a0), rim(i, a1), rim(i + 1, a1), rim(i + 1, a0)]
            # Smooth the fairing across both circumferential and longitudinal seams.
            normals = []
            for k, a in ((i, a0), (i, a1), (i + 1, a1), (i + 1, a0)):
                rx, ry, _ = profile[k]
                axis = minus(rim(min(k + 1, len(profile) - 1), a), rim(max(k - 1, 0), a))
                normals.append(unit(cross((-rx * sin(a), ry * cos(a), 0), axis)))
            finish = paint
            if i == 10 and j % 8 == 0:
                finish = "Copper"
            elif i == 1 and j % 6 == 0:
                finish = "Champagne"
            elif i == 5 and 25 <= j <= 45:
                finish = "Deep enamel"
            for n in (0, 1, 2, 0, 2, 3):
                surfaces[finish].append((verts[n], normals[n]))

    # Thin formed cowl on the crown and recessed cooling slots down either flank.
    def shell(z, angle, lift):
        for near, far in itertools.pairwise(profile[4:8]):
            if near[2] <= z <= far[2]:
                t = (z - near[2]) / (far[2] - near[2])
                rx = near[0] * (1 - t) + far[0] * t + lift
                ry = near[1] * (1 - t) + far[1] * t + lift
                return (x + rx * cos(angle), 1.42 + ry * sin(angle), z)
        raise ValueError(f"Outside the cowling at {z}")

    def shell_panel(stations, angle, lift, paint):
        arcs = [
            [shell(z, angle + width * (j / 4 - 1) + skew, lift) for j in range(9)]
            for z, width, skew in stations
        ]
        for front, rear in itertools.pairwise(arcs):
            for j in range(8):
                triangle(paint, front[j], front[j + 1], rear[j + 1])
                triangle(paint, front[j], rear[j + 1], rear[j])

    crown = [(4.10, 0.27, 0), (4.52, 0.77, 0), (5.34, 0.65, 0), (6.04, 0.20, 0)]
    shell_panel(crown, pi / 2, 0.042, "Champagne")
    shell_panel([(z, width * 0.92, skew) for z, width, skew in crown], pi / 2, 0.050, "Ceramic")
    for facing in (0, pi):
        for j in range(5):
            z = 4.56 + 0.21 * j
            shell_panel(
                [(z, 0.26, -0.10), (z + 0.084, 0.28, 0), (z + 0.105, 0.24, 0.055)],
                facing,
                0.024,
                "Deep enamel",
            )
            shell_panel([(z + 0.082, 0.23, 0.02), (z + 0.107, 0.20, 0.06)], facing, 0.03, "Copper")
    return x, 1.42, 6.99


def spoiler_drive():
    finishes_foil = ["Copper", "Ceramic", "Sea green", "Copper", "Deep enamel", "Heat shield", "Sea green"]
    # Two swept pylons lift one continuous wing and its outboard nacelles clear of the disc.
    for side in (-1, 1):
        foot = [
            (side * 1.68, 0.11, 2.94, 1.48, 0.54),
            (side * 2.02, 0.27, 3.10, 1.55, 0.56),
            (side * 2.52, 0.98, 4.37, 1.20, 0.50),
            (side * 2.83, 1.34, 4.85, 1.14, 0.42),
        ]
        foil(sorted(foot), finishes_foil)
    foil(
        [
            (-3.80, 1.41, 5.14, 1.23, 0.40),
            (-2.72, 1.37, 4.89, 1.15, 0.40),
            (-1.17, 1.29, 4.63, 0.92, 0.30),
            (0, 1.28, 4.57, 0.88, 0.29),
            (1.17, 1.29, 4.63, 0.92, 0.30),
            (2.72, 1.37, 4.89, 1.15, 0.40),
            (3.80, 1.41, 5.14, 1.23, 0.40),
        ],
        finishes_foil,
    )
    return {"ExhaustPort": engine_pod(-3.79), "ExhaustStarboard": engine_pod(3.79)}


def write_glb(output, mesh_name, anchors):
    binary = bytearray()
    views, accessors, primitives, materials = [], [], [], []

    def accessor(data, fmt, kind, component, target):
        while len(binary) % 4:
            binary.append(0)
        offset = len(binary)
        pack = struct.Struct("<" + fmt).pack
        for row in data:
            binary.extend(pack(*row))
        views.append(
            {"buffer": 0, "byteOffset": offset, "byteLength": len(binary) - offset, "target": target}
        )
        entry = {"bufferView": len(views) - 1, "componentType": component, "count": len(data), "type": kind}
        if fmt == "fff":
            entry.update(min=list(map(min, zip(*data))), max=list(map(max, zip(*data))))
        accessors.append(entry)
        return len(accessors) - 1

    for name, vertices in surfaces.items():
        hex_value, metal, rough, glow = finishes[name]
        rgb = [(int(hex_value[i : i + 2], 16) / 255) ** 2.2 for i in (0, 2, 4)]
        materials.append(
            {
                "name": name,
                "pbrMetallicRoughness": {
                    "baseColorFactor": rgb + [1],
                    "metallicFactor": metal,
                    "roughnessFactor": rough,
                },
                "emissiveFactor": [c * glow for c in rgb],
            }
        )
        unique = list(dict.fromkeys(vertices))
        ids = {vertex: i for i, vertex in enumerate(unique)}
        pos = accessor([p for p, n in unique], "fff", "VEC3", 5126, 34962)
        normal = accessor([n for p, n in unique], "fff", "VEC3", 5126, 34962)
        idx = accessor([(ids[v],) for v in vertices], "H", "SCALAR", 5123, 34963)
        primitives.append(
            {
                "attributes": {"POSITION": pos, "NORMAL": normal},
                "indices": idx,
                "material": len(materials) - 1,
            }
        )
    while len(binary) % 4:
        binary.append(0)
    doc = {
        "asset": {"version": "2.0", "generator": "OctoFox Ship Home"},
        "scene": 0,
        "scenes": [{"nodes": [0]}],
        "nodes": [
            {"name": mesh_name, "mesh": 0, "children": list(range(1, len(anchors) + 1))},
            *({"name": name, "translation": pos} for name, pos in anchors.items()),
        ],
        "meshes": [{"name": mesh_name, "primitives": primitives}],
        "materials": materials,
        "bufferViews": views,
        "accessors": accessors,
        "buffers": [{"byteLength": len(binary)}],
    }
    desc = json.dumps(doc, separators=(",", ":")).encode()
    desc += b" " * (-len(desc) % 4)
    output.write_bytes(
        struct.pack("<4sIIII", b"glTF", 2, 28 + len(desc) + len(binary), len(desc), 0x4E4F534A)
        + desc
        + struct.pack("<II", len(binary), 0x004E4942)
        + binary
    )


if __name__ == "__main__":
    hull()
    dorsal_markings()
    bridge()
    anchors = gravity_emitters() | spoiler_drive()
    write_glb(OUTPUT, "Saucer", anchors)
