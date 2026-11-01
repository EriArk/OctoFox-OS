#!/usr/bin/python3 -I
"""Use the bounded audio teardown repair only on the reviewed host build."""
import hashlib
import json
import os
from pathlib import Path
import sys

ROOT = Path('/var/opt/traineros/host/pulseaudio-qt')
STOCK = Path('/usr/lib64/libKF6PulseAudioQt.so.5')


def environment(root=ROOT, stock=STOCK, original=None):
    env = dict(os.environ if original is None else original)
    try:
        manifest = json.loads((root / 'manifest.json').read_text())
        library = root / 'libKF6PulseAudioQt.so.5'
        if hashlib.sha256(stock.read_bytes()).hexdigest() != manifest['stock_sha256']:
            raise ValueError('host library changed; review/rebuild required')
        if hashlib.sha256(library.read_bytes()).hexdigest() != manifest['patched_sha256']:
            raise ValueError('repair library missing or changed')
        env['LD_PRELOAD'] = str(library) + (' ' + env['LD_PRELOAD'] if env.get('LD_PRELOAD') else '')
    except (OSError, ValueError, KeyError, TypeError) as error:
        print('TrainerOS: Plasma audio compatibility repair skipped: ' + str(error), file=sys.stderr)
    return env


if __name__ == '__main__':
    os.execve('/usr/bin/plasmashell', ['/usr/bin/plasmashell', '--no-respawn'], environment())
