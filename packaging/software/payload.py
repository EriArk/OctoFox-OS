#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Stage a native CMake install and its private Files library, without publishing.

Run inside the same ARM64 builder as CMake. Never collect files from a player's
home directory. The separate publisher still requires redistribution review.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import struct
import screenscraper_client
import avatar_resources


def output(args):
    return subprocess.check_output(args, text=True, timeout=30).strip()


def stage(build, destination, screenscraper=None):
    build, destination = Path(build).resolve(), Path(destination).absolute()
    if destination.exists(): raise ValueError('Use a new empty staging destination')
    if any(p.is_symlink() for p in destination.parents): raise ValueError('Redirected staging destination')
    report = destination.with_name(destination.name + '.staging.json')
    if report.exists(): raise ValueError('Staging report already exists')
    if screenscraper is not None: screenscraper_client.read(screenscraper)
    with (build / 'traineros').open('rb') as stream: header = stream.read(64)
    if len(header) < 64 or header[:6] != b'\x7fELF\x02\x01' or struct.unpack_from('<H', header, 18)[0] != 183:
        raise ValueError('The release builder requires an ARM64 application')
    cache = (build / 'CMakeCache.txt').read_text()
    match = re.search(r'^FILES_FM_QT_LIBRARY:FILEPATH=(.+)$', cache, re.M)
    if not match: raise ValueError('The build has no Files runtime library')
    library = Path(match[1]).resolve(strict=True)
    dynamic = output(['readelf', '-d', str(library)])
    soname = re.search(r'\(SONAME\).*?\[([^]]+)\]', dynamic)
    if not soname or not re.fullmatch(r'libfm-qt6\.so\.[0-9]+', soname[1]):
        raise ValueError('Unexpected Files library SONAME')
    dependencies = output(['ldd', str(library)])
    menu = re.search(r'libmenu-cache\.so\.3 => (\S+)', dependencies)
    if not menu or not Path(menu[1]).is_file(): raise ValueError('Missing Files menu-cache dependency')
    libraries = [(soname[1], library), ('libmenu-cache.so.3', Path(menu[1]).resolve(strict=True))]
    records, licenses = [], set()
    for name, path in libraries:
        package = output(['rpm', '-qf', '--qf', '%{NAME}', str(path)])
        notices = {Path(p) for p in output(['rpm', '-ql', package]).splitlines()
                   if p.startswith('/usr/share/licenses/') and Path(p).is_file()}
        if not notices: raise ValueError('Missing runtime licence files: ' + package)
        licenses.update(notices)
        records.append({'soname': name, 'sourcePackage': output(['rpm', '-qf', '--qf', '%{SOURCERPM}', str(path)]),
                        'package': output(['rpm', '-q', package]), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
    destination.mkdir(parents=True, mode=0o700)
    subprocess.run(['cmake', '--install', str(build), '--prefix', str(destination)], check=True)
    avatar_resources.validate(destination / 'share/traineros/avatar/packs')
    if screenscraper is not None: screenscraper_client.stage(screenscraper, destination)
    # The managed launcher and dependency preflight expose this signed lib
    # directory. RUNPATH alone does not resolve libfm's transitive menu-cache.
    for name, path in libraries:
        target = destination / 'lib' / name
        target.parent.mkdir(parents=True, exist_ok=True); shutil.copyfile(path, target); target.chmod(0o755)
    for source in sorted(licenses):
        target = destination / source.relative_to('/usr')
        target.parent.mkdir(parents=True, exist_ok=True); shutil.copyfile(source, target); target.chmod(0o644)
    files = []
    for path in sorted(destination.rglob('*')):
        if path.is_symlink(): raise ValueError('Unexpected symlink in staged payload: ' + str(path))
        if path.is_file(): files.append(path)
    # This report is deliberately outside the signed payload. It is preparation,
    # not an assertion of host compatibility or a redistribution approval.
    record = {'schema': 1, 'payload': destination.name, 'files': len(files),
              'bytes': sum(p.stat().st_size for p in files),
              'bundledLibraries': records,
              'screenScraperClientIncluded': screenscraper is not None,
              'redistributionReviewed': False, 'published': False}
    report.write_text(json.dumps(record, indent=2) + '\n')
    return record


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--screenscraper-client', type=Path,
                        help='Private operator input containing only the approved application identity')
    args = parser.parse_args()
    print(json.dumps(stage(args.build, args.output, args.screenscraper_client)))
