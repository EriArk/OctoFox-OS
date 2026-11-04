# SPDX-License-Identifier: GPL-3.0-or-later
"""Separate software source from avatar geometry with independent asset terms.

The original Git archive is retained. This does not clear runtime art rights or
claim complete corresponding source for separately distributed emulators.
"""
import argparse
import gzip
import hashlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import re
import tarfile
import tempfile

RECORD = 'TRAINEROS-SOURCE-CONTENTS.json'
MODEL_SUFFIXES = {'.blend', '.blend1', '.fbx', '.glb', '.gltf', '.obj', '.bin'}


def excluded(name):
    return name.startswith('assets/avatar/') and PurePosixPath(name).suffix.lower() in MODEL_SUFFIXES


def safe_name(name):
    if not name or name.startswith('/') or '\\' in name or any(p in ('', '.', '..') for p in name.split('/')):
        raise ValueError('Unsafe source archive path')
    return name


def check(archive, revision):
    """Reject wrong revisions and loose third-party geometry before publication."""
    if not re.fullmatch('[0-9a-f]{40}', revision): raise ValueError('Exact source revision required')
    with (tarfile.open(fileobj=archive) if hasattr(archive, 'read') else tarfile.open(archive)) as source:
        if source.pax_headers.get('comment') != revision: raise ValueError('Source archive revision differs from Software')
        seen = set()
        for member in source:
            name = safe_name(member.name.rstrip('/') if member.isdir() else member.name)
            if name in seen or excluded(name): raise ValueError('Duplicate source or separate avatar geometry in source archive: ' + name)
            if not (member.isfile() or member.isdir() or member.issym()): raise ValueError('Unsafe source archive type')
            if member.issym():
                if member.linkname.startswith('/') or '\\' in member.linkname: raise ValueError('External source symlink')
                parts = list(PurePosixPath(name).parent.parts)
                for part in member.linkname.split('/'):
                    if part == '..':
                        if not parts: raise ValueError('External source symlink')
                        parts.pop()
                    elif part not in ('', '.'): parts.append(part)
            seen.add(name)
        if not {'LICENSE', 'CMakeLists.txt', 'LICENSING.md'} <= seen: raise ValueError('Missing software source/build/licence material')
    return {'source': revision, 'entries': len(seen), 'separateAvatarGeometry': False}


def build(original, output):
    original, output = Path(original), Path(output)
    if original.is_symlink() or output.exists() or output.is_symlink(): raise ValueError('Original and output must be separate regular archive paths')
    output.parent.mkdir(parents=True, exist_ok=True)
    with tarfile.open(original) as source:
        revision = source.pax_headers.get('comment', '')
        if not re.fullmatch('[0-9a-f]{40}', revision): raise ValueError('Original Git archive must identify an exact revision')
        record = {'schema': 1, 'source': revision, 'included': [], 'omitted': [],
                  'omissionReason': 'Avatar geometry has separate asset terms; this is software source, not a standalone model library.',
                  'runtimeArtRedistributionReviewed': False}
        with tempfile.NamedTemporaryFile(dir=output.parent, prefix='.source-', delete=False) as f: temporary = Path(f.name)
        try:
            with temporary.open('wb') as raw, gzip.GzipFile(fileobj=raw, mode='wb', filename='', mtime=0) as gz:
                with tarfile.open(fileobj=gz, mode='w|', format=tarfile.PAX_FORMAT, pax_headers={'comment': revision}) as target:
                    seen = set()
                    for member in source:
                        name = safe_name(member.name.rstrip('/') if member.isdir() else member.name)
                        if name in seen or name == RECORD: raise ValueError('Duplicate source archive entry')
                        if not (member.isfile() or member.isdir() or member.issym()): raise ValueError('Unsupported source archive entry')
                        seen.add(name)
                        if excluded(name):
                            if not member.isfile(): raise ValueError('Avatar source geometry is not a regular file')
                            digest = hashlib.file_digest(source.extractfile(member), 'sha256').hexdigest()
                            record['omitted'].append({'path': name, 'bytes': member.size, 'sha256': digest})
                            continue
                        # Stream unmodified code/build/notices. A complete input-file
                        # digest is retained independently of gzip/tar metadata.
                        if member.isfile():
                            digest = hashlib.sha256()
                            class Reader:
                                def read(self, size=-1):
                                    block = incoming.read(size); digest.update(block); return block
                            with source.extractfile(member) as incoming:
                                target.addfile(member, Reader())
                            record['included'].append({'path': name, 'bytes': member.size, 'sha256': digest.hexdigest()})
                        else: target.addfile(member)
                    blob = (json.dumps(record, indent=2) + '\n').encode()
                    entry = tarfile.TarInfo(RECORD); entry.size = len(blob); entry.mode = 0o644
                    target.addfile(entry, io.BytesIO(blob))
            check(temporary, revision)
            os.link(temporary, output)
        finally: temporary.unlink(missing_ok=True)
    with output.open('rb') as stream: digest = hashlib.file_digest(stream, 'sha256').hexdigest()
    return {'source': revision, 'file': output.name, 'bytes': output.stat().st_size,
            'sha256': digest,
            'includedFiles': len(record['included']), 'omittedGeometryFiles': len(record['omitted']),
            'runtimeArtRedistributionReviewed': False}


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__); p.add_argument('original'); p.add_argument('output')
    args = p.parse_args(); print(json.dumps(build(args.original, args.output)))
