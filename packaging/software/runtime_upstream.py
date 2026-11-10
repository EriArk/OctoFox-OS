# SPDX-License-Identifier: GPL-3.0-or-later
"""Pinned upstream AppImages, downloaded before any installation transaction.

The descriptor lives in signed runtime media. Never follows a moving release
tag, executes a downloaded installer, or falls back to an unreviewed version.
"""
from pathlib import Path
import re
import shutil
import urllib.request
import urllib.error
import releases as sw

GITHUB_REPOSITORIES = {
    'DuckStation': 'stenzek/duckstation',
    'ARMSX2': 'ARMSX2/ARMSX2',
    'Azahar-Enhanced': 'virtudude/Azahar-AppImage-Enhanced',
    'Cemu': 'pkgforge-dev/Cemu-AppImage-Enhanced',
    'melonDS': 'virtudude/melonDS',
    'rpcs3': 'RPCS3/rpcs3-binaries-linux-arm64',
}


def validate(record):
    delivery = record.get('delivery', {})
    fields = set(delivery)
    if delivery.get('kind') == 'github-release-asset':
        if fields != {'kind', 'repository', 'assetId'}:
            raise ValueError('Unsupported upstream runtime delivery')
        if (record.get('id') not in GITHUB_REPOSITORIES
                or GITHUB_REPOSITORIES[record['id']] != delivery['repository']):
            raise ValueError('Unreviewed upstream runtime source')
        if not sw.integer(delivery['assetId'], 1, 2**53-1):
            raise ValueError('Upstream runtime requires a pinned asset ID')
    elif delivery.get('kind') == 'eden-release-file':
        if (fields != {'kind', 'url'} or record.get('id') != 'eden'
                or not isinstance(delivery['url'], str)
                or not re.fullmatch(r'https://stable\.eden-emu\.dev/v[0-9]+\.[0-9]+\.[0-9]+/'
                    r'Eden-Linux-v[0-9]+\.[0-9]+\.[0-9]+-aarch64-(clang-pgo|gcc-standard)\.AppImage', delivery['url'])):
            raise ValueError('Unreviewed upstream runtime source')
    else:
        raise ValueError('Unsupported upstream runtime delivery')
    rows = record.get('files', [])
    if len(rows) != 1 or set(rows[0]) != {'path', 'sha256', 'bytes', 'mode'}:
        raise ValueError('Upstream AppImage must have one exact file')
    row = rows[0]
    if (row['path'] != record['id'] + '.AppImage' or row['mode'] != 0o755
            or not isinstance(row['sha256'], str) or not sw.HASH.fullmatch(row['sha256'])
            or not sw.integer(row['bytes'], 1, 1024**3)):
        raise ValueError('Invalid upstream AppImage identity')
    if 'archive' in record:
        raise ValueError('Upstream runtime must not contain a repackaged archive')
    return row


def prepare(stage, record, progress=lambda *args: None, opener=None):
    row = validate(record)
    stage = Path(stage)
    cache = stage / 'downloads'
    if cache.is_symlink(): raise ValueError('Redirected runtime download cache')
    cache.mkdir(exist_ok=True)
    delivery = record['delivery']
    part = cache / (row['sha256'] + '.part')
    if shutil.disk_usage(cache).free < row['bytes'] * 2 + 16 * 1024**2:
        raise ValueError('Not enough space for upstream runtime and recovery')
    url = (delivery['url'] if delivery['kind'] == 'eden-release-file' else
           'https://api.github.com/repos/' + delivery['repository']
           + '/releases/assets/' + str(delivery['assetId']))
    fetch = opener or urllib.request.build_opener(sw.SecureRedirect()).open

    def binary(request, **kwargs):
        request.add_header('Accept', 'application/octet-stream')
        return fetch(request, **kwargs)

    progress('Downloading verified runtime: ' + record['id'])
    try:
        sw.download({'url': url, 'size': row['bytes'], 'sha256': row['sha256']}, part,
                    lambda phase, done, total: progress(
                        'Downloading ' + record['id'] + ': ' + str(done * 100 // max(1, total)) + '%'), binary)
    except urllib.error.HTTPError as error:
        error.close()
        raise ValueError('Cannot download the pinned ' + record['id'] + ' runtime (HTTP '
                         + str(error.code) + '). Check for an updated TrainerOS Setup. '
                         'No different emulator version was substituted.') from error
    # The existing component transaction checks the resulting file again and
    # projects it into the private runtime-home. No public repackaging occurs.
    return part
