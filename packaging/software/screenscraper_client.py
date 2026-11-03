# SPDX-License-Identifier: GPL-3.0-or-later
"""Validate the distributable ScreenScraper application identity, never accounts.

The input is provided privately by the release operator, outside the source tree.
The resulting client identity is shipped to users and is therefore extractable.
It is not a vault or a mechanism for distributing personal ScreenScraper logins.
"""
import json
from pathlib import Path

RELATIVE_PATH = Path('share/traineros/integrations/screenscraper-client.json')


def read(path):
    path = Path(path)
    if path.is_symlink() or not path.is_file() or path.stat().st_size > 8192:
        raise ValueError('Missing or invalid ScreenScraper application identity')
    try:
        def unique(pairs):
            result = {}
            for key, value in pairs:
                if key in result:
                    raise ValueError('Duplicate key')
                result[key] = value
            return result
        record = json.loads(path.read_text(encoding='utf-8'), object_pairs_hook=unique)
    except (ValueError, UnicodeError):
        raise ValueError('Invalid ScreenScraper application identity') from None
    if (not isinstance(record, dict)
            or set(record) != {'version', 'developerId', 'developerPassword'}
            or type(record['version']) is not int or record['version'] != 1):
        raise ValueError('ScreenScraper payload must contain only application credentials, never user accounts')
    for key in ('developerId', 'developerPassword'):
        value = record[key]
        if not isinstance(value, str) or not 1 <= len(value) <= 256 or '\0' in value:
            raise ValueError('Invalid ScreenScraper application identity')
    return record


def stage(path, payload):
    record = read(path)
    target = Path(payload) / RELATIVE_PATH
    if target.exists() or target.is_symlink() or any(p.is_symlink() for p in target.parents):
        raise ValueError('ScreenScraper payload target already exists or is redirected')
    target.parent.mkdir(parents=True, exist_ok=True)
    with target.open('x', encoding='utf-8') as stream:
        json.dump(record, stream, ensure_ascii=True, sort_keys=True)
        stream.write('\n')
    target.chmod(0o644)
