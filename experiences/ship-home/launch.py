#!/usr/bin/env python3
"""Linux entry point; keep the tracked process and single-instance lock through exec."""
# SPDX-License-Identifier: GPL-3.0-or-later
import fcntl
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

def fail(message):
    base = Path(os.environ.get('XDG_STATE_HOME', Path.home()/'.local/state'))/'octofox-ship-home'
    base.mkdir(parents=True, exist_ok=True)
    log = base/'launch-error.txt'
    log.write_text(message+'\n')
    text = 'Could not open your ship.\n'+message+'\nDetails: '+str(log)
    print(text, file=sys.stderr)
    for executable, arguments in [('kdialog', ['--error', text]), ('zenity', ['--error', '--text', text])]:
        if shutil.which(executable):
            subprocess.run([executable, *arguments], timeout=120, check=False)
            break
    return 1

def main():
    root = Path(__file__).resolve().parent
    try:
        engine = Path(json.loads((root/'runtime.json').read_text())['engine'])
        if not engine.is_absolute() or not engine.is_file() or not os.access(engine, os.X_OK):
            return fail('The configured Godot runtime is missing. Reinstall the development preview with install-dev.py.')
        data = Path(os.environ.get('XDG_DATA_HOME', Path.home()/'.local/share'))/'octofox-ship-home'
        data.mkdir(parents=True, exist_ok=True)
        lock = os.open(data/'session.lock', os.O_CREAT | os.O_RDWR, 0o600)
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            os.close(lock)
            return fail('Your ship is already open. Return to it through Quick Apps.')
        os.set_inheritable(lock, True)
        # exec retains the PID used by the existing Apps supervisor, and the lock.
        os.execv(str(engine), [str(engine), '--path', str(root)])
    except (OSError, ValueError, KeyError) as error:
        return fail(str(error))

if __name__ == '__main__':
    sys.exit(main())
