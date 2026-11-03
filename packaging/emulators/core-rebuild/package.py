# SPDX-License-Identifier: GPL-3.0-or-later
"""Package all reviewed build outputs and pinned sources as an uninstalled candidate.

The archive is deliberately not Setup/runtime-set media. No installed core lock,
profile, software generation or device is changed by this operator tool.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path
import re
import tarfile


def digest(path):
    with path.open('rb') as f:
        return hashlib.file_digest(f, 'sha256').hexdigest()


def package(root, output, attempts, probe_path):
    root = root.resolve(strict=True)
    if output.exists() or output.is_symlink():
        raise ValueError('Existing candidate retained')
    plan = json.loads((root / 'candidates.json').read_text())
    if plan['schema'] != 1 or plan['stage'] != 'candidate-only':
        raise ValueError('Expected candidate plan')
    probes = json.loads(probe_path.read_text())['cores']
    selection = json.loads((root / 'selection.json').read_text())
    if set(selection) != {row['core'] for row in plan['cores']} or not set(selection.values()) <= set(attempts):
        raise ValueError('Explicit candidate selection is incomplete')
    results = {}
    files = {}
    def add(path, name, expected=None):
        if not path.is_file() or path.is_symlink() or not path.resolve().is_relative_to(root):
            raise ValueError('Missing or redirected candidate material')
        actual = {'path': name, 'bytes': path.stat().st_size, 'sha256': digest(path)}
        if expected and any(actual[k] != expected[k] for k in ('bytes', 'sha256')):
            raise ValueError('Candidate material differs from verified input: ' + name)
        if name in files:
            raise ValueError('Duplicate candidate member')
        files[name] = (path, actual)
    for attempt in attempts:
        if not re.fullmatch('[a-z0-9-]+', attempt):
            raise ValueError('Invalid attempt identifier')
        path = root / (attempt + '.json')
        for row in json.loads(path.read_text())['cores']:
            if row['status'] == 'built' and selection.get(row['core']) == attempt:
                if row['core'] in results:
                    raise ValueError('Ambiguous build selection')
                results[row['core']] = (attempt, row)
        add(path, 'build-records/' + path.name)
    expected_names = {row['core'] for row in plan['cores']}
    if set(results) != expected_names or len(expected_names) != len(plan['cores']):
        raise ValueError('Candidate set is incomplete or contains extra cores')
    if len(probes) != len(expected_names) or len({p['file'] for p in probes}) != len(probes):
        raise ValueError('Candidate probes are incomplete or duplicated')
    for spec in plan['cores']:
        attempt, row = results[spec['core']]
        if (row['commit'] != spec['commit'] or row['artifact'] != spec['core'] + '_libretro.so'
                or row['previousBinary'] != spec['previousBinary']
                or row.get('patches', []) != spec.get('patches', [])):
            raise ValueError('Candidate build identity differs')
        for patch in spec.get('patches', []):
            name = patch['file']
            if not re.fullmatch(r'patches/[a-z0-9_-]+\.patch', name):
                raise ValueError('Invalid candidate patch path')
            path = root / name
            if digest(path) != patch['sha256']:
                raise ValueError('Candidate patch differs from build')
            add(path, name)
        probe = next((p for p in probes if p['file'] == row['artifact']), None)
        if not probe or probe['status'] != 'abi-loaded' or any(probe[k] != row[k] for k in ('bytes', 'sha256')):
            raise ValueError('Missing successful probe of exact candidate')
        add(root / 'artifacts' / attempt / row['artifact'], 'cores/' + row['artifact'], row)
        source_id = spec['sourceId']
        if not re.fullmatch('[a-z0-9_-]+', source_id):
            raise ValueError('Invalid source id')
        meta_path = root / 'sources' / (source_id + '.json')
        meta = json.loads(meta_path.read_text())
        if any(meta[k] != spec[k] for k in ('repository', 'commit')) or meta['sha256'] != row['sourceSha256']:
            raise ValueError('Source identity differs from build')
        if Path(meta['file']).name != meta['file']:
            raise ValueError('Invalid source filename')
        add(root / 'sources' / meta['file'], 'sources/' + meta['file'], meta)
        add(meta_path, 'sources/' + meta_path.name)
        add(root / 'attempts' / attempt / spec['core'] / 'build.log', 'build-logs/' + spec['core'] + '.log')
    for path in sorted((root / 'recipes').rglob('*')):
        if path.is_file():
            add(path, 'recipes/' + path.relative_to(root / 'recipes').as_posix())
    for name in ('candidates.json', 'toolchains.json', 'selection.json'):
        add(root / name, name)
    for path in sorted(root.glob('toolchain-packages*.tsv')):
        add(path, path.name)
    add(probe_path, 'abi-probes.json')
    report = {'schema': 1, 'kind': 'core-rebuild-candidate-only', 'coreCount': len(results),
              'installed': False, 'gameplayAccepted': False, 'redistributionReviewed': False,
              'files': [v[1] for _, v in sorted(files.items())]}
    blob = (json.dumps(report, indent=2) + '\n').encode()
    with tarfile.open(output, 'x:') as t:
        info = tarfile.TarInfo('candidate.json'); info.size = len(blob); info.mode = 0o644
        t.addfile(info, io.BytesIO(blob))
        for name, (path, row) in sorted(files.items()):
            info = tarfile.TarInfo(name); info.size = row['bytes']; info.mode = 0o644
            with path.open('rb') as stream:
                t.addfile(info, stream)
    with tarfile.open(output) as t:
        if len(t.getmembers()) != len(files) + 1 or set(t.getnames()) != set(files) | {'candidate.json'}:
            raise ValueError('Candidate archive inventory differs')
        for member in t:
            with t.extractfile(member) as stream:
                checksum = hashlib.file_digest(stream, 'sha256').hexdigest()
            expected = hashlib.sha256(blob).hexdigest() if member.name == 'candidate.json' else files[member.name][1]['sha256']
            if checksum != expected:
                raise ValueError('Candidate archive readback failed')
    return {**report, 'file': output.name, 'bytes': output.stat().st_size,
            'sha256': digest(output), 'allEntriesReadBack': True}


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--root', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--attempts', nargs='+', required=True)
    p.add_argument('--probes', type=Path, required=True)
    p.add_argument('--report', type=Path, required=True)
    args = p.parse_args()
    if args.report.exists() or args.report.is_symlink():
        p.error('Existing candidate report retained')
    result = package(args.root, args.output, args.attempts, args.probes)
    args.report.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({k: result[k] for k in ('file', 'bytes', 'sha256', 'coreCount')}))
