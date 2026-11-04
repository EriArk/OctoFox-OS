# SPDX-License-Identifier: GPL-3.0-or-later
"""Replace the legacy nested application source without changing runtime code."""
import io
import json
from pathlib import Path
import tarfile

import fullbundle
import source_archive

MEMBER = 'sources/corresponding-source-app.tar.gz'


def check(archive, revision):
    """Check the source actually inside runtime media, not a neighbouring archive."""
    with tarfile.open(archive) as tar:
        matches = [m for m in tar.getmembers() if m.name == MEMBER]
        if len(matches) != 1 or not matches[0].isfile():
            raise ValueError('Missing or ambiguous nested application source')
        with tar.extractfile(matches[0]) as stream:
            return source_archive.check(stream, revision)


def replace(archive, expected, filtered, revision, output):
    archive, filtered, output = Path(archive), Path(filtered), Path(output)
    if output.exists() or output.is_symlink() or any(p.is_symlink() for p in output.parents):
        raise ValueError('Use a new non-redirected source media output')
    if (archive.is_symlink() or archive.stat().st_size != expected['bytes']
            or fullbundle.payload.digest(archive) != expected['sha256']):
        raise ValueError('Runtime differs from pinned input')
    if filtered.is_symlink():
        raise ValueError('Redirected source input')
    source_archive.check(filtered, revision)
    fullbundle.verify(archive)
    replacement = {'path': MEMBER, 'bytes': filtered.stat().st_size,
                   'sha256': fullbundle.payload.digest(filtered)}
    with tarfile.open(archive) as source:
        index = json.load(source.extractfile('fullbundle.json'))
        if sum(r['path'] == MEMBER for r in index['files']) != 1:
            raise ValueError('Missing nested application source inventory')
        index['files'] = [replacement if r['path'] == MEMBER else r for r in index['files']]
        index['redistributionReviewed'] = False
        with tarfile.open(output, 'x:') as target:
            raw = (json.dumps(index, indent=2) + '\n').encode()
            entry = tarfile.TarInfo('fullbundle.json'); entry.size = len(raw); entry.mode = 0o644
            target.addfile(entry, io.BytesIO(raw))
            for row in index['files']:
                entry = tarfile.TarInfo(row['path']); entry.size = row['bytes']; entry.mode = 0o644
                with (filtered.open('rb') if row['path'] == MEMBER else source.extractfile(row['path'])) as stream:
                    target.addfile(entry, stream)
    fullbundle.verify(output)
    nested = check(output, revision)
    return {'file': output.name, 'bytes': output.stat().st_size,
            'sha256': fullbundle.payload.digest(output), 'changedPaths': [MEMBER],
            'source': nested, 'published': False, 'runtimeArtRedistributionReviewed': False}
