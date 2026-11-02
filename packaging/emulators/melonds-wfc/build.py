# SPDX-License-Identifier: GPL-3.0-or-later
"""Build the pinned WFC core into a NEW staging directory; never install it."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess

SOURCE = 'f394adbacb5722ee97c1b37c8064da9a25818310'
SETTINGS = 'ds-wfc-kaeru-owned-v1'
RECIPE = Path(__file__).resolve().parent


def git(source, *args):
    return subprocess.check_output(['git', '-C', str(source), *args]).decode().strip()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('build', type=Path)
    parser.add_argument('output', type=Path)
    parser.add_argument('--jobs', default=2, type=int)
    parser.add_argument('--cmake-arg', action='append', default=[])
    args = parser.parse_args()
    source, build, output = (p.resolve() for p in (args.source, args.build, args.output))
    if output.exists():
        raise SystemExit('Use a new staging directory; installed packages are never overwritten.')
    if git(source, 'rev-parse', 'HEAD') != SOURCE:
        raise SystemExit('Unexpected melonDS DS source revision')
    patch = RECIPE / '0001-register-console-mac.patch'
    diff = subprocess.check_output(['git', '-C', str(source), 'diff', 'HEAD'])
    if not diff:
        subprocess.run(['git', '-C', str(source), 'apply', '--check', str(patch)], check=True)
        subprocess.run(['git', '-C', str(source), 'apply', str(patch)], check=True)
    elif diff.replace(b'\r\n', b'\n') != patch.read_bytes().replace(b'\r\n', b'\n'):
        raise SystemExit('Unexpected source changes; preserve and review them first.')
    pins = json.loads((RECIPE / 'dependencies.json').read_text(encoding='utf-8-sig'))
    cmake = ['cmake', '-S', str(source), '-B', str(build), '-G', 'Ninja', *args.cmake_arg,
             '-DCMAKE_BUILD_TYPE=Release', '-DENABLE_OPENGL=OFF', '-DENABLE_JIT=ON', '-DBUILD_TESTING=OFF']
    for name, revision in pins.items():
        key = re.sub(r'[^A-Z0-9_]', '_', name.upper())
        cmake.append(f'-D{key}_REPOSITORY_TAG={revision}')
    subprocess.run(cmake, check=True)
    for name, revision in pins.items():
        dependency = build / '_deps' / (name + '-src')
        if git(dependency, 'rev-parse', 'HEAD') != revision or git(dependency, 'diff', 'HEAD'):
            raise SystemExit(f'Unexpected dependency: {name}')
    subprocess.run(['cmake', '--build', str(build), '-j', str(args.jobs)], check=True)
    cores = [build / 'src/libretro' / name for name in ('melondsds_libretro.so', 'melondsds_libretro.dll')]
    cores = [p for p in cores if p.is_file()]
    if len(cores) != 1:
        raise SystemExit('Expected exactly one platform core')
    core = cores[0]
    output.mkdir(parents=True)
    shutil.copy2(core, output / core.name)
    shutil.copy2(build / 'melondsds-LICENSE.txt', output / 'THIRD-PARTY-NOTICES.txt')
    shutil.copy2(RECIPE / 'dependencies.json', output / 'dependencies.json')
    shutil.copy2(patch, output / patch.name)
    manifest = dict(protocol=1, source=SOURCE, coreSource=pins['melonds'], settings=SETTINGS,
                    core=core.name, sha256=hashlib.sha256(core.read_bytes()).hexdigest())
    (output / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    print(f'Staged {core.name}. Run check.py before installation; retain sources and notices.')


if __name__ == '__main__':
    main()
