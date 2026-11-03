#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Maintainer-side runtime staging. Explicit code inputs, never a home backup.

The result is an operator candidate. It is not permission to redistribute a
component or to activate it on a player's installation.
"""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import tarfile


def digest(path):
    with Path(path).open('rb') as stream: return hashlib.file_digest(stream, 'sha256').hexdigest()


def relative(name):
    if not isinstance(name, str) or not name or '\\' in name or ':' in name or any(x in ('', '.', '..') for x in name.split('/')):
        raise ValueError('Invalid component path')
    p = PurePosixPath(name)
    if p.is_absolute(): raise ValueError('Invalid component path')
    return p


def selected(root, includes):
    root = Path(root).resolve(strict=True)
    result = {}
    for name in includes:
        path = root.joinpath(*relative(name).parts)
        if not path.exists(): raise ValueError('Missing component input: ' + name)
        entries = sorted(path.rglob('*')) if path.is_dir() else [path]
        for entry in entries:
            rel = entry.relative_to(root).as_posix()
            if '__pycache__' in entry.parts or entry.suffix == '.pyc': continue
            resolved = entry.resolve(strict=True)
            if not resolved.is_relative_to(root): raise ValueError('Component link escapes its source: ' + rel)
            if entry.is_dir(): continue
            if not resolved.is_file(): raise ValueError('Non-regular component input: ' + rel)
            result[rel] = resolved
    return result


def build(root, includes, output, identity, expected=None, metadata=None):
    output = Path(output)
    if output.exists(): raise ValueError('Use a new component destination')
    if any(p.is_symlink() for p in output.parents): raise ValueError('Redirected component destination')
    files = selected(root, includes)
    if not files: raise ValueError('Empty runtime component')
    records = []
    for name, path in files.items():
        sha = digest(path)
        if expected and name in expected and sha != expected[name]: raise ValueError('Changed runtime input: ' + name)
        records.append({'path': name, 'sha256': sha, 'bytes': path.stat().st_size,
                        'mode': 0o755 if path.stat().st_mode & 0o111 else 0o644})
    if expected and set(expected) - set(files): raise ValueError('Required runtime files were not selected')
    output.mkdir(parents=True)
    archive = output / 'component.tar.gz'
    with tarfile.open(archive, 'x:gz', compresslevel=3) as tar:
        for record in records:
            info = tarfile.TarInfo(record['path']); info.size = record['bytes']; info.mode = record['mode']
            with files[record['path']].open('rb') as stream: tar.addfile(info, stream)
    # Catch concurrent changes between the inventory and archive reads.
    with tarfile.open(archive) as tar:
        for member, record in zip(tar.getmembers(), records, strict=True):
            with tar.extractfile(member) as stream:
                if hashlib.file_digest(stream, 'sha256').hexdigest() != record['sha256']:
                    raise ValueError('Runtime input changed while packing')
    result = {'schema': 1, 'id': identity, 'target': 'linux-aarch64', 'files': records,
              'archive': {'bytes': archive.stat().st_size, 'sha256': digest(archive)},
              'metadata': metadata or {}, 'redistributionReviewed': False, 'installed': False}
    (output / 'component.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    return result


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--source', type=Path, required=True); p.add_argument('--output', type=Path, required=True)
    p.add_argument('--id', required=True); p.add_argument('--include', action='append', required=True)
    args = p.parse_args()
    print(json.dumps(build(args.source, args.include, args.output, args.id)))
