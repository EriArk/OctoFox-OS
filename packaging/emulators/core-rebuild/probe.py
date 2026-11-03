# SPDX-License-Identifier: GPL-3.0-or-later
"""Load candidate ARM64 cores under QEMU; no retro_init, ROM, BIOS or save access."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess


def probe(artifact, executable):
    with artifact.open('rb') as stream:
        checksum = hashlib.file_digest(stream, 'sha256').hexdigest()
    row = {'file': artifact.name, 'sha256': checksum, 'bytes': artifact.stat().st_size,
           'gameplayAccepted': False, 'deviceAccepted': False}
    try:
        p = subprocess.run(['qemu-aarch64', str(executable), str(artifact)],
                           capture_output=True, text=True, timeout=30)
        row['exitCode'] = p.returncode
        if p.returncode:
            row.update(status='failed', error=p.stderr[-4000:])
        else:
            row.update(status='abi-loaded', info=json.loads(p.stdout))
    except (subprocess.TimeoutExpired, json.JSONDecodeError) as exc:
        row.update(status='failed', error=str(exc))
    return row


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--artifacts', type=Path, nargs='+', required=True)
    p.add_argument('--executable', type=Path, required=True)
    p.add_argument('--report', type=Path, required=True)
    args = p.parse_args()
    if args.report.exists():
        p.error('Existing report retained')
    files = [x for directory in args.artifacts for x in sorted(directory.glob('*_libretro.so'))]
    if not files or len({f.name for f in files}) != len(files) or any(f.is_symlink() for f in files):
        p.error('Expected a nonempty, unique set of regular core files')
    result = {'schema': 1, 'method': 'QEMU ARM64 dlopen RTLD_NOW + 25 libretro symbols + API/system_info only',
              'cores': [probe(f.resolve(), args.executable.resolve()) for f in files]}
    args.report.write_text(json.dumps(result, indent=2) + '\n')
    for row in result['cores']:
        print(row['file'], row['status'], row.get('info', row.get('error')), flush=True)
    raise SystemExit(any(row['status'] != 'abi-loaded' for row in result['cores']))
