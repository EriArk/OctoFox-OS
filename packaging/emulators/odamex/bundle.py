#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Seal an already staged native bundle; never includes an IWAD or user files."""
import hashlib
import json
from pathlib import Path
import sys

root = Path(sys.argv[1]).resolve()
required = ['bin/odamex', 'bin/odasrv', 'bin/odamex.wad', 'content.py', 'launch.py', 'endpoint.py', 'stream_transport']
names = required + sorted(str(p.relative_to(root)) for p in (root / 'lib').glob('*') if p.is_file())
for n in names:
    p = root / n
    if not p.is_file() or not p.resolve().is_relative_to(root):
        raise ValueError('Missing or external package file: ' + n)
m = dict(protocol=1, source='3a763534ac609aee8d22351baa3155809c4ea355', settings='odamex-owned-native-v1',
         files={n: hashlib.sha256((root / n).read_bytes()).hexdigest() for n in names})
(root / 'manifest.json').write_text(json.dumps(m, indent=2) + '\n')
