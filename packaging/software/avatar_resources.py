#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Reject loose avatar geometry in a Software payload; not a licence clearance.

The C++ packer checks decoded byte equivalence. Here we check the staged shape,
bounded envelope lengths and all manifest file references before signing.
"""
import json
from pathlib import Path
import struct


def validate(root):
    root = Path(root)
    if not root.is_dir():
        raise ValueError('Missing incorporated avatar packs')
    count = 0
    for path in root.rglob('*'):
        if path.is_symlink():
            raise ValueError('Redirected avatar resource')
        if not path.is_file():
            continue
        if path.suffix.lower() in {'.glb', '.gltf', '.bin', '.blend', '.fbx', '.obj'}:
            raise ValueError('Loose avatar geometry: ' + path.name)
        if path.suffix == '.tav':
            with path.open('rb') as stream:
                header = stream.read(8)
            if len(header) != 8 or header[:4] != b'TAV1':
                raise ValueError('Invalid avatar resource header')
            size = struct.unpack('<I', header[4:])[0]
            if not 0 < size <= 64 * 1024**2 or path.stat().st_size != 56 + (size // 16 + 1) * 16:
                raise ValueError('Invalid avatar resource length')
            count += 1
    def files(value):
        if isinstance(value, dict):
            for key, item in value.items():
                if key == 'file' and isinstance(item, str):
                    yield item
                else:
                    yield from files(item)
        elif isinstance(value, list):
            for item in value:
                yield from files(item)
    manifests = list(root.rglob('manifest.json'))
    if not manifests or not count:
        raise ValueError('Empty incorporated avatar packs')
    for manifest in manifests:
        for name in ['template.glb', *files(json.loads(manifest.read_text(encoding='utf-8')))]:
            if not name or '/' in name or '\\' in name or '..' in name:
                raise ValueError('Invalid avatar manifest resource')
            path = manifest.parent / (name + '.tav' if Path(name).suffix in {'.glb', '.bin'} else name)
            if not path.is_file():
                raise ValueError('Missing avatar resource: ' + name)
    return count
