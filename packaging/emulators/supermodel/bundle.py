#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Seal the private package; config/NVRAM remain owner-local, outside the package."""
import hashlib
import json
from pathlib import Path
import sys

FILES = ('bin/supermodel', 'bin/supermodel.real', 'lib/libSDL2_net-2.0.so.0', 'lib/libGLU.so.1',
         'Config/Games.xml', 'Config/Supermodel.ini', 'content.py', 'model3_endpoint', 'stream_transport')
SOURCE = '036af1c8d6640c5a60709c1f99144635ed82a184'
SETTINGS = 'supermodel-native-ring-owned-v1'


def seal(root, config, nvram):
    root = Path(root).resolve()
    if not Path(config).is_absolute() or not Path(nvram).is_absolute():
        raise ValueError('Owner paths must be absolute')
    files = {}
    for name in FILES:
        path = root/name
        if path.is_symlink() or not path.is_file() or not 0 < path.stat().st_size <= 256*1024*1024:
            raise ValueError('Missing or unsafe package file: '+name)
        if name in ('bin/supermodel', 'bin/supermodel.real', 'model3_endpoint', 'stream_transport') and not path.stat().st_mode & 0o111:
            raise ValueError('Not executable: '+name)
        files[name] = hashlib.sha256(path.read_bytes()).hexdigest()
    manifest = dict(protocol=1, source=SOURCE, settings=SETTINGS, files=files, config=config, nvram=nvram)
    (root/'manifest.json').write_text(json.dumps(manifest, indent=2)+'\n')
    return manifest


if __name__ == '__main__':
    print(json.dumps(seal(*sys.argv[1:])))
