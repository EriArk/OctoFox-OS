"""Build the reversible racing-helmet hair shapes on the revision-15/16 SDK pack."""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np

from build_pack import GLB

def helmet_hair(points):
    # Fit in the closed volume underneath the shell, including the tied tail.
    # A smooth radial limit preserves ordering of overlapping locks; simply
    # projecting all tips onto the same surface causes flickering under glass.
    centre = np.array([0., .844, .006])
    radii = np.array([.151, .153, .166])
    local = (points - centre) / radii
    radius = np.linalg.norm(local, axis=1, keepdims=True)
    excess = np.maximum(radius - .84, 0.)
    fitted = np.minimum(radius, .84) + .132 * excess / (.132 + excess)
    return centre + local * (fitted / np.maximum(radius, 1e-9)) * radii


def transformed(positions, normals, deform):
    p = positions.astype(float)
    # Transport the authored normals of each lock through the same compression.
    step = .00002
    jac = np.stack([(deform(p+d) - deform(p-d))/(2*step)
                    for d in np.eye(3)*step], axis=2)
    n = np.linalg.solve(jac.transpose(0,2,1), normals[..., None])[..., 0]
    n /= np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-12)
    return deform(p).astype("<f4"), n.astype("<f4")


def digest(data):
    return hashlib.sha256(data).hexdigest()


def build(pack):
    manifest = json.loads((pack/"manifest.json").read_text())
    assert manifest["revision"] in (15,16)
    template = GLB(pack/"template.glb")
    for hair, node in manifest["hairNodes"].items():
        mesh = template.g["nodes"][node]["mesh"]
        patches = []
        for i, prim in enumerate(template.g["meshes"][mesh]["primitives"]):
            a = prim["attributes"]
            fitted = transformed(template.acc(a["POSITION"]), template.acc(a["NORMAL"]), helmet_hair)
            for key, data in zip(("POSITION","NORMAL"), fitted):
                filename = f"fit-racing-helmet-{hair}-{i}-{key.lower()}.bin"
                raw = data.tobytes()
                (pack/filename).write_bytes(raw)
                manifest["files"][filename] = digest(raw)
                patches.append(dict(accessor=a[key], file=filename, sha256=digest(raw),
                                    sourceSha256=digest(template.acc(a[key]).tobytes()),
                                    min=data.min(0).tolist(), max=data.max(0).tolist()))
        for helmet in ("racing-helmet","rose-racing-helmet"):
            manifest["wearables"][helmet].pop("hidesHair", None)
            manifest["headwearFits"][helmet+"/"+hair] = patches
    manifest["revision"] = 16
    encoded = json.dumps(manifest, indent=2)+"\n"
    assert len(encoded.encode()) < 65536
    (pack/"manifest.json").write_text(encoded, encoding="utf8", newline="\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("pack", type=Path)
    build(parser.parse_args().pack)
