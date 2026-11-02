#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Prepare a versioned ARM64 delivery archive directory without accessing devices.

The wheelhouse must contain the reviewed CPython 3.14 aarch64 dependencies from
install-transport.sh. Installation remains explicit and writes a new directory.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import gzip


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('frontend', 'wheelhouse', 'output'):
        parser.add_argument(name, type=Path)
    parser.add_argument('--sha256', required=True)
    parser.add_argument('--source', type=Path, required=True, help='Pinned, patched melonDS tree')
    args = parser.parse_args()
    revision='906e9ebb27da8c6a715cd7abab4abfe8a8d29427'
    if subprocess.check_output(['git','-C',str(args.source),'rev-parse','HEAD'],text=True).strip()!=revision:
        raise SystemExit('Unexpected melonDS source')
    header = args.frontend.read_bytes()[:20]
    if header[:6] != b'\x7fELF\x02\x01' or int.from_bytes(header[18:20], 'little') != 183 or sha(args.frontend) != args.sha256:
        raise SystemExit('Expected the reviewed little-endian ELF64 AArch64 frontend')
    wheels = sorted(args.wheelhouse.glob('*.whl'))
    if not wheels or any(not (p.name.endswith('-none-any.whl') or p.name.endswith('_aarch64.whl')) for p in wheels):
        raise SystemExit('Expected an ARM64/pure-Python wheelhouse')
    root = args.output.resolve()
    if root.exists() or args.output.is_symlink():
        raise SystemExit('Choose a new staging directory')
    root.mkdir(parents=True)
    shutil.copyfile(args.frontend, root / 'traineros-ds')
    (root / 'traineros-ds').chmod(0o700)
    recipe = Path(__file__).resolve().parent
    for family in ('melonds', 'handheld'):
        destination = root / 'recipe' / family
        destination.mkdir(parents=True)
        names = ('install-runtime.py', 'install-transport.sh', 'secure-channel.py') if family == 'melonds' else ('linked-save-requirements.txt',)
        for name in names:
            shutil.copyfile(recipe.parent / family / name, destination / name)
    (root / 'wheels').mkdir()
    for wheel in wheels:
        shutil.copyfile(wheel, root / 'wheels' / wheel.name)
    (root / 'source').mkdir()
    shutil.copyfile(args.source / 'LICENSE', root / 'LICENSE.melonDS')
    archive = subprocess.check_output(['git','-C',str(args.source),'archive','--format=tar','HEAD'])
    with gzip.open(root / 'source' / 'melonds-upstream.tar.gz','wb') as output:
        output.write(archive)
    for path in recipe.iterdir():
        if path.is_file():
            destination=root / 'source' / 'recipe' / 'melonds' / path.name
            destination.parent.mkdir(parents=True,exist_ok=True)
            shutil.copyfile(path,destination)
    destination=root / 'source' / 'recipe' / 'dolphin'
    destination.mkdir()
    shutil.copyfile(recipe.parent / 'dolphin' / 'arm64-fedora44.cmake',destination / 'arm64-fedora44.cmake')
    installer = '''#!/bin/sh
set -eu
base=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
test "$(uname -m)" = aarch64 || { echo 'This package requires ARM64 Linux' >&2; exit 1; }
python3 -c 'import sys; assert sys.version_info[:2] == (3,14), "This wheelhouse requires Python 3.14"'
(cd "$base" && sha256sum --quiet -c SHA256SUMS)
export PIP_NO_INDEX=1
export PIP_FIND_LINKS="$base/wheels"
exec python3 "$base/recipe/melonds/install-runtime.py" --frontend "$base/traineros-ds" --sha256 HASH --directory "${1:?New absolute version directory required}"
'''.replace('HASH', args.sha256)
    (root / 'install.sh').write_text(installer, encoding='utf-8')
    (root / 'install.sh').chmod(0o700)
    manifest = dict(source=revision, settings='detmp-group-owned-v2',
                    architecture='aarch64', python='3.14', frontendSha256=args.sha256,
                    installed=False, note='Run install.sh on the target to create a fresh private runtime version; select it separately.')
    (root / 'delivery.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    files = sorted(p for p in root.rglob('*') if p.is_file())
    (root / 'SHA256SUMS').write_text(''.join(f'{sha(p)}  {p.relative_to(root).as_posix()}\n' for p in files), encoding='utf-8')
    print('Staged offline ARM64 delivery; no installed profile or saves changed')


if __name__ == '__main__':
    main()
