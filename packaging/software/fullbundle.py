#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Assemble and verify operator offline media from explicitly selected artifacts.

This is not the public installer/signing command. Unreviewed components stay
marked as such; collecting artifacts never grants redistribution permission or
activates a runtime. Paths in the published inventory are relative, not host paths.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path
import tarfile
import runtime_payload as payload

MAX_FILES = 30000
MAX_BYTES = 32 * 1024**3


def inventory(plan):
    result = []; names = set(); total = 0
    if plan.get('schema') != 1 or not 1 <= len(plan['files']) <= MAX_FILES:
        raise ValueError('Invalid offline collection plan')
    for row in plan['files']:
        name = str(payload.relative(row['path']))
        if name in names or name == 'fullbundle.json': raise ValueError('Duplicate media path')
        source = Path(row['source'])
        if source.is_symlink() or not source.is_file(): raise ValueError('Expected a regular artifact')
        checksum = payload.digest(source)
        if checksum != row['sha256']: raise ValueError('Artifact changed: ' + name)
        size = source.stat().st_size; total += size
        if total > MAX_BYTES: raise ValueError('Offline media exceeds size limit')
        result.append({'path': name, 'bytes': size, 'sha256': checksum})
        names.add(name)
    return result


def verify(archive):
    with tarfile.open(archive, 'r:') as tar:
        member = tar.next()
        if not member or not member.isfile() or member.name != 'fullbundle.json' or member.size > 8 * 1024**2:
            raise ValueError('Missing bounded offline inventory')
        record = json.load(tar.extractfile(member))
        if record.get('schema') != 1 or record.get('product') != 'traineros-offline-candidate':
            raise ValueError('Unknown offline media')
        rows = record['files']
        if not 1 <= len(rows) <= MAX_FILES: raise ValueError('Invalid artifact count')
        expected = {}
        for row in rows:
            name = str(payload.relative(row['path']))
            if name in expected or type(row['bytes']) is not int or row['bytes'] < 0:
                raise ValueError('Invalid media inventory')
            expected[name] = row
        if sum(r['bytes'] for r in rows) > MAX_BYTES: raise ValueError('Oversized media')
        seen = set()
        while (member := tar.next()) is not None:
            if member.name not in expected or member.name in seen or not member.isfile():
                raise ValueError('Unexpected archive entry')
            row = expected[member.name]
            if member.size != row['bytes']: raise ValueError('Artifact size mismatch')
            with tar.extractfile(member) as stream:
                if hashlib.file_digest(stream, 'sha256').hexdigest() != row['sha256']:
                    raise ValueError('Artifact content mismatch: ' + member.name)
            seen.add(member.name)
        if seen != set(expected): raise ValueError('Offline media is incomplete')
    return {'files': len(rows), 'bytes': sum(r['bytes'] for r in rows),
            'redistributionReviewed': record.get('redistributionReviewed', False)}


def build(plan, output):
    output = Path(output)
    if output.exists() or any(p.is_symlink() for p in output.parents):
        raise ValueError('Use a new, non-redirected output directory')
    files = inventory(plan)
    record = {'schema': 1, 'product': 'traineros-offline-candidate',
              'target': 'linux-aarch64', 'redistributionReviewed': False,
              'installerAcceptance': False, 'files': files}
    output.mkdir(parents=True)
    archive = output / 'TrainerOS-Full-CANDIDATE.tar'
    raw = (json.dumps(record, indent=2) + '\n').encode()
    with tarfile.open(archive, 'x:', format=tarfile.PAX_FORMAT) as tar:
        info = tarfile.TarInfo('fullbundle.json'); info.size = len(raw); info.mode = 0o644
        tar.addfile(info, io.BytesIO(raw))
        for row, original in zip(files, plan['files'], strict=True):
            info = tarfile.TarInfo(row['path']); info.size = row['bytes']; info.mode = 0o644
            with Path(original['source']).open('rb') as stream: tar.addfile(info, stream)
    result = verify(archive)  # Also detects input mutation during collection.
    checksum = payload.digest(archive)
    (output / 'fullbundle.json').write_bytes(raw)
    (output / 'SHA256SUMS').write_text(checksum + '  ' + archive.name + '\n')
    return {**result, 'archive': archive.name, 'sha256': checksum, 'archiveBytes': archive.stat().st_size}


def split(archive, output, part_bytes=1800 * 1024**2):
    """Prepare bounded release assets without changing the complete offline file."""
    archive, output = Path(archive), Path(output)
    if not 1 <= part_bytes < 2 * 1024**3: raise ValueError('Parts must be smaller than 2 GiB')
    if archive.is_symlink() or not archive.is_file() or not 1 <= archive.stat().st_size <= MAX_BYTES:
        raise ValueError('Invalid media archive')
    if (archive.stat().st_size + part_bytes - 1) // part_bytes > 1000: raise ValueError('Too many release parts')
    if output.exists() or any(p.is_symlink() for p in output.parents): raise ValueError('Use a new parts directory')
    output.mkdir(parents=True); rows = []; complete = hashlib.sha256(); total = 0
    with archive.open('rb') as source:
        while chunk := source.read(min(1024**2, part_bytes)):
            name = 'TrainerOS-Full.tar.part' + str(len(rows) + 1).zfill(3)
            size = 0; digest = hashlib.sha256()
            with (output / name).open('xb') as part:
                while chunk:
                    part.write(chunk); digest.update(chunk); complete.update(chunk)
                    size += len(chunk); total += len(chunk)
                    if total > MAX_BYTES: raise ValueError('Media grew beyond size limit')
                    if size == part_bytes: break
                    chunk = source.read(min(1024**2, part_bytes - size))
            rows.append({'path': name, 'bytes': size, 'sha256': digest.hexdigest()})
    result = {'schema': 1, 'product': 'traineros-offline-parts', 'bytes': total,
              'sha256': complete.hexdigest(), 'parts': rows, 'published': False}
    (output / 'parts.json').write_text(json.dumps(result, indent=2) + '\n')
    verify_parts(output / 'parts.json')
    return result


def verify_parts(index):
    index = Path(index); record = json.loads(index.read_text())
    if record.get('schema') != 1 or record.get('product') != 'traineros-offline-parts': raise ValueError('Invalid parts inventory')
    if not 1 <= len(record['parts']) <= 1000: raise ValueError('Invalid part count')
    complete = hashlib.sha256(); total = 0; seen = set()
    for row in record['parts']:
        if type(row['bytes']) is not int or not 1 <= row['bytes'] < 2 * 1024**3:
            raise ValueError('Invalid part size')
        name = str(payload.relative(row['path']))
        if '/' in name or name in seen: raise ValueError('Invalid part name')
        seen.add(name); path = index.parent / name
        if path.is_symlink() or not path.is_file() or path.stat().st_size != row['bytes']:
            raise ValueError('Missing or changed media part')
        digest = hashlib.sha256()
        with path.open('rb') as source:
            while chunk := source.read(1024**2):
                digest.update(chunk); complete.update(chunk); total += len(chunk)
                if total > MAX_BYTES: raise ValueError('Media exceeds size limit')
        if digest.hexdigest() != row['sha256']: raise ValueError('Media part checksum mismatch')
    if total != record['bytes'] or complete.hexdigest() != record['sha256']:
        raise ValueError('Combined media checksum mismatch')
    return {'parts': len(seen), 'bytes': total, 'sha256': complete.hexdigest()}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    p = commands.add_parser('build'); p.add_argument('--plan', type=Path, required=True); p.add_argument('--output', type=Path, required=True)
    p = commands.add_parser('verify'); p.add_argument('archive', type=Path)
    p = commands.add_parser('split'); p.add_argument('archive', type=Path); p.add_argument('--output', type=Path, required=True)
    p = commands.add_parser('verify-parts'); p.add_argument('index', type=Path)
    args = parser.parse_args()
    if args.command == 'build': result = build(json.loads(args.plan.read_text()), args.output)
    elif args.command == 'split': result = split(args.archive, args.output)
    elif args.command == 'verify-parts': result = verify_parts(args.index)
    else: result = verify(args.archive)
    print(json.dumps(result))
