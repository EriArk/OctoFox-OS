# SPDX-License-Identifier: GPL-3.0-or-later
"""Promote explicitly checked core candidates into new, unsigned offline media.

Does not mutate an installed runtime or clear redistribution/gameplay review.
The signed generation is produced separately with the normal release tools.
"""
import copy
import hashlib
import io
import json
from pathlib import Path
import tarfile

import fullbundle
import runtime_payload as payload

BUILD_RECORD = 'packaging/emulators/core-rebuild/promoted-builds.json'


def read_json(tar, name):
    member = tar.getmember(name)
    if not member.isfile() or member.size > 8 * 1024**2:
        raise ValueError('Invalid bounded metadata: ' + name)
    return json.load(tar.extractfile(member))


def verify_archive(path, expected):
    path = Path(path)
    if path.is_symlink() or path.stat().st_size != expected['bytes'] or payload.digest(path) != expected['sha256']:
        raise ValueError('Archive differs from pinned input')


def retained_records(bindings, builds):
    """Require a matching build record for every active identity we own."""
    rows = builds.get('cores', []) if builds else []
    records = {r['name']: r for r in rows}
    if len(records) != len(rows):
        raise ValueError('Duplicate retained build record')
    required = {Path(r['path']).name: r for r in bindings['cores']
                if (r.get('identity') or {}).get('record') == BUILD_RECORD}
    if set(records) != set(required):
        raise ValueError('Incomplete retained build records')
    for name, row in required.items():
        record = records[name]
        if (record.get('status') != 'built'
                or any(record.get(k) != row[k] for k in ('bytes', 'sha256'))
                or record.get('commit') != row['source']['commit']):
            raise ValueError('Retained build identity differs')
    return copy.deepcopy(records)


def component(base, base_record, bindings, candidate, candidate_record, native, output, prior_builds=None):
    """Keep every base info/other core; only replace pinned, native-loaded inputs."""
    base, candidate, output = Path(base), Path(candidate), Path(output)
    if output.exists() or output.is_symlink() or any(p.is_symlink() for p in output.parents):
        raise ValueError('Existing or redirected promotion output')
    if base_record.get('id') != 'retroarch-cores' or bindings.get('component') != 'retroarch-cores':
        raise ValueError('Expected core component')
    if bindings['archive'] != base_record['archive']:
        raise ValueError('Base source binding differs')
    verify_archive(base, base_record['archive'])
    verify_archive(candidate, candidate_record)
    old = {r['path']: r for r in base_record['files']}
    bound = {r['path']: r for r in bindings['cores']}
    if len(old) != len(base_record['files']) or len(bound) != len(bindings['cores']):
        raise ValueError('Duplicate base inventory')
    if {n for n in old if n.startswith('cores/')} != set(bound):
        raise ValueError('Incomplete base source bindings')
    for name, row in old.items():
        payload.relative(name)
        if not (name.startswith('cores/') and name.endswith('_libretro.so') or name.startswith('info/') and name.endswith('.info')):
            raise ValueError('Unexpected core component path')
        if name in bound and any(row[k] != bound[name][k] for k in ('bytes', 'sha256')):
            raise ValueError('Base core binding differs')
    checks = {r['file']: r for r in native['cores']}
    if len(checks) != len(native['cores']):
        raise ValueError('Duplicate native checks')
    promoted = copy.deepcopy(bindings)
    records = retained_records(bindings, prior_builds)
    with tarfile.open(candidate) as new, tarfile.open(base) as previous:
        inventory = read_json(new, 'candidate.json')
        expected = {r['path']: r for r in inventory['files']}
        members = new.getmembers()
        if (len(expected) != len(inventory['files']) or len(members) != len(expected) + 1
                or {m.name for m in members} != set(expected) | {'candidate.json'}):
            raise ValueError('Incomplete candidate inventory')
        for member in members:
            payload.relative(member.name)
            if not member.isfile():
                raise ValueError('Nonregular candidate member')
            if member.name == 'candidate.json':
                continue
            row = expected[member.name]
            with new.extractfile(member) as stream:
                if member.size != row['bytes'] or hashlib.file_digest(stream, 'sha256').hexdigest() != row['sha256']:
                    raise ValueError('Candidate member changed')
        plan = read_json(new, 'candidates.json')
        selection = read_json(new, 'selection.json')
        selected = {r['core']: r for r in plan['cores']}
        if (len(selected) != len(plan['cores']) or set(selection) != set(selected)
                or {n for n in expected if n.startswith('cores/')} != {'cores/' + n + '_libretro.so' for n in selected}):
            raise ValueError('Candidate selection differs')
        for name, spec in selected.items():
            path = 'cores/' + name + '_libretro.so'
            row = expected[path]
            if path not in old or any(old[path][k] != spec['previousBinary'][k] for k in ('bytes', 'sha256')):
                raise ValueError('Replacement does not match retained core')
            check = checks.get(Path(path).name, {})
            if check.get('exitCode') != 0 or any(check.get(k) != row[k] for k in ('bytes', 'sha256')):
                raise ValueError('Missing native check for exact candidate')
            attempts = read_json(new, 'build-records/' + selection[name] + '.json')['cores']
            matches = [r for r in attempts if r['core'] == name and r['status'] == 'built']
            if len(matches) != 1:
                raise ValueError('Missing selected build record')
            build = matches[0]
            if (any(build[k] != row[k] for k in ('bytes', 'sha256')) or build['commit'] != spec['commit']
                    or build.get('patches', []) != spec.get('patches', [])):
                raise ValueError('Selected build differs')
            records[Path(path).name] = {**build, 'name': Path(path).name}
            binding = next(r for r in promoted['cores'] if r['path'] == path)
            binding.update(bytes=row['bytes'], sha256=row['sha256'],
                           source={'id': spec['sourceId'], 'repository': spec['repository'], 'commit': spec['commit']},
                           identity={'kind': 'retained-build-record', 'record': BUILD_RECORD},
                           localMaterials=[BUILD_RECORD, 'packaging/emulators/core-rebuild/README.md',
                                           'packaging/emulators/core-rebuild/build.py',
                                           'packaging/emulators/core-rebuild/Dockerfile',
                                           'packaging/emulators/core-rebuild/aarch64.cmake',
                                           *['packaging/emulators/core-rebuild/' + p['file'] for p in spec.get('patches', [])]])
        # Validate all originals before creating output. No extractall or personal inputs.
        seen = set()
        for member in previous:
            if not member.isfile() or member.name not in old or member.name in seen:
                raise ValueError('Unexpected base member')
            row = old[member.name]
            with previous.extractfile(member) as stream:
                if member.size != row['bytes'] or hashlib.file_digest(stream, 'sha256').hexdigest() != row['sha256']:
                    raise ValueError('Base member changed')
            seen.add(member.name)
        if seen != set(old):
            raise ValueError('Incomplete base component')
        inputs = output / 'inputs'
        inputs.mkdir(parents=True)
        for name, row in old.items():
            source = new if name in expected and name.startswith('cores/') else previous
            target = inputs / name
            target.parent.mkdir(parents=True, exist_ok=True)
            with source.extractfile(name) as stream, target.open('xb') as dest:
                while chunk := stream.read(1024**2):
                    dest.write(chunk)
            target.chmod(row['mode'])
    expected_hashes = {r['path']: r['sha256'] for r in promoted['cores']}
    expected_hashes.update({n: r['sha256'] for n, r in old.items() if n.startswith('info/')})
    result = payload.build(inputs, ['cores', 'info'], output / 'component', 'retroarch-cores', expected_hashes,
                           {'replacedCores': sorted(selected), 'candidateSha256': candidate_record['sha256'],
                            'gameplayAcceptance': 'bounded native smoke only; see release evidence'})
    promoted['archive'] = result['archive']
    (output / 'core-source-bindings.json').write_text(json.dumps(promoted, indent=2) + '\n', encoding='utf-8')
    (output / 'promoted-builds.json').write_text(json.dumps({'schema': 1, 'cores': list(records.values())}, indent=2) + '\n', encoding='utf-8')
    return result, promoted


def media(base, base_identity, component_dir, candidate, candidate_identity, bindings, builds, output):
    """Replace cores and current bindings; retain every prior exact source kit."""
    base, output = Path(base), Path(output)
    if output.exists() or output.is_symlink() or any(p.is_symlink() for p in output.parents):
        raise ValueError('Existing or redirected runtime media')
    verify_archive(base, base_identity)
    verify_archive(candidate, candidate_identity)
    record = json.loads((Path(component_dir) / 'component.json').read_text())
    bound = json.loads(Path(bindings).read_text())
    if record.get('id') != 'retroarch-cores' or bound.get('archive') != record['archive']:
        raise ValueError('Replacement component binding differs')
    retained_records(bound, json.loads(Path(builds).read_text()))
    verify_archive(Path(component_dir) / 'component.tar.gz', record['archive'])
    fullbundle.verify(base)
    changes = {'runtimes/retroarch-cores/component.json': Path(component_dir) / 'component.json',
               'runtimes/retroarch-cores/component.tar.gz': Path(component_dir) / 'component.tar.gz'}
    metadata = {'sources/core-source-bindings.json': Path(bindings),
                'sources/core-promoted-builds.json': Path(builds)}
    with tarfile.open(base) as source:
        inventory = read_json(source, 'fullbundle.json')
        names = {r['path'] for r in inventory['files']}
        if not set(changes) <= names or len(names & set(metadata)) not in (0, len(metadata)):
            raise ValueError('Unexpected existing media layout')
        # The original fixed name remains readable. Later kits use their digest,
        # so a second promotion cannot discard the first promotion's sources.
        kit = ('sources/core-rebuild-' + candidate_identity['sha256'] + '.tar'
               if 'sources/core-rebuild-candidate.tar' in names else 'sources/core-rebuild-candidate.tar')
        if kit in names:
            raise ValueError('Candidate source kit already retained')
        changes.update(metadata)
        changes[kit] = Path(candidate)
        additions = set(changes) - names
        rows = {n: {'path': n, 'bytes': p.stat().st_size, 'sha256': payload.digest(p)} for n, p in changes.items()}
        inventory['files'] = [rows.get(r['path'], r) for r in inventory['files']] + [rows[n] for n in sorted(additions)]
        inventory['redistributionReviewed'] = False
        with tarfile.open(output, 'x:') as target:
            raw = (json.dumps(inventory, indent=2) + '\n').encode()
            info = tarfile.TarInfo('fullbundle.json'); info.size = len(raw); info.mode = 0o644
            target.addfile(info, io.BytesIO(raw))
            for row in inventory['files']:
                info = tarfile.TarInfo(row['path']); info.size = row['bytes']; info.mode = 0o644
                with (changes[row['path']].open('rb') if row['path'] in changes else source.extractfile(row['path'])) as stream:
                    target.addfile(info, stream)
    result = fullbundle.verify(output)
    return {**result, 'archive': {'bytes': output.stat().st_size, 'sha256': payload.digest(output)},
            'changedPaths': sorted(changes), 'installed': False, 'published': False}
