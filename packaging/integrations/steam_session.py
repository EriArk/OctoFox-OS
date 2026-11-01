#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Observe one Steam app; the Steam launcher/client is never the game lifetime."""
import json
import os
from pathlib import Path
import signal
import stat
import subprocess
import sys
import time


def process(pid, proc=Path('/proc')):
    path = proc/str(pid)
    if path.stat().st_uid != os.getuid(): raise ValueError('Different process owner')
    fields = (path/'stat').read_text().rsplit(')', 1)[1].split()
    if fields[0] == 'Z': raise ProcessLookupError(pid)
    return str(fields[19]), int(fields[1])


def state_path(pid, start):
    return Path(f'/run/user/{os.getuid()}/traineros-steam/{pid}-{start}.json')


def session_roots(pid, start):
    """None = ordinary child; empty = Steam supervisor without a live game.

    All overlays use the same exact process identities, including external
    children of an already running Steam client. No window-name/AppID guesses.
    """
    try:
        cmd = (Path('/proc')/str(pid)/'cmdline').read_bytes().split(b'\0')
        if len(cmd) < 2 or cmd[1] != os.fsencode(Path(__file__).resolve()) or b'launch' not in cmd[2:3]: return None
        if process(pid)[0] != str(start): return {}
        path = state_path(pid, start)
        fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW)
        with os.fdopen(fd, 'rb') as source:
            info = os.fstat(source.fileno())
            if info.st_uid != os.getuid() or not stat.S_ISREG(info.st_mode) or info.st_mode & 0o077: return {}
            data = source.read(65537)
        if len(data) > 65536: return {}
        saved = json.loads(data)
        if saved.get('supervisor') != [pid, str(start)]: return {}
        return {int(p): str(s) for p, s in saved['processes'].items()}
    except (OSError, ValueError, KeyError, TypeError, IndexError): return {}


def owns_pid(pid, roots):
    for _ in range(64):
        try:
            start, parent = process(pid)
            if roots.get(pid) == start: return True
            if parent <= 1: return False
            pid = parent
        except (OSError, ValueError, IndexError): return False
    return False


def snapshot(app, before, known, proc=Path('/proc')):
    """Discover new exact AppID processes; retain descendants after reparenting."""
    current = {}; matches = {}
    for path in proc.iterdir():
        if not path.name.isdecimal(): continue
        pid = int(path.name)
        try:
            token, parent = process(pid, proc)
            current[pid] = (token, parent)
            if before.get(pid) == token: continue
            if known.get(pid) == token: matches[pid] = token; continue
            with (path/'environ').open('rb') as source: env = source.read(262144).split(b'\0')
            if f'SteamAppId={app}'.encode() in env or f'SteamGameId={app}'.encode() in env:
                matches[pid] = token
        except (OSError, ValueError, IndexError): continue
    for _ in range(64):
        extra = {pid: token for pid, (token, parent) in current.items()
                 if pid not in matches and before.get(pid) != token and parent in matches}
        if not extra: break
        matches.update(extra)
    return matches


def signal_owned(owned, sig):
    for pid, start in owned.items():
        try:
            fd = os.pidfd_open(pid)
            try:
                if process(pid)[0] == start: signal.pidfd_send_signal(fd, sig)
            finally: os.close(fd)
        except (OSError, ValueError, IndexError): pass


def supervise(config):
    from steam_library import discover
    app = config['appId']
    found = [g for g in discover()['games'] if g['appId'] == app]
    if len(found) != 1 or not found[0]['available']: raise ValueError('Reconnect this game library or complete its installation in Steam.')
    game = found[0]
    if game['steamRoot'] != config['steamRoot']: raise ValueError('Steam library changed. Refresh Games before playing.')
    # A second session must never adopt an independently running instance.
    if snapshot(app, {}, {}): raise ValueError('This game is already running in Steam. Close it before launching from TrainerOS.')
    before = {}
    for path in Path('/proc').iterdir():
        if path.name.isdecimal():
            try: before[int(path.name)] = process(int(path.name))[0]
            except (OSError, ValueError, IndexError): pass
    pid = os.getpid(); start = process(pid)[0]; target = state_path(pid, start)
    target.parent.mkdir(mode=0o700, exist_ok=True)
    directory = target.parent.lstat()
    if not stat.S_ISDIR(directory.st_mode) or directory.st_uid != os.getuid() or directory.st_mode & 0o077:
        raise ValueError('Steam session directory is unavailable.')
    def publish(owned):
        data = json.dumps(dict(supervisor=[pid,start],processes=owned)).encode()
        temporary = target.with_suffix('.new')
        fd = os.open(temporary, os.O_WRONLY|os.O_CREAT|os.O_EXCL|os.O_NOFOLLOW, 0o600)
        with os.fdopen(fd,'wb') as output: output.write(data)
        temporary.replace(target)
    stopping = [None]
    def stop(_sig, _frame):
        if stopping[0] is None: stopping[0] = time.monotonic()
    for sig in (signal.SIGTERM,signal.SIGINT,signal.SIGHUP): signal.signal(sig,stop)
    env = os.environ.copy()
    for key in ('QT_QUICK_BACKEND','QT_SCALE_FACTOR','QSG_RHI_BACKEND','QT_PLUGIN_PATH','QML2_IMPORT_PATH',
                'QT_QPA_PLATFORM_PLUGIN_PATH','LD_PRELOAD','SteamAppId','SteamGameId','SteamOverlayGameId'):
        env.pop(key,None)
    env['STEAM_ROOT'] = game['steamRoot']
    env['GDK_BACKEND'] = 'x11'
    launcher = ['/usr/bin/steam','-silent','-applaunch',app]
    if '/.var/app/com.valvesoftware.Steam/' in game['steamRoot']:
        launcher = ['/usr/bin/flatpak','run','com.valvesoftware.Steam','-silent','-applaunch',app]
    owned = {}; ready = False; absent = None; began = time.monotonic()
    client = None
    try:
        publish({})
        client = subprocess.Popen(launcher, env=env, stdin=subprocess.DEVNULL,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,start_new_session=True)
        from overlay_support import X11
        x11 = X11()
        while True:
            client.poll()  # Reap the URI/CLI forwarding process, not the game.
            now = time.monotonic()
            owned = snapshot(app, before, owned)
            publish(owned)
            if stopping[0] is not None:
                signal_owned(owned, signal.SIGKILL if now-stopping[0]>.5 else signal.SIGTERM)
                if now-stopping[0] > 1: return 130
            if owned:
                absent = None
                if not ready and owns_pid(x11.pid(x11.active()), owned):
                    ready = True; print('TRAINEROS_STEAM_READY',flush=True)
            elif ready:
                absent = absent or now
                if now-absent >= 2: return 0
            if not ready and now-began > 120:
                # Do not kill Steam or claim a play session on a login/update UI.
                signal_owned(owned,signal.SIGTERM)
                raise ValueError('Steam did not open the game. Check its login, updates and compatibility in Steam.')
            time.sleep(.15)
    finally:
        target.unlink(missing_ok=True)
        target.with_suffix('.new').unlink(missing_ok=True)


if __name__ == '__main__':
    try:
        if len(sys.argv) != 3 or sys.argv[1] != 'launch': raise ValueError('Unsupported Steam session operation.')
        raise SystemExit(supervise(json.loads(sys.argv[2])))
    except Exception as error:
        message = str(error) if isinstance(error, ValueError) else 'Steam could not start this game. Check Steam and try again.'
        print('TRAINEROS_PC_ERROR:'+message,flush=True)
        raise SystemExit(1)
