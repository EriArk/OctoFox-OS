#!/usr/bin/python3 -I
"""Add bounded radio privileges; preserve other system/user configuration."""
import argparse
import os
from pathlib import Path
import pwd
import re
import shutil
import subprocess
import tempfile

def files(user):
    """Prepare all bytes before writing; never change a radio or saved network."""
    if not re.fullmatch(r'[a-z_][a-z0-9_-]*', user):
        raise ValueError('A regular local login name is required')
    root = Path('/var/opt/traineros/integrations')
    helper = root / 'radio-control.py'
    verbs = [kind + '-' + state for kind in ('wifi', 'bluetooth', 'airplane') for state in ('on', 'off')]
    policy = user + ' ALL=(root) NOPASSWD: ' + ', '.join(str(helper) + ' ' + verb for verb in verbs) + '\n'
    policy += user + ' ALL=(root) NOPASSWD: ' + str(root / 'network-control.py') + ' ""\n'
    policy += user + ' ALL=(root) NOPASSWD: ' + str(root / 'nearby-control.py') + ' ""\n'
    planned = []
    for name in ('radio-control.py', 'network-control.py', 'nearby-bluetooth.py', 'nearby-control.py'):
        data = Path(__file__).with_name(name).read_bytes().replace(b'\r\n', b'\n')
        compile(data, name, 'exec')
        planned.append((root / name, data, 0o644 if name == 'nearby-bluetooth.py' else 0o755))
    planned.append((Path('/etc/sudoers.d/traineros-radio'), policy.encode(), 0o440))
    return planned


def install(user, writer=None):
    if os.geteuid() != 0 or not re.fullmatch(r'[a-z_][a-z0-9_-]*', user) or pwd.getpwnam(user).pw_uid < 1000:
        raise RuntimeError('Root and a regular local user are required')
    planned = files(user)
    with tempfile.NamedTemporaryFile() as check:
        check.write(planned[-1][1]); check.flush()
        subprocess.run(['/usr/sbin/visudo', '-cf', check.name], check=True, stdout=subprocess.DEVNULL)
    if writer is not None:
        # Managed installation owns preflight, atomic replacement and recovery.
        for destination, data, mode in planned: writer(str(destination), data, mode)
        return
    root = Path('/var/opt/traineros/integrations')
    root.mkdir(parents=True, exist_ok=True)
    if root.is_symlink() or root.stat().st_uid != 0 or root.stat().st_mode & 0o022:
        raise RuntimeError('Unsafe helper directory')
    backup = Path('/var/lib/traineros/radio-backup')
    backup.mkdir(parents=True, exist_ok=True, mode=0o700)
    for destination, data, mode in planned:
        if destination.is_symlink() or any(p.is_symlink() for p in destination.parents):
            raise RuntimeError('Redirected radio installation path')
        previous = backup / destination.name
        if destination.exists() and not previous.exists(): shutil.copy2(destination, previous)
        fd, temporary = tempfile.mkstemp(dir=destination.parent)
        try:
            with os.fdopen(fd, 'wb') as output:
                output.write(data); output.flush(); os.fchmod(output.fileno(), mode); os.fsync(output.fileno())
            os.replace(temporary, destination)
        finally:
            if os.path.exists(temporary): os.unlink(temporary)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--user', required=True)
    install(parser.parse_args().user)
    print('Radio controls installed; radio state unchanged')
