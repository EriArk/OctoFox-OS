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


def exhaust(x):
    # Nested open bells face aft, below the paired fairings.
    profile = [
        (0.008, 0.008, 5.48),
        (0.30, 0.18, 5.49),
        (0.39, 0.24, 5.56),
        (0.48, 0.30, 5.77),
        (0.62, 0.38, 5.79),
        (0.66, 0.42, 5.65),
        (0.78, 0.46, 5.25),
        (0.60, 0.28, 3.92),
    ]
    colors = ["Ion ceramic", "Copper", "Deep enamel", "Heat shield", "Copper", "Sea green", "Deep enamel"]
    for i, paint in enumerate(colors):

        def rim(k, j):
            rx, ry, z = profile[k]
            a = tau * j / 48
            return (
                x + rx * cos(a),
                -0.52 + ry * sin(a) + (5.8 - z) * 0.22,
                z + 0.63 + max(0, min(1, (z - 4.72) / 0.5)) * 0.32,
            )

        for j in range(48):
            a, b, c, d = rim(i, j), rim(i + 1, j), rim(i + 1, j + 1), rim(i, j + 1)
            triangle(paint, a, b, c)
            triangle(paint, a, c, d)


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
    # Low swept engine fairings along either side of the aft deck.
    for side in (-1, 1):

        def pod(rx, rz, y, side=side):
            return ring(rx, rz, y, 2.50, side * 2.47)

        exhaust(side * 2.47)
        loft(
            [
                pod(0.95, 2.26, -0.14),
                pod(0.94, 2.22, 0.20),
                pod(0.83, 1.97, 0.38),
                pod(0.63, 1.68, 0.53),
                pod(0.001, 0.001, 0.60),
            ],
            ["Deep enamel", "Copper", "Sea green", "Sea green"],
            steps=48,
        )
        for j in range(5):
            z = 2.68 + 0.24 * j
            width = 0.53 - 0.035 * j
            loft(
                [
                    ring(width, 0.068, 0.535, z, side * 2.47),
                    ring(width, 0.068, 0.586, z, side * 2.47),
                    ring(0.001, 0.001, 0.59, z, side * 2.47),
                ],
                ["Deep enamel", "Champagne"],
                steps=20,
            )


def engines():
    for i in range(3):
        angle = pi + i * tau / 3
        x, z = 3.70 * sin(angle), 0.26 - 3.70 * cos(angle)

        def hub(r, y, z=z, x=x):
            return ring(r, r, y, z, x)

        loft(
            [
                hub(0.001, -1.98),
                hub(0.26, -1.99),
                hub(0.34, -2.10),
                hub(0.47, -2.13),
                hub(0.53, -2.06),
                hub(0.60, -1.93),
                hub(0.70, -1.73),
                hub(0.67, -1.49),
            ],
            [
                "Ion ceramic",
                "Deep enamel",
                "Ion ceramic",
                "Copper",
                "Deep enamel",
                "Heat shield",
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


def strut(start, end, base, tip, paint):
    axis = unit(minus(end, start))
    u = unit(cross(axis, (1, 0, 0)))
    v = cross(axis, u)

    def circle(center, radius, j):
        a = j * tau / 20
        return tuple(center[k] + radius * (u[k] * cos(a) + v[k] * sin(a)) for k in range(3))

    for j in range(20):
        a, b = circle(start, base, j), circle(start, base, j + 1)
        c, d = circle(end, tip, j), circle(end, tip, j + 1)
        triangle(paint, a, b, d)
        triangle(paint, a, d, c)
        triangle(paint, start, b, a)
        triangle(paint, end, c, d)


def landing_gear():
    # Local origin is the deployment hinge at y = -2.79. Shoes meet the pad at -5.35.
    for i in range(3):
        angle = tau * i / 3

        def leg(radius, y, angle=angle):
            return (radius * sin(angle), y, -radius * cos(angle))

        mount, knee, foot = leg(1.92, 0), leg(2.54, -1.255), leg(2.95, -2.44)
        strut(leg(1.92, -0.08), leg(1.92, 1.20), 0.24, 0.38, "Heat shield")
        strut(mount, knee, 0.24, 0.18, "Deep enamel")
        strut(knee, foot, 0.145, 0.12, "Champagne")
        strut(leg(1.44, 0), knee, 0.09, 0.075, "Ceramic")
        strut(leg(2.47, -1.12), leg(2.59, -1.40), 0.21, 0.19, "Copper")
        strut(leg(2.95, -2.56), leg(2.95, -2.43), 0.43, 0.40, "Deep enamel")
        strut(leg(2.95, -2.43), leg(2.95, -2.31), 0.40, 0.24, "Heat shield")


def write_glb(output, mesh_name):
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
        "nodes": [{"name": mesh_name, "mesh": 0}],
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
    engines()
    write_glb(OUTPUT, "Saucer")
    surfaces.clear()
    landing_gear()
    write_glb(OUTPUT.with_name("landing-gear.glb"), "LandingGear")
