#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Native Model 3 content admission and owner-local cabinet preparation."""
import hashlib
import ctypes
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import tempfile


def atomic_write(target, data):
    with tempfile.NamedTemporaryFile(dir=target.parent, prefix='.prepare-', delete=False) as f:
        temporary = Path(f.name)
        try:
            f.write(data)
            f.flush()
            os.fsync(f.fileno())
            os.replace(temporary, target)
        finally:
            temporary.unlink(missing_ok=True)


def identity(bundle, content):
    bundle, content = Path(bundle), Path(content)
    if not content.is_absolute() or content.suffix.lower() != '.zip' or not content.is_file() or not 0 < content.stat().st_size <= 1024**3:
        raise ValueError('Unsupported Model 3 archive')
    with tempfile.TemporaryDirectory(prefix='trainer-model3-inspect-') as tmp:
        stage = Path(tmp)
        (stage / 'Config').mkdir()
        env = dict(os.environ, TRAINEROS_SUPERMODEL_INSPECT='1')
        parent = os.getpid()
        def owned_probe():
            # QProcess cancellation can kill this Python helper. Do not leave
            # the native ROM reader running after its owning scan disappears.
            libc = ctypes.CDLL(None, use_errno=True)
            libc.prctl.argtypes = [ctypes.c_int] + [ctypes.c_ulong] * 4
            if libc.prctl(1, signal.SIGKILL, 0, 0, 0) != 0 or os.getppid() != parent:
                os._exit(1)
        result = subprocess.run([str(bundle / 'bin/supermodel'), '-game-xml-file=' + str(bundle / 'Config/Games.xml'), str(content)],
                                env=env, cwd=stage, capture_output=True, timeout=90, check=True, preexec_fn=owned_probe)
    lines = [x.removeprefix(b'[TrainerOSModel3] ') for x in result.stdout.splitlines() if x.startswith(b'[TrainerOSModel3] ')]
    if len(lines) != 1 or len(lines[0]) > 1024:
        raise ValueError('Native content identification failed')
    value = json.loads(lines[0])
    if set(value) != {'name', 'parent', 'link'} or value['link'] is not True or not re.fullmatch('[a-z0-9_]+', value['name']) or not re.fullmatch('[a-z0-9_]*', value['parent']):
        raise ValueError('The installed native runtime does not support cabinet link for this set')
    files = [content]
    if value['parent']:
        parent = content.parent / (value['parent'] + '.zip')
        if parent.is_file() and parent.resolve() != content.resolve():
            files.append(parent)
    digest = hashlib.sha256()
    digest.update(value['name'].encode() + b'\0')
    for path in files:
        if path.stat().st_size > 1024**3:
            raise ValueError('Oversized dependency')
        with path.open('rb') as f:
            digest.update(hashlib.file_digest(f, 'sha256').digest())
    value['content'] = digest.hexdigest()
    return value


def prepare(bundle, directory, config, nvram, name):
    bundle, directory, config, nvram = map(Path, (bundle, directory, config, nvram))
    if not directory.is_absolute() or directory.is_symlink() or not re.fullmatch('[a-z0-9_]+', name):
        raise ValueError('Invalid local cabinet folder')
    # The caller holds the local game lock. Native cabinet NVRAM persists only
    # in this own-content/seat folder; the ordinary player's NVRAM is never changed.
    for leaf in ('Config', 'NVRAM', 'Saves'):
        target = directory / leaf
        if target.is_symlink():
            raise ValueError('Invalid cabinet folder')
        target.mkdir(mode=0o700, parents=True, exist_ok=True)
    if config.is_file():
        if config.stat().st_size > 1024**2:
            raise ValueError('Oversized native settings')
        data = config.read_bytes()
    else:
        data = (bundle / 'Config/Supermodel.ini').read_bytes()
    target = directory / 'Config/Supermodel.ini'
    if target.is_symlink():
        raise ValueError('Invalid settings file')
    atomic_write(target, data)
    saved = directory / 'NVRAM' / (name + '.nv')
    if saved.is_symlink():
        raise ValueError('Invalid cabinet NVRAM')
    original = nvram / (name + '.nv')
    if not saved.exists() and original.is_file():
        if original.stat().st_size > 1024**2:
            raise ValueError('Oversized NVRAM')
        atomic_write(saved, original.read_bytes())


if __name__ == '__main__':
    os.umask(0o077)
    try:
        if sys.argv[1] == 'identity':
            print(json.dumps(identity(*sys.argv[2:])))
        elif sys.argv[1] == 'prepare':
            prepare(*sys.argv[2:])
            print('{"ready":true}')
        else:
            raise ValueError('Unknown operation')
    except (ValueError, OSError, subprocess.SubprocessError, KeyError):
        print('{}')
        raise SystemExit(1)
