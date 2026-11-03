# SPDX-License-Identifier: GPL-3.0-or-later
"""Verify exact core/source bindings and package materials without running cores.

Embedded revisions identify upstream inputs, not compiler flags or local patches.
Unresolved cores remain visible; this tool never certifies redistribution.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path
import re
import struct
import tarfile
import source_capsule as source

CHUNK = 1024**2


def sha256(path):
    with Path(path).open('rb') as stream: return hashlib.file_digest(stream, 'sha256').hexdigest()


def pinned_file(root, name):
    source.relative(name)
    path = Path(root) / name
    if path.is_symlink() or not path.is_file() or not path.resolve().is_relative_to(Path(root).resolve()):
        raise ValueError('Missing or redirected source material: ' + name)
    return path


def identity(stream, row):
    checksum = hashlib.sha256(); size = 0; tail = b''; found = False
    binding = row['identity']
    if binding and binding['kind'] == 'embedded-marker':
        marker = binding['marker'].encode('ascii')
        if not 1 <= len(marker) <= 160 or b'\0' in marker: raise ValueError('Invalid embedded marker')
        abbreviation = binding['abbreviation']
        if not re.fullmatch('[0-9a-f]{7,40}', abbreviation) or abbreviation not in binding['marker']:
            raise ValueError('Marker does not contain the selected revision')
        if not row['source']['commit'].startswith(abbreviation): raise ValueError('Source revision differs from embedded marker')
        if binding['dirty'] is not ('-dirty' in binding['marker']): raise ValueError('Dirty source marker must remain explicit')
        # A C string can immediately follow binary tables, without a preceding
        # NUL (the real Citra revision does). Its terminator is still required.
        needle = marker + b'\0'
    elif binding and binding['kind'] != 'retained-build-record': raise ValueError('Unknown source identity route')
    else: needle = None
    while block := stream.read(CHUNK):
        if size == 0 and (len(block) < 64 or block[:6] != b'\x7fELF\x02\x01' or struct.unpack_from('<H', block, 18)[0] != 183):
            raise ValueError('Core must be an ARM64 ELF file')
        checksum.update(block); size += len(block)
        if size > row['bytes']: raise ValueError('Core exceeds pinned size')
        if needle:
            data = tail + block; found = found or needle in data; tail = data[-(len(needle) - 1):]
    if size != row['bytes'] or checksum.hexdigest() != row['sha256']: raise ValueError('Core differs from pinned bytes')
    if needle and not found: raise ValueError('Pinned marker is absent from this core')


def verify(archive, plan, capsules, checkout):
    archive, capsules, checkout = Path(archive), Path(capsules), Path(checkout)
    if plan['schema'] != 1 or plan['component'] != 'retroarch-cores': raise ValueError('Invalid core binding plan')
    if archive.is_symlink() or archive.stat().st_size != plan['archive']['bytes'] or sha256(archive) != plan['archive']['sha256']:
        raise ValueError('Core component archive differs from pinned release')
    rows = {source.relative(row['path']): row for row in plan['cores']}
    if not rows or len(rows) != len(plan['cores']) or any(not p.startswith('cores/') or not p.endswith('_libretro.so') for p in rows):
        raise ValueError('Duplicate or invalid core binding')
    for row in rows.values():
        if type(row['bytes']) is not int or not 1 <= row['bytes'] <= 1024**3 or not re.fullmatch('[0-9a-f]{64}', row['sha256']):
            raise ValueError('Invalid core binary identity')
        if bool(row['source']) != bool(row['identity']): raise ValueError('Source and identity route must be paired')
        if row['source']:
            source.revision(row['source']['commit']); source.repository(row['source']['repository'])
    seen = set()
    with tarfile.open(archive, 'r|gz') as tar:
        for member in tar:
            path = source.relative(member.name.rstrip('/') if member.isdir() else member.name)
            if not (member.isfile() or member.isdir()): raise ValueError('Unsafe core archive entry')
            if not path.endswith('.so'): continue
            if not member.isfile() or path not in rows or path in seen: raise ValueError('Unlisted or duplicate core in release')
            if member.size != rows[path]['bytes']: raise ValueError('Core size differs from binding')
            try:
                with tar.extractfile(member) as stream: identity(stream, rows[path])
            except ValueError as error:
                raise ValueError(path + ': ' + str(error)) from error
            seen.add(path)
    if seen != set(rows): raise ValueError('Core inventory is incomplete')
    result = []; files = {}; checked = {}
    def material(path, name, expected=None):
        checksum = sha256(path)
        if expected and checksum != expected: raise ValueError('Source capsule differs from inventory: ' + name)
        row = {'path': name, 'bytes': path.stat().st_size, 'sha256': checksum}
        if name in files and files[name][1] != row: raise ValueError('Conflicting source material name')
        files[name] = (path, row)
    def capsule(spec):
        source.revision(spec['commit']); source.repository(spec['repository'])
        if not re.fullmatch('[a-z0-9][a-z0-9_-]*', spec['id']): raise ValueError('Invalid source capsule id')
        if spec['id'] in checked:
            if checked[spec['id']] != (spec['repository'], spec['commit']): raise ValueError('Conflicting core source binding')
            return True
        record_path = capsules / (spec['id'] + '.json')
        if record_path.is_symlink(): raise ValueError('Redirected source capsule inventory')
        if not record_path.exists(): return False
        record_path = pinned_file(capsules, record_path.name)
        record = json.loads(record_path.read_text())
        if any(record[k] != spec[k] for k in ('id', 'repository', 'commit')): raise ValueError('Source capsule revision/repository differs')
        path = pinned_file(capsules, record['file'])
        if path.stat().st_size != record['bytes']: raise ValueError('Source capsule size differs')
        material(path, 'upstream/' + record['file'], record['sha256'])
        material(record_path, 'upstream/' + record_path.name)
        checked[spec['id']] = (spec['repository'], spec['commit']); return True
    for name, row in sorted(rows.items()):
        spec = row['source']; binding = row['identity']
        if bool(spec) != bool(binding): raise ValueError('Source and identity route must be paired')
        if spec and binding['kind'] == 'retained-build-record':
            record_path = pinned_file(checkout, binding['record'])
            record = json.loads(record_path.read_text())
            matches = [item for item in record['cores'] if item['name'] == Path(name).name]
            if len(matches) != 1 or any(matches[0][k] != row[k] for k in ('bytes', 'sha256')):
                raise ValueError('Retained build record does not identify this binary')
            material(record_path, 'traineros/' + binding['record'])
        collected = capsule(spec) if spec else False
        for local in row['localMaterials']:
            material(pinned_file(checkout, local), 'traineros/' + local)
        result.append({'path': name, 'sha256': row['sha256'], 'sourceId': spec['id'] if spec else None,
                       'status': 'upstream-source-collected' if collected else 'source-not-collected' if spec else 'identity-unresolved',
                       'dirtyMarker': bool(binding and binding.get('dirty')), 'localMaterials': row['localMaterials'],
                       'completeBinaryBuildReviewed': False})
    reference = plan['recipeReference']
    recipes = capsule(reference['source'])
    if recipes:
        spec = reference['source']
        record = json.loads(pinned_file(capsules, spec['id'] + '.json').read_text())
        with tarfile.open(pinned_file(capsules, record['file'])) as tar:
            member = tar.getmember(spec['id'] + '/' + source.relative(reference['file']))
            if not member.isfile() or member.size > 2 * CHUNK: raise ValueError('Invalid recipe reference')
            with tar.extractfile(member) as stream: checksum = hashlib.file_digest(stream, 'sha256').hexdigest()
            if checksum != reference['sha256']: raise ValueError('Recipe reference differs from pinned source')
    for name in ('LICENSE', 'LICENSING.md'):
        material(pinned_file(checkout, name), 'traineros/' + name)
    report = {'schema': 1, 'componentArchiveSha256': plan['archive']['sha256'], 'coreCount': len(result),
              'upstreamSourceCollected': sum(row['status'] == 'upstream-source-collected' for row in result),
              'identityUnresolved': sum(row['status'] == 'identity-unresolved' for row in result),
              'recipeReferenceCollected': recipes, 'cores': result,
              'completeCorrespondingSourceReviewed': False, 'redistributionReviewed': False,
              'files': [row for _, row in sorted(files.values(), key=lambda x: x[1]['path'])]}
    return report, files


def bundle(archive, plan_path, capsules, checkout, output):
    output = Path(output)
    if output.exists() or output.is_symlink(): raise ValueError('Existing source bundle retained')
    raw = Path(plan_path).read_bytes(); plan = json.loads(raw)
    report, files = verify(archive, plan, capsules, checkout)
    blobs = {'sources.json': (json.dumps(report, indent=2) + '\n').encode(), 'core-source-bindings.json': raw}
    with tarfile.open(output, 'x:') as tar:
        for name, data in blobs.items():
            member = tarfile.TarInfo(name); member.mode = 0o644; member.size = len(data)
            tar.addfile(member, io.BytesIO(data))
        for name, (path, row) in sorted(files.items()):
            member = tarfile.TarInfo(name); member.mode = 0o644; member.size = row['bytes']
            with path.open('rb') as stream: tar.addfile(member, stream)
    # Independently read back every entry; output is a candidate until this passes.
    with tarfile.open(output) as tar:
        expected = set(blobs) | set(files)
        if len(tar.getmembers()) != len(expected) or set(tar.getnames()) != expected: raise ValueError('Source bundle inventory differs')
        for member in tar:
            with tar.extractfile(member) as stream: checksum = hashlib.file_digest(stream, 'sha256').hexdigest()
            wanted = hashlib.sha256(blobs[member.name]).hexdigest() if member.name in blobs else files[member.name][1]['sha256']
            if checksum != wanted: raise ValueError('Source bundle changed during packaging')
    return {**report, 'file': output.name, 'bytes': output.stat().st_size, 'sha256': sha256(output), 'allEntriesReadBack': True}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('archive', 'plan', 'capsules', 'checkout', 'output', 'report'):
        parser.add_argument('--' + name, type=Path, required=True)
    args = parser.parse_args()
    result = bundle(args.archive, args.plan, args.capsules, args.checkout, args.output)
    args.report.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({k: result[k] for k in ('file', 'bytes', 'sha256', 'coreCount', 'upstreamSourceCollected', 'identityUnresolved')}))
