#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Isolated native clients/server check with a supplied freely licensed IWAD.

Usage: check-native.py PACKAGE IWAD OUTPUT_DIR [2|3|4]
No user display, controllers, sound, library registration or saves are used.
"""
import json
import os
from pathlib import Path
import selectors
import signal
import socket
import subprocess
import sys
import time

package, wad, output = map(lambda s: Path(s).resolve(), sys.argv[1:4])
count = int(sys.argv[4]) if len(sys.argv) > 4 else 2
assert 2 <= count <= 4
output.mkdir()  # Preserve any previous run.
identity = json.loads(subprocess.check_output([sys.executable, '-I', str(package / 'content.py'), str(wad)]))
selector = selectors.DefaultSelector()
listeners, processes, channels, logs = [], [], [], []
traffic = {}
try:
    configs = {i: dict(protocol=2, seat=i, players=count, sockets={}) for i in range(1, count + 1)}
    for guest in range(2, count + 1):
        pair = []
        for seat, peer in [(1, guest), (guest, 1)]:
            directory = output / f'{seat}-{peer}'; directory.mkdir()
            path = str(directory / 'cabinet.sock')
            assert len(path.encode()) < 108
            listener = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            listener.bind(path); listener.listen(); listener.settimeout(10)
            listeners.append(listener); pair.append(listener)
            configs[seat]['sockets'][str(peer)] = path
        channels.append(pair)
    for seat, config in configs.items():
        path = output / f'connection-{seat}.json'; path.write_text(json.dumps(config)); path.chmod(0o600)
        log = (output / f'client-{seat}.log').open('w'); logs.append(log)
        local_wad = wad
        if seat > 1:
            local_wad = output / f'renamed-{seat}.wad'
            local_wad.hardlink_to(wad)
        env = dict(os.environ, SDL_VIDEODRIVER='dummy', SDL_AUDIODRIVER='dummy', SDL_RENDER_DRIVER='software')
        processes.append(subprocess.Popen(['bwrap', '--die-with-parent', '--unshare-net', '--bind', '/', '/',
            '--dev', '/dev', '--', sys.executable, '-I', str(package / 'launch.py'), 'network', str(local_wad),
            identity['content'], str(output / f'state-{seat}'), str(path)], env=env,
            stdout=log, stderr=subprocess.STDOUT, start_new_session=True))
    for pair in channels:
        a, b = (listener.accept()[0] for listener in pair)
        a.settimeout(1); b.settimeout(1)
        selector.register(a, selectors.EVENT_READ, b); selector.register(b, selectors.EVENT_READ, a)
        traffic[a] = 0; traffic[b] = 0
    deadline = time.monotonic() + 20
    while time.monotonic() < deadline:
        if any(p.poll() is not None for p in processes):
            raise RuntimeError('A native client exited; inspect its isolated log')
        for key, _ in selector.select(.1):
            data = key.fileobj.recv(32768)
            if not data:
                raise RuntimeError('Native channel closed during the check')
            key.data.sendall(data); traffic[key.fileobj] += len(data)
    for log in logs: log.flush()
    texts = [(output / f'client-{i}.log').read_text(errors='replace') for i in configs]
    # Native engine acknowledgement, not just our transport's open sockets.
    # The dedicated server writes native admission and map events to stdout;
    # clients render their consoles internally, even with SDL's dummy driver.
    host_log = texts[0].lower()
    if host_log.count('has connected.') < count or '--- map01:' not in host_log or 'disconnected.' in host_log:
        raise RuntimeError('Native server did not retain every client on the map')
    assert all(size > 1000 for size in traffic.values()), traffic
    servers = []
    for proc in Path('/proc').glob('[0-9]*'):
        try:
            if (proc / 'exe').readlink().name == 'odasrv' and (proc / 'cwd').resolve() == output / 'state-1':
                servers.append(proc)
        except OSError:
            pass
    assert len(servers) == 1, 'Expected exactly one owned native server'
    next(iter(traffic)).close()  # Authenticated carrier loss, not a game exit.
    deadline = time.monotonic() + 4
    while servers[0].exists() and time.monotonic() < deadline:
        time.sleep(.05)
    assert not servers[0].exists(), 'Native server survived revoked carrier'
    assert all(p.poll() is None for p in processes), 'Connection loss closed a user game window'
    result = dict(players=count, native_clients_alive=True, native_server_admitted_clients=count, renamed_guest_content=True,
                  loss_revokes_server_without_closing_clients=True,
                  bidirectional_bytes=list(traffic.values()), duration_seconds=20)
    (output / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result))
finally:
    for p in processes:
        if p.poll() is None:
            os.killpg(p.pid, signal.SIGTERM)
    for p in processes:
        try: p.wait(3)
        except subprocess.TimeoutExpired:
            os.killpg(p.pid, signal.SIGKILL); p.wait()
    for s in traffic: s.close()
    selector.close()
    for s in listeners: s.close()
    for f in logs: f.close()
