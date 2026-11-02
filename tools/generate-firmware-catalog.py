#!/usr/bin/env python3
"""Extract factual requirements from a local libretro-core-info checkout; no firmware payloads."""
import json
import re
import subprocess
import sys
from pathlib import Path

source = Path(sys.argv[1])
target = Path(__file__).resolve().parents[1] / 'data/firmware'
target.mkdir(parents=True, exist_ok=True)
catalog = {}
for path in sorted(source.glob('*_libretro.info')):
    values = dict(re.findall(r'^\s*(\w+)\s*=\s*"?([^"\r\n]*)"?\s*$', path.read_text(encoding='utf-8-sig'), re.M))
    files = []
    for n in range(int(values.get('firmware_count', '0'))):
        name = values.get(f'firmware{n}_path', '').strip()
        if not name:
            continue
        item = dict(path=name, title=values.get(f'firmware{n}_desc', name).strip(), optional=values.get(f'firmware{n}_opt', '').strip() == 'true')
        if name in ('pcsx2/bios', 'pcsx2/resources', 'eka2l1/firmware'):
            item['directory'] = True
        # An exact path/basename note is evidence, never the first hash in a core's notes.
        match = re.search(r'(?:^|\|)\(!\)\s*(?:' + re.escape(name) + '|' + re.escape(Path(name).name) + r')\s*\(md5\):\s*([0-9a-fA-F]{32})(?:\||$)', values.get('notes', ''))
        if match:
            item['md5'] = match[1].lower()
        files.append(item)
    catalog[path.name.removesuffix('_libretro.info')] = dict(title=values.get('display_name', path.stem).strip(), files=files)
(target / 'firmware.json').write_text(json.dumps(catalog, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
(target / 'LICENSE').write_bytes((source / 'COPYING').read_bytes())
revision = subprocess.check_output(['git', '-C', str(source), 'rev-parse', 'HEAD'], text=True).strip()
(target / 'README.md').write_text(f'''# Firmware requirement metadata

Derived from https://github.com/libretro/libretro-core-info at `{revision}`.
MIT notice: [LICENSE](LICENSE). No BIOS, firmware, console keys or ROMs are included.
Regenerate with `python tools/generate-firmware-catalog.py <core-info-checkout>`.
This is upstream filename/optional/checksum metadata, not a game compatibility whitelist.
Unknown cores remain explicitly undescribed. Optional requirements remain optional.
''', encoding='utf-8')
print(f'{len(catalog)} cores; {sum(len(v["files"]) for v in catalog.values())} file requirements')
