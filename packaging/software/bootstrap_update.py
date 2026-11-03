# SPDX-License-Identifier: GPL-3.0-or-later
"""Explicit Setup-only bootstrap replacement, with an atomic directory exchange."""
import ctypes
import errno
import os
from pathlib import Path
import re
import shutil
import uuid
import installation as install
import releases as sw


def verify(tree, records):
    install.private(tree)
    for name, digest in records.items():
        path = tree / 'packaging' / sw.relative(name)
        install.private(path, False)
        if not path.is_file() or sw.sha256(path) != digest:
            raise ValueError('Bootstrap was modified')


def exchange(first, second):
    # Both directories are on the installation filesystem. Either complete
    # bootstrap remains at the launcher path, including across interruption.
    libc = ctypes.CDLL(None, use_errno=True)
    call = getattr(libc, 'renameat2', None)
    if call is None: raise OSError(errno.ENOSYS, 'Atomic bootstrap exchange is unavailable')
    call.argtypes = (ctypes.c_int, ctypes.c_char_p, ctypes.c_int, ctypes.c_char_p, ctypes.c_uint)
    call.restype = ctypes.c_int
    if call(-100, os.fsencode(first), -100, os.fsencode(second), 2):
        raise OSError(ctypes.get_errno(), 'Atomic bootstrap exchange failed')
    for directory in {first.parent, second.parent}:
        fd = os.open(directory, os.O_RDONLY | os.O_DIRECTORY)
        try: os.fsync(fd)
        finally: os.close(fd)


def replace(root, source, files, records, confirm, checkpoint=lambda phase: None):
    root = install.private(root)
    destination = root / 'bootstrap'
    journal = root / 'bootstrap-update.json'
    with sw.cache_lock(root / 'runtime'), sw.cache_lock(root / 'transaction'):
        install.ensure_no_orphans(root)
        if (root/'setup-pending.json').exists() or (root/'runtimes/transaction.json').exists():
            raise ValueError('Finish the interrupted installation with its matching recovery installer first')
        pending = install.read(journal)
        if pending:
            if pending['new'] != records:
                raise ValueError('Resume bootstrap update with the same installer')
            identity = pending['id']
            if not re.fullmatch('[0-9a-f]{32}', identity): raise ValueError('Invalid bootstrap update journal')
            stage = root / 'bootstrap-updates' / identity / 'tree'
            install.private(stage)
        else:
            old = install.read(root/'bootstrap-files.json')
            verify(destination, old)
            if confirm is None: raise ValueError('Installed bootstrap differs; use the matching recovery installer')
            if not confirm(): return False
            identity = uuid.uuid4().hex
            stage = install.private(root / 'bootstrap-updates' / identity / 'tree')
            for path in files:
                target = stage / 'packaging' / path.relative_to(source)
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(path, target)
                target.chmod(0o755 if path.suffix in ('.py', '.sh') else 0o644)
                with target.open('rb') as stream: os.fsync(stream.fileno())
            verify(stage, records)
            for directory in [p for p in stage.rglob('*') if p.is_dir()] + [stage, stage.parent, stage.parent.parent]:
                fd = os.open(directory, os.O_RDONLY | os.O_DIRECTORY)
                try: os.fsync(fd)
                finally: os.close(fd)
            pending = {'id': identity, 'old': old, 'new': records}
            sw.atomic(journal, pending)
            checkpoint('prepared')
        try:
            verify(destination, pending['new'])
            exchanged = True
        except (OSError, ValueError):
            exchanged = False
        if not exchanged:
            verify(destination, pending['old'])
            verify(stage, pending['new'])
            exchange(destination, stage)
            checkpoint('exchanged')
        verify(destination, pending['new'])
        verify(stage, pending['old'])
        sw.atomic(root/'bootstrap-files.json', pending['new'])
        sw.atomic(stage.parent/'recovery.json', pending)
        checkpoint('recorded')
        journal.unlink()
        return True
