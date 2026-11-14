#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Recreate platform PNGs from the exact downloads listed in sources.json.

Download each record's `download` URL to INPUT/<id>.png, then run this script
with INPUT as its sole argument. Original and derivative licences are retained.
"""
import hashlib
import json
from pathlib import Path
import sys
from PIL import Image

root = Path(__file__).resolve().parents[2] / 'assets/platforms'
inputs = Path(sys.argv[1])
for row in json.loads((root / 'sources.json').read_text()):
    source = inputs / (row['id'] + '.png')
    if hashlib.sha256(source.read_bytes()).hexdigest() != row['downloaded_sha256']:
        raise ValueError('Source changed: ' + row['id'])
    with Image.open(source) as original:
        image = original.convert('RGBA')
    image = image.crop(image.getchannel('A').getbbox())
    image.thumbnail((640, 640), Image.Resampling.LANCZOS)
    image.save(root / row['file'], optimize=True)
print('Recreated all platform photographs; retain per-file attribution and licences.')
