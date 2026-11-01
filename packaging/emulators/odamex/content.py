# SPDX-License-Identifier: GPL-3.0-or-later
"""Data-only Doom launch recipes. No filename/title allowlist or command strings."""
import hashlib
import json
import re
import struct
import sys
from pathlib import Path

LIMIT = 512 * 1024 * 1024


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        if not 0 < path.stat().st_size <= LIMIT:
            raise ValueError('Content size')
        for block in iter(lambda: f.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()


def wad(path, base=False):
    with path.open('rb') as f:
        size = path.stat().st_size
        if not 12 <= size <= LIMIT:
            raise ValueError('WAD size')
        magic, count, offset = struct.unpack('<4sii', f.read(12))
        if magic not in (b'IWAD', b'PWAD') or not 1 <= count <= 100000 or offset < 12 or offset + count * 16 > size:
            raise ValueError('WAD directory')
        if base and magic != b'IWAD':
            raise ValueError('A PWAD needs a .doom recipe with its base IWAD')
        f.seek(offset)
        names = set()
        patches = []
        for _ in range(count):
            start, length, name = struct.unpack('<ii8s', f.read(16))
            if start < 0 or length < 0 or (length and start + length > size):
                raise ValueError('WAD lump bounds')
            name = name.rstrip(b'\0').upper()
            names.add(name)
            if name == b'DEHACKED':
                patches.append((start, length))
        if base and (not {b'PLAYPAL', b'COLORMAP', b'PNAMES', b'TEXTURE1', b'STTNUM0'}.issubset(names)
                     or not ({b'MAP01', b'E1M1'} & names)):
            raise ValueError('Not a Doom base game')
        for start, length in patches:
            if length > 16 * 1024 * 1024:
                raise ValueError('Patch size')
            f.seek(start)
            standalone_patch(f.read(length))
        return names


def standalone_patch(data):
    # Odamex can load BEX includes from unlisted search directories. Such a
    # dependency must be made explicit/flattened before exact-content admission.
    if re.search(rb'(?im)^\s*include\b', data):
        raise ValueError('External BEX includes need a self-contained patch')


def content(filename):
    path = Path(filename).resolve(strict=True)
    recipe = {'version': 1, 'iwad': str(path)}
    if path.suffix.lower() == '.doom':
        if path.stat().st_size > 16384:
            raise ValueError('Recipe size')
        recipe = json.loads(path.read_text(encoding='utf-8'))
        if not isinstance(recipe, dict) or set(recipe) - {'version', 'iwad', 'files', 'deh', 'mode', 'map', 'skill'}:
            raise ValueError('Unknown recipe fields')
    elif path.suffix.lower() != '.wad':
        raise ValueError('Unsupported content container')
    if recipe.get('version') != 1:
        raise ValueError('Recipe version')

    def resolve(value, suffixes):
        if not isinstance(value, str) or not value or '\0' in value:
            raise ValueError('Invalid content path')
        p = (path.parent / value).resolve(strict=True)
        if not p.is_file() or p.suffix.lower() not in suffixes:
            raise ValueError('Invalid content file')
        return p

    iwad = resolve(recipe.get('iwad'), {'.wad'})
    maps = wad(iwad, True)
    files, deh = [], []
    for key, dest, suffixes in [('files', files, {'.wad'}), ('deh', deh, {'.deh', '.bex'})]:
        values = recipe.get(key, [])
        if not isinstance(values, list) or len(values) > 32:
            raise ValueError('Too many dependencies')
        for value in values:
            p = resolve(value, suffixes)
            if key == 'files':
                maps.update(wad(p))
            else:
                if p.stat().st_size > 16 * 1024 * 1024:
                    raise ValueError('Patch size')
                standalone_patch(p.read_bytes())
            dest.append(p)
    mode = recipe.get('mode', 'coop')
    skill = recipe.get('skill', 3)
    level = recipe.get('map', 'MAP01' if b'MAP01' in maps else 'E1M1')
    if mode not in ('coop', 'deathmatch') or type(skill) is not int or not 1 <= skill <= 5:
        raise ValueError('Invalid game options')
    if isinstance(level, str):
        level = level.upper()
    if not isinstance(level, str) or not re.fullmatch(r'[A-Z0-9_]{1,8}', level) or level.encode() not in maps:
        raise ValueError('Missing map')
    identity = {'iwad': digest(iwad), 'files': [digest(p) for p in files],
                'deh': [digest(p) for p in deh], 'mode': mode, 'map': level, 'skill': skill}
    fingerprint = hashlib.sha256(json.dumps(identity, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
    return {'content': fingerprint, 'iwad': str(iwad), 'files': list(map(str, files)),
            'deh': list(map(str, deh)), 'mode': mode, 'map': level, 'skill': skill,
            'dependencies': list(map(str, [path, iwad, *files, *deh]))}


def arguments(c):
    args = ['-iwad', c['iwad']]
    if c['files']:
        args += ['-file', *c['files']]
    if c['deh']:
        args += ['-deh', *c['deh']]
    return args


if __name__ == '__main__':
    try:
        print(json.dumps(content(sys.argv[1])))
    except (OSError, ValueError, TypeError, struct.error):
        sys.exit(2)
