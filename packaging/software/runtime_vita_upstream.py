# SPDX-License-Identifier: GPL-3.0-or-later
"""Exact original Vita runtime; TrainerOS wrappers stay in the signed component."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import urllib.request
import releases as sw

SPEC = {'repository': 'Vita3K/Vita3K-builds', 'assetId': 630852874,
        'bytes': 70814216, 'sha256': '8a6b8ec4b65cc6769d69e4a48449d286ecd564ebe3a945a39218d0fa5ae3bf58',
        'squashfsOffset': 936456}


def rows(record):
    if record.get('id') != 'vita3k-netplay' or record.get('upstreamRuntime') != SPEC:
        raise ValueError('Unreviewed native upstream runtime')
    # AppRun.wrapped has our owned-process/argument fix and stays bundled.
    selected = [r for r in record['files'] if r['path'].startswith('runtime/')
                and r['path'] != 'runtime/AppRun.wrapped']
    if not selected or not any(r['path'] == 'runtime/usr/bin/Vita3K' for r in selected):
        raise ValueError('Missing original Vita runtime inventory')
    from runtime_payload import relative
    for row in selected: relative(row['path'])
    return selected


def prepare(stage, record, target, progress=lambda *args: None, opener=None, runner=subprocess.run):
    selected = rows(record)
    cache = Path(stage) / 'downloads'
    if cache.is_symlink(): raise ValueError('Redirected Vita download cache')
    cache.mkdir(exist_ok=True)
    image = cache / (SPEC['sha256'] + '.part')
    if shutil.disk_usage(cache).free < 1024**3: raise ValueError('Not enough space for Vita runtime preparation')
    fetch = opener or urllib.request.build_opener(sw.SecureRedirect()).open
    def binary(request, **kwargs):
        request.add_header('Accept', 'application/octet-stream')
        return fetch(request, **kwargs)
    sw.download({'url': 'https://api.github.com/repos/' + SPEC['repository'] + '/releases/assets/' + str(SPEC['assetId']),
                 'size': SPEC['bytes'], 'sha256': SPEC['sha256']}, image,
                lambda phase, done, total: progress('Downloading Vita3K: ' + str(done * 100 // max(1, total)) + '%'), binary)
    progress('Preparing verified Vita3K runtime')
    # Read the pinned SquashFS as data. Never execute an AppImage to unpack it.
    with tempfile.TemporaryDirectory(dir=cache, prefix='.vita-') as tmp:
        extracted = Path(tmp) / 'runtime'
        result = runner(['unsquashfs', '-no-progress', '-processors', '2', '-o', str(SPEC['squashfsOffset']),
                         '-d', str(extracted), str(image)], capture_output=True, text=True, timeout=180)
        if result.returncode: raise ValueError('Vita runtime extraction failed: ' + result.stderr[-2000:])
        for row in selected:
            source = Path(tmp) / row['path']
            resolved = source.resolve(strict=True)
            if (not resolved.is_relative_to(extracted) or not resolved.is_file()
                    or resolved.stat().st_size != row['bytes'] or sw.sha256(resolved) != row['sha256']):
                raise ValueError('Original Vita runtime differs: ' + row['path'])
            output = Path(target) / row['path']
            if output.exists() or output.is_symlink(): raise ValueError('Duplicate Vita runtime input')
            output.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(resolved, output); output.chmod(row['mode'])
