# SPDX-License-Identifier: GPL-3.0-or-later
"""Recoverable code-only file changes. Callers hold the installation/runtime locks."""
import os
import errno
from pathlib import Path
import shutil
import tempfile
import installation as install
import releases as sw


def copy_code(source, target):
    """Clone storage extents when supported; never share a writable inode."""
    if os.name == 'posix':
        import fcntl
        try:
            fcntl.ioctl(target.fileno(), 0x40049409, source.fileno())  # Linux FICLONE
            return
        except OSError as error:
            if error.errno not in (errno.EXDEV, errno.EOPNOTSUPP, errno.ENOTTY, errno.EINVAL, errno.ENOSYS):
                raise
            target.seek(0); target.truncate(0); source.seek(0)
    shutil.copyfileobj(source, target)


class Files:
    def __init__(self, root, boundaries):
        self.root = install.private(root)
        self.boundaries = [Path(p).absolute() for p in boundaries]
        self.blobs = install.private(self.root / 'blobs')

    def path(self, name):
        path = Path(name)
        if not path.is_absolute() or '..' in path.parts:
            raise ValueError('Invalid runtime destination')
        if not any(base in path.parents for base in self.boundaries):
            raise ValueError('Runtime destination outside allowed roots')
        # No traversing mutable legacy directory links during a transaction.
        if any(p.is_symlink() for p in path.parents):
            raise ValueError('Linked runtime directory requires explicit migration: ' + str(path))
        return path

    def snapshot(self, path):
        path = self.path(str(path))
        if path.is_symlink(): return {'kind': 'link', 'target': os.readlink(path)}
        if not path.exists(): return {'kind': 'absent'}
        if not path.is_file(): raise ValueError('Runtime code destination is not a file: ' + str(path))
        sha = sw.sha256(path)
        blob = self.blobs / sha
        if not blob.exists():
            fd, tmp = tempfile.mkstemp(dir=self.blobs)
            try:
                with os.fdopen(fd, 'wb') as target, path.open('rb') as source:
                    copy_code(source, target); target.flush(); os.fsync(target.fileno())
                if sw.sha256(tmp) != sha: raise ValueError('Runtime file changed while backing up')
                os.replace(tmp, blob)
            finally:
                if os.path.exists(tmp): os.unlink(tmp)
        elif blob.is_symlink() or sw.sha256(blob) != sha:
            raise ValueError('Runtime recovery copy is damaged')
        return {'kind': 'file', 'sha256': sha, 'mode': path.stat().st_mode & 0o777}

    def import_file(self, source, mode):
        source = Path(source)
        if source.is_symlink() or not source.is_file(): raise ValueError('Invalid staged runtime file')
        sha = sw.sha256(source); blob = self.blobs / sha
        if not blob.exists():
            fd, tmp = tempfile.mkstemp(dir=self.blobs)
            try:
                with os.fdopen(fd, 'wb') as target, source.open('rb') as incoming:
                    copy_code(incoming, target); target.flush(); os.fsync(target.fileno())
                if sw.sha256(tmp) != sha: raise ValueError('Staged runtime file changed')
                os.replace(tmp, blob)
            finally:
                if os.path.exists(tmp): os.unlink(tmp)
        elif blob.is_symlink() or sw.sha256(blob) != sha:
            raise ValueError('Runtime recovery copy is damaged')
        return {'kind': 'file', 'sha256': sha, 'mode': mode}

    def baseline(self): return install.read(self.root / 'baseline.json', {})
    def owned(self): return install.read(self.root / 'owned.json', {})
    def pending(self): return install.read(self.root / 'transaction.json')

    def plan(self, desired, identity, migrate=False):
        if self.pending(): raise ValueError('Recover the interrupted runtime operation first')
        owned = self.owned(); baseline = self.baseline(); operations = []
        for name in sorted(set(owned) | set(desired)):
            current = self.snapshot(self.path(name))
            if name in owned and current != owned[name]:
                raise ValueError('Installed runtime code was changed; preserve/review it before updating: ' + name)
            if name not in owned:
                if current['kind'] != 'absent' and current != desired[name] and not migrate:
                    raise ValueError('Existing runtime code needs migration with a recovery copy: ' + name)
                baseline[name] = current
            target = desired.get(name, baseline[name])
            operations.append({'path': name, 'before': current, 'after': target})
        return {'schema': 1, 'identity': identity, 'operations': operations,
                'beforeOwned': owned, 'afterOwned': desired, 'baseline': baseline, 'direction': 'apply'}

    def write(self, name, value):
        path = self.path(name); path.parent.mkdir(parents=True, exist_ok=True)
        if value['kind'] == 'absent': path.unlink(missing_ok=True)
        else:
            fd, tmp = tempfile.mkstemp(dir=path.parent, prefix='.traineros-runtime-'); os.close(fd)
            try:
                if value['kind'] == 'link':
                    os.unlink(tmp); os.symlink(value['target'], tmp)
                elif value['kind'] == 'file':
                    blob = self.blobs / value['sha256']
                    if blob.is_symlink() or sw.sha256(blob) != value['sha256']: raise ValueError('Recovery blob is damaged')
                    with open(tmp, 'wb') as target, blob.open('rb') as source:
                        copy_code(source, target); target.flush(); os.fsync(target.fileno())
                    os.chmod(tmp, value['mode'])
                else: raise ValueError('Invalid runtime file state')
                os.replace(tmp, path)
            finally:
                if os.path.lexists(tmp): os.unlink(tmp)
        if os.name != 'nt':
            fd = os.open(path.parent, os.O_RDONLY)
            try: os.fsync(fd)
            finally: os.close(fd)

    def begin(self, plan):
        if self.pending(): raise ValueError('Runtime operation already pending')
        for op in plan['operations']:
            if self.snapshot(op['path']) != op['before']: raise ValueError('Runtime changed after preflight')
        sw.atomic(self.root / 'transaction.json', plan)

    def apply(self, reverse=False, checkpoint=lambda *args: None, finish=True):
        plan = self.pending()
        if not plan: raise ValueError('No pending runtime operation')
        if reverse: plan['direction'] = 'rollback'; sw.atomic(self.root / 'transaction.json', plan)
        reverse = plan['direction'] == 'rollback'
        ops = list(reversed(plan['operations'])) if reverse else plan['operations']
        # Verify all files before making a further write, including after a crash.
        for op in ops:
            if self.snapshot(op['path']) not in (op['before'], op['after']):
                raise ValueError('Runtime changed during recovery; personal changes preserved: ' + op['path'])
        for index, op in enumerate(ops):
            wanted = op['before'] if reverse else op['after']
            if self.snapshot(op['path']) != wanted: self.write(op['path'], wanted)
            checkpoint(index, op['path'])
        if finish: self.finish()

    def finish(self):
        plan = self.pending()
        if not plan: raise ValueError('No pending runtime operation')
        reverse = plan['direction'] == 'rollback'
        for op in plan['operations']:
            if self.snapshot(op['path']) != op['before' if reverse else 'after']:
                raise ValueError('Runtime transaction is incomplete')
        sw.atomic(self.root / 'baseline.json', plan['baseline'])
        sw.atomic(self.root / 'owned.json', plan['beforeOwned' if reverse else 'afterOwned'])
        (self.root / 'transaction.json').unlink()
