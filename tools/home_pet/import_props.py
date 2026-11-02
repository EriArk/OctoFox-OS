"""Import the reviewed CC0 prop subset from original Kenney ZIPs.

python3 tools/home_pet/import_props.py ARCHIVE_DIRECTORY OUTPUT_DIRECTORY
Downloads stay outside the repository. No archive code is executed.
"""
import hashlib
import json
from pathlib import Path, PurePosixPath
import struct
import sys
import zipfile

PACKS = {
    "food-kit": ("cdad90853682499b94c9fda2f87678b24bfd8f3264e0ed323f6b6a27fd7c6f6f",
                 ["apple", "banana", "cookie-chocolate", "burger", "cup-tea", "cupcake"]),
    "furniture-kit": ("e67652d0932cee41683f74711c03d3e192a2af9979ef8e6b237711f5482d46b0",
                      ["bedSingle", "loungeChair", "tableCoffee", "rugRound", "plantSmall1", "books"]),
    "toy-car-kit": ("26c11bbb77102b8dd00cdaf7b2c7ab692416d750dd064de886d809acec346782",
                    ["vehicle-racer", "vehicle-monster-truck"]),
}


def digest(data):
    return hashlib.sha256(data).hexdigest()


def embed_images(data, archive, source):
    magic, version, size = struct.unpack_from("<III", data)
    assert (magic, version, size) == (0x46546C67, 2, len(data))
    json_size, kind = struct.unpack_from("<II", data, 12)
    assert kind == 0x4E4F534A
    document = json.loads(data[20:20 + json_size])
    binary_size, kind = struct.unpack_from("<II", data, 20 + json_size)
    assert kind == 0x004E4942 and 28 + json_size + binary_size == len(data)
    assert len(document["buffers"]) == 1 and "uri" not in document["buffers"][0]
    binary = bytearray(data[28 + json_size:])
    for image in document.get("images", []):
        if "uri" not in image:
            continue
        uri = PurePosixPath(image.pop("uri"))
        assert not uri.is_absolute() and ".." not in uri.parts and uri.suffix == ".png"
        texture = archive.read(str(PurePosixPath(source).parent / uri))
        assert texture.startswith(b"\x89PNG\r\n\x1a\n")
        binary.extend(b"\0" * (-len(binary) % 4))
        image["bufferView"] = len(document["bufferViews"])
        image["mimeType"] = "image/png"
        document["bufferViews"].append({"buffer": 0, "byteOffset": len(binary), "byteLength": len(texture)})
        binary.extend(texture)
    document["buffers"][0]["byteLength"] = len(binary)
    binary.extend(b"\0" * (-len(binary) % 4))
    payload = json.dumps(document, separators=(",", ":"), ensure_ascii=True).encode()
    payload += b" " * (-len(payload) % 4)
    result = (struct.pack("<III", magic, version, 28 + len(payload) + len(binary))
              + struct.pack("<II", len(payload), 0x4E4F534A) + payload
              + struct.pack("<II", len(binary), 0x004E4942) + binary)
    triangles = 0
    for mesh in document["meshes"]:
        for primitive in mesh["primitives"]:
            assert primitive.get("mode", 4) == 4
            triangles += document["accessors"][primitive["indices"]]["count"] // 3
    return result, triangles


def main():
    archive_root, output = map(Path, sys.argv[1:])
    manifest = {"schema": 1, "reviewed": "2026-11-02", "license": "CC0-1.0",
                "status": "prepared-not-integrated", "author": "Kenney", "packs": []}
    for slug, (expected_hash, names) in PACKS.items():
        path = archive_root / (slug + ".zip")
        assert digest(path.read_bytes()) == expected_hash, f"Unreviewed archive: {slug}"
        directory = output / slug
        directory.mkdir(parents=True, exist_ok=True)
        pack = {"id": slug, "source": "https://kenney.nl/assets/" + slug,
                "archiveSha256": expected_hash, "models": []}
        with zipfile.ZipFile(path) as archive:
            license_data = archive.read("License.txt")
            assert b"CC0" in license_data
            license_text = "\n".join(line.rstrip() for line in license_data.decode("utf-8-sig").splitlines()).strip() + "\n"
            (directory / "License.txt").write_text(license_text, encoding="utf-8")
            pack["licenseSourceSha256"] = digest(license_data)
            for name in names:
                matches = [p for p in archive.namelist() if p.endswith("/" + name + ".glb")]
                assert len(matches) == 1, (slug, name, matches)
                source = matches[0]
                original = archive.read(source)
                model, triangles = embed_images(original, archive, source)
                target = directory / (name + ".glb")
                target.write_bytes(model)
                pack["models"].append({"file": target.relative_to(output).as_posix(),
                                       "sourcePath": source, "sourceSha256": digest(original),
                                       "sha256": digest(model), "bytes": len(model), "triangles": triangles})
        manifest["packs"].append(pack)
    (output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"models": sum(len(p["models"]) for p in manifest["packs"]),
                      "bytes": sum(m["bytes"] for p in manifest["packs"] for m in p["models"])}))


if __name__ == "__main__":
    main()
