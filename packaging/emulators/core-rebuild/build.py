# SPDX-License-Identifier: GPL-3.0-or-later
"""Build explicitly pinned candidate cores inside the isolated cross-build image.

This operator tool never installs a runtime or modifies the release core lock.
Inputs are source_capsule archives and manifests; output directories must be new.
"""
import argparse
import concurrent.futures
import hashlib
import json
from pathlib import Path
import re
import shutil
import struct
import subprocess
import tarfile


def digest(path):
    with path.open('rb') as f:
        return hashlib.file_digest(f, 'sha256').hexdigest()


def build(row, root, attempt):
    name = row['core']
    if not re.fullmatch(r'[A-Za-z0-9_]+', name):
        raise ValueError('Invalid core name')
    if row['artifact'] != name + '_libretro.so' or not re.fullmatch(r'[0-9a-f]{40}', row['commit']):
        raise ValueError('Invalid candidate artifact or revision')
    source_id = row['sourceId']
    if not re.fullmatch(r'[A-Za-z0-9_-]+', source_id):
        raise ValueError('Invalid source id')
    metadata = json.loads((root / 'sources' / (source_id + '.json')).read_text())
    archive = root / 'sources' / metadata['file']
    if archive.parent != root / 'sources' or archive.is_symlink():
        raise ValueError('Invalid source archive')
    if (metadata['id'] != source_id or metadata['commit'] != row['commit'] or metadata['repository'] != row['repository']
            or archive.stat().st_size != metadata['bytes'] or digest(archive) != metadata['sha256']):
        raise ValueError('Source capsule differs from pinned candidate')
    work = root / 'attempts' / attempt / name
    work.mkdir(parents=True, exist_ok=False)
    with tarfile.open(archive) as t:
        t.extractall(work, filter='data')
    source = work / source_id
    directory = (source / row['directory']).resolve()
    if not directory.is_relative_to(source.resolve()) or not directory.is_dir():
        raise ValueError('Invalid build directory')
    output = root / 'artifacts' / attempt
    output.mkdir(parents=True, exist_ok=True)
    result = {'core': name, 'sourceId': source_id, 'buildSystem': row['buildSystem'], 'commit': row['commit'], 'sourceSha256': metadata['sha256'],
              'previousBinary': row['previousBinary'], 'installed': False,
              'runtimeAccepted': False, 'commands': []}
    log = work / 'build.log'
    try:
        if row['buildSystem'] == 'cmake':
            binary = work / 'cmake'
            commands = [['cmake', '-S', str(directory), '-B', str(binary), '-G', 'Ninja',
                         '-DCMAKE_TOOLCHAIN_FILE=' + str(root / 'aarch64.cmake'),
                         '-DCMAKE_BUILD_TYPE=Release', '-DCMAKE_POSITION_INDEPENDENT_CODE=ON',
                         *row['arguments']], ['cmake', '--build', str(binary), '-j2',
                         *(['--target', *row['targets']] if row.get('targets') else [])]]
        else:
            binary = source
            commands = [['make', '-C', str(directory), '-f', row['makefile'], '-j2', *row['arguments']]]
        with log.open('x') as stream:
            for command in commands:
                result['commands'].append(command)
                subprocess.run(command, stdout=stream, stderr=subprocess.STDOUT, check=True, timeout=1800)
        matches = list(binary.rglob(row['artifact']))
        if len(matches) != 1 or matches[0].is_symlink():
            raise ValueError('Expected exactly one regular core artifact')
        artifact = matches[0]
        with artifact.open('rb') as stream:
            header = stream.read(64)
        if header[:6] != b'\x7fELF\x02\x01' or len(header) != 64 or struct.unpack_from('<H', header, 18)[0] != 183:
            raise ValueError('Candidate is not an ARM64 ELF')
        target = output / row['artifact']
        with artifact.open('rb') as src, target.open('xb') as dst:
            shutil.copyfileobj(src, dst)
        result.update(status='built', bytes=target.stat().st_size, sha256=digest(target), artifact=target.name)
        result['dynamic'] = subprocess.check_output(['aarch64-linux-gnu-readelf', '-d', str(target)], text=True)
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired, ValueError) as exc:
        result.update(status='failed', error=str(exc))
    (work / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
    return result


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--root', type=Path, required=True)
    p.add_argument('--attempt', required=True)
    p.add_argument('--only', nargs='*')
    args = p.parse_args()
    if not re.fullmatch(r'[a-z0-9-]+', args.attempt):
        p.error('Use a new simple attempt identifier')
    root = args.root.resolve(strict=True)
    plan = json.loads((root / 'candidates.json').read_text())
    if plan['schema'] != 1 or plan['stage'] != 'candidate-only':
        raise ValueError('Not a candidate plan')
    rows = [r for r in plan['cores'] if not args.only or r['core'] in args.only]
    if not rows or (args.only and set(args.only) != {r['core'] for r in rows}):
        raise ValueError('Unknown selected core')
    report = root / (args.attempt + '.json')
    if report.exists() or (root / 'attempts' / args.attempt).exists():
        raise ValueError('Existing attempt retained; choose a new identifier')
    results = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        futures = {pool.submit(build, row, root, args.attempt): row['core'] for row in rows}
        for future in concurrent.futures.as_completed(futures):
            try:
                result = future.result()
            except Exception as exc:
                result = {'core': futures[future], 'status': 'failed', 'error': str(exc)}
            results.append(result)
            report.write_text(json.dumps({'schema': 1, 'attempt': args.attempt, 'cores': results}, indent=2) + '\n')
            print(result['core'], result['status'], result.get('error', result.get('sha256')), flush=True)
    raise SystemExit(any(r['status'] != 'built' for r in results))
