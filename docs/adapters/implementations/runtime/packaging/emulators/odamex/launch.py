#!/usr/bin/python3
# SPDX-License-Identifier: GPL-3.0-or-later
import ctypes
import json
import os
from pathlib import Path
import runpy
import signal
import socket
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parent
# Execute the sealed source directly. Import caches are not package members and
# must never substitute an unchecked .pyc for a verified helper.
_content = runpy.run_path(str(ROOT / 'content.py'))
_endpoint = runpy.run_path(str(ROOT / 'endpoint.py'))
content, arguments = _content['content'], _content['arguments']
Bridge, connection = _endpoint['Bridge'], _endpoint['connection']


def child():
    parent = os.getppid()
    if ctypes.CDLL(None).prctl(1, signal.SIGKILL) != 0 or os.getppid() != parent or parent == 1:
        os._exit(2)


def stop(p):
    if p and p.poll() is None:
        p.terminate()
        try:
            p.wait(2)
        except subprocess.TimeoutExpired:
            p.kill()
            p.wait()


def main():
    # Internal fixed argv only; no user-supplied command strings in recipes.
    mode, filename, expected, state, config = sys.argv[1:6]
    prefix = sys.argv[6:]
    c = content(filename)
    if c['content'] != expected or mode not in ('solo', 'network'):
        raise ValueError('Content changed')
    state = Path(state)
    state.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    env.update(HOME=str(state), XDG_CONFIG_HOME=str(state / 'config'), XDG_DATA_HOME=str(state / 'data'),
               TRAINEROS_DOOM_MANAGED='1', LD_LIBRARY_PATH=str(ROOT / 'lib') + ':' + env.get('LD_LIBRARY_PATH', ''))
    # All engine config/autoexec/save searches are confined to owned state.
    cfg = state / 'client.cfg'
    if not cfg.exists():
        with cfg.open('x') as f:
            f.write('vid_fullscreen 1\nvid_defwidth 1280\nvid_defheight 720\nuse_joystick 1\n')
    base = arguments(c)
    client = [*prefix, str(ROOT / 'bin/odamex'), '-config', str(cfg), *base,
              '+set', 'cl_serverdownload', '0', '+set', 'cl_downloadsites', '',
              '+set', 'vid_fullscreen', '1']
    server = game = bridge = None
    try:
        if mode == 'network':
            if {name for _, name in socket.if_nameindex()} != {'lo'}:
                raise ValueError('Private network namespace required')
            conn = connection(config)
            bridge = Bridge(conn)
            if conn['seat'] == 1:
                server = subprocess.Popen([str(ROOT / 'bin/odasrv'), '-config', str(state / 'server.cfg'),
                    *base, '-port', '10666', '+set', 'sv_usemasters', '0',
                    '+set', 'sv_maxclients', str(conn['players']), '+set', 'sv_maxplayers', str(conn['players']),
                    '+set', 'sv_gametype', '0' if c['mode'] == 'coop' else '1',
                    '+set', 'sv_skill', str(c['skill']), '+map', c['map']],
                    cwd=state, env=env, stdin=subprocess.DEVNULL, preexec_fn=child)
            client += ['+connect', '127.0.0.1:10666']
        game = subprocess.Popen(client, cwd=state, env=env, preexec_fn=child)
        while game.poll() is None:
            if bridge and bridge.active:
                bridge.poll()
                if not bridge.active:
                    stop(server)  # Revoke network; the user's game window remains.
            else:
                time.sleep(.05)
            if server and server.poll() is not None and bridge and bridge.active:
                bridge.close()
        return game.returncode
    finally:
        if bridge:
            bridge.close()
        stop(game)
        stop(server)


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, ValueError, TypeError):
        print('Doom could not prepare the selected content or connection.', file=sys.stderr)
        sys.exit(2)
