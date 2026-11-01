#!/usr/bin/python3 -I
"""User-owned XDG return link; never overwrite a custom or legacy launcher."""
import os
from pathlib import Path
import pwd
import sys

TARGET = '/var/opt/traineros/session/org.traineros.Session.desktop'


def update(home, action):
    entry = Path(home) / '.local/share/applications/org.traineros.Session.desktop'
    if action == 'install':
        entry.parent.mkdir(parents=True, exist_ok=True)
        try:
            entry.symlink_to(TARGET)
        except FileExistsError:
            pass  # Preserve earlier manual installs and all user changes.
    elif action == 'uninstall':
        if entry.is_symlink() and os.readlink(entry) == TARGET:
            entry.unlink()
    else:
        raise ValueError('Unknown desktop entry action')


if __name__ == '__main__':
    if os.geteuid() == 0 or len(sys.argv) != 2 or sys.argv[1] not in {'install', 'uninstall'}:
        sys.exit(2)
    update(pwd.getpwuid(os.geteuid()).pw_dir, sys.argv[1])
