#!/usr/bin/env python3
"""Build an archive containing original screenshots and publication text."""
from pathlib import Path
from zipfile import ZipFile, ZIP_STORED
import json

root = Path(__file__).resolve().parent
manifest = json.loads((root / "selection.json").read_text(encoding="utf-8"))
names = [item["archive_path"] for item in manifest]
names += ["texts/DISCORD_ANNOUNCEMENT_APPROVED.md", "texts/REDDIT_DRAFT_FOR_REVIEW.md", "README.md", "selection.json", "REVIEW_GALLERY.html"]
destination = root / "OctoFox_OS_Alpha9_Post_Kit.zip"
with ZipFile(destination, "w", compression=ZIP_STORED) as archive:
    for name in names:
        path = root / name
        if not path.is_file():
            raise SystemExit(f"Missing file: {path}")
        archive.write(path, arcname=name)
print(f"{destination} ({destination.stat().st_size:,} bytes; {len(names)} entries)")
