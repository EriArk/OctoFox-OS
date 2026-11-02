# SPDX-License-Identifier: GPL-3.0-or-later
import hashlib
import json
from pathlib import Path
import sys
import re

SOURCE = 'd0acb0874cc07735d7fa978539bb2471b2c1e71a'
SETTINGS = 'ngpc-mirror-own-flash-v1'


def bundle(root):
    root=Path(root).resolve()
    sys.path.insert(0,str(root/'upstream.zip'))
    from core.native import core_fingerprint
    fingerprint=core_fingerprint(root/'core.so')
    if not re.fullmatch(r'[0-9]+:p[0-9a-f]{16}',fingerprint):raise ValueError('Unprobed native core')
    runtime=hashlib.sha256((SOURCE+'/'+SETTINGS+'/'+fingerprint).encode()).hexdigest()
    required=['core.so','frontend.so','font.ttf','bios_hle.bin','upstream.zip','launch.py','state.py','channel.py','stream_transport']
    names=required+sorted(str(p.relative_to(root)) for p in (root/'lib').glob('*') if p.is_file())
    files={}
    for name in names:
        p=root/name
        if not p.is_file() or not p.resolve().is_relative_to(root):raise ValueError('Package path')
        files[name]=hashlib.sha256(p.read_bytes()).hexdigest()
    (root/'manifest.json').write_text(json.dumps(dict(protocol=1,source=SOURCE,settings=SETTINGS,runtime=runtime,fingerprint=fingerprint,files=files),indent=2)+'\n')


if __name__=='__main__':bundle(sys.argv[1])
