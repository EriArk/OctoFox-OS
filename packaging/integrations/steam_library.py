#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Read-only local Steam discovery. No account files, network, or Steam writes."""
import json
from datetime import datetime, timezone
import os
from pathlib import Path
import re
import struct
import sys


def read(path, limit):
    with path.open('rb') as source:
        data = source.read(limit + 1)
    if len(data) > limit:
        raise ValueError('Steam metadata exceeds the supported size')
    return data


def text_vdf(data):
    """Strict bounded KeyValues; do not silently accept truncation/duplicate keys."""
    text = data.decode('utf-8-sig')
    tokens = []; i = 0
    while i < len(text):
        if text[i].isspace(): i += 1; continue
        if text[i:i+2] == '//':
            end = text.find('\n', i); i = len(text) if end < 0 else end + 1; continue
        if text[i] in '{}': tokens.append(text[i]); i += 1; continue
        if text[i] != '"': raise ValueError('Invalid Steam metadata token')
        i += 1; value = ''
        while i < len(text) and text[i] != '"':
            if text[i] == '\\' and i + 1 < len(text) and text[i+1] in '\\"': i += 1
            value += text[i]; i += 1
        if i >= len(text): raise ValueError('Truncated Steam metadata string')
        tokens.append((value,)); i += 1
        if len(tokens) > 200000: raise ValueError('Too many Steam metadata tokens')
    cursor = 0
    def block(depth=0, nested=False):
        nonlocal cursor
        if depth > 24: raise ValueError('Steam metadata nesting is too deep')
        result = {}
        while cursor < len(tokens):
            key = tokens[cursor]; cursor += 1
            if key == '}' and nested: return result
            if not isinstance(key, tuple) or cursor >= len(tokens): raise ValueError('Invalid Steam metadata key')
            key = key[0].lower()
            if key in result: raise ValueError('Duplicate Steam metadata key')
            value = tokens[cursor]; cursor += 1
            if value == '{': value = block(depth+1, True)
            elif isinstance(value, tuple): value = value[0]
            else: raise ValueError('Invalid Steam metadata value')
            result[key] = value
        if nested: raise ValueError('Truncated Steam metadata block')
        return result
    return block()


def app_metadata(path, wanted):
    """Appinfo 27/28/29, using Steam's common/type (never title guesses)."""
    data = read(path, 128 * 1024 * 1024)
    version, = struct.unpack_from('<I', data)
    if version not in (0x07564427, 0x07564428, 0x07564429):
        raise ValueError('Unsupported Steam app cache version')
    names = None; offset = 8; end = len(data)
    if version == 0x07564429:
        end, = struct.unpack_from('<Q', data, 8); offset = 16
        if not 16 <= end <= len(data)-4: raise ValueError('Invalid Steam string table')
        count, = struct.unpack_from('<I', data, end)
        if count > 1000000: raise ValueError('Invalid Steam string count')
        names = data[end+4:].split(b'\0')
        if len(names) != count+1 or names[-1]: raise ValueError('Truncated Steam string table')
    def binary(payload):
        pos = 0
        def string():
            nonlocal pos
            stop = payload.find(b'\0', pos)
            if stop < 0: raise ValueError('Truncated Steam app string')
            value = payload[pos:stop].decode('utf-8'); pos = stop+1
            return value
        def block(depth=0):
            nonlocal pos
            if depth > 24: raise ValueError('Steam app nesting is too deep')
            obj = {}
            while pos < len(payload):
                kind = payload[pos]; pos += 1
                if kind == 8: return obj
                if names is None: key = string()
                else:
                    index, = struct.unpack_from('<I', payload, pos); pos += 4
                    key = names[index].decode('utf-8')
                if kind == 0: value = block(depth+1)
                elif kind == 1: value = string()
                elif kind in (2, 3, 4, 6, 7, 10):
                    size = 8 if kind in (7, 10) else 4
                    if pos+size > len(payload): raise ValueError('Truncated Steam app value')
                    value = payload[pos:pos+size]; pos += size
                else: raise ValueError('Unsupported Steam app value')
                obj[key.lower()] = value
            raise ValueError('Truncated Steam app block')
        return block()
    result = {}
    while offset+4 <= end:
        app, = struct.unpack_from('<I', data, offset)
        if not app: return result
        size, = struct.unpack_from('<I', data, offset+4)
        following = offset+8+size
        header = 40 if version == 0x07564427 else 60
        if size < header or following > end: raise ValueError('Truncated Steam app entry')
        if str(app) in wanted:
            entry = binary(data[offset+8+header:following]).get('appinfo', {})
            common = entry.get('common', {}); extended = entry.get('extended', {})
            metadata = {'kind': common.get('type', '').lower()}
            for key in ('developer','publisher'):
                value = extended.get(key)
                if isinstance(value,str) and value.strip(): metadata[key] = value.strip()[:160]
            release = common.get('steam_release_date')
            if isinstance(release,bytes) and len(release)==4: release = struct.unpack('<I',release)[0]
            if isinstance(release,str) and release.isdecimal(): release = int(release)
            if isinstance(release,int) and 0 < release < 4102444800:
                metadata['releasedate'] = datetime.fromtimestamp(release,timezone.utc).strftime('%Y%m%d')
            result[str(app)] = metadata
        offset = following
    raise ValueError('Missing Steam app cache terminator')


def roots(home):
    result = []
    for path in (home/'.local/share/Steam', home/'.steam/steam', home/'.steam/root',
                 home/'.var/app/com.valvesoftware.Steam/.local/share/Steam'):
        if path.is_dir() and path.resolve() not in result: result.append(path.resolve())
    return result


def libraries(root):
    path = root/'steamapps/libraryfolders.vdf'
    entries = text_vdf(read(path, 4*1024*1024)).get('libraryfolders', {}) if path.is_file() else {}
    result = {root: ''}
    for key, item in entries.items():
        if not key.isdecimal(): continue
        location = item.get('path', '') if isinstance(item, dict) else item
        library = Path(location)
        if not location or not library.is_absolute(): raise ValueError('Invalid Steam library location')
        result[library.resolve()] = item.get('contentid', '') if isinstance(item, dict) else ''
    return result


def manifest(path, library):
    app = path.stem.removeprefix('appmanifest_')
    if not re.fullmatch(r'[1-9][0-9]{0,9}', app): raise ValueError('Invalid Steam app ID')
    state = text_vdf(read(path, 1024*1024)).get('appstate', {})
    if state.get('appid') != app: raise ValueError('Steam manifest identity mismatch')
    name = state.get('name', '').strip()
    directory = state.get('installdir', '')
    if not name or len(name) > 512 or not directory or directory in ('.','..') or any(c in directory for c in '/\\\0'):
        raise ValueError('Invalid Steam game metadata')
    base = (library/'steamapps/common').resolve()
    install = (base/directory).resolve()
    # Users may move a game to another disk and retain a directory symlink.
    # Discovery is read-only; launch still goes through Steam's numeric app ID.
    # The manifest's directory component was validated above, so a link is not
    # an untrusted relative path supplied by metadata.
    flags = int(state.get('stateflags', '0'))
    available = bool(flags & 4) and install.is_dir()
    return dict(appId=app, title=name[:96], manifest=str(path.resolve()), installRoot=str(install),
                available=available, issue='' if available else 'Complete the installation in Steam or reconnect its storage.')


def discover(home=None):
    games = {}; warnings = []
    for root in roots(home or Path.home()):
        try: locations = libraries(root)
        except (OSError, ValueError, TypeError, AttributeError) as error:
            warnings.append('Steam library list could not be read. Existing games were retained.'); continue
        candidates = []
        for library, identity in locations.items():
            try:
                paths = sorted((library/'steamapps').glob('appmanifest_*.acf'))
                if len(paths) > 20000: raise ValueError('Too many Steam manifests')
                for path in paths:
                    try:
                        game = manifest(path, library)
                        game.update(steamRoot=str(root), libraryRoot=str(library), libraryId=identity)
                        candidates.append(game)
                    except (OSError, ValueError, TypeError, AttributeError):
                        warnings.append('A Steam manifest could not be read. Existing games were retained.')
            except OSError: warnings.append('A Steam library is unavailable. Reconnect its storage.')
        try: types = app_metadata(root/'appcache/appinfo.vdf', {g['appId'] for g in candidates})
        except (OSError, ValueError, IndexError, TypeError, AttributeError, struct.error):
            warnings.append('Steam game metadata is unavailable. Open Steam once and refresh the library.'); continue
        for game in candidates:
            metadata = types.get(game['appId'], {})
            if metadata.get('kind') not in ('game','demo','mod'): continue
            game['media'] = {k:v for k,v in metadata.items() if k != 'kind'}
            app = game['appId']; art = root/'appcache/librarycache'
            for name in (f'{app}/library_600x900.jpg', f'{app}/library_600x900_2x.jpg',
                         f'{app}_library_600x900.jpg', f'{app}/header.jpg', f'{app}_header.jpg'):
                image = art/name
                if image.is_file() and image.resolve().is_relative_to(art.resolve()):
                    game['artwork'] = image.resolve().as_uri(); break
            for key, names in {'marquee':(f'{app}/logo.png',f'{app}_logo.png'),
                               'fanart':(f'{app}/library_hero.jpg',f'{app}_library_hero.jpg')}.items():
                for name in names:
                    image = art/name
                    if image.is_file() and image.resolve().is_relative_to(art.resolve()):
                        game['media'][key] = image.resolve().as_uri(); break
            if app in games:
                # Never choose a duplicate by filesystem enumeration order.
                games[app]['available'] = False
                games[app]['issue'] = 'Steam reports this game in multiple libraries. Resolve the duplicate in Steam and refresh.'
            else: games[app] = game
    return dict(games=list(games.values()), warnings=sorted(set(warnings)))


if __name__ == '__main__':
    try:
        if sys.argv[1:] != ['scan']: raise ValueError('Unsupported Steam operation')
        print(json.dumps(discover(), ensure_ascii=False))
    except Exception:
        print(json.dumps({'error': 'Steam discovery failed. Existing games were retained.'})); sys.exit(1)
