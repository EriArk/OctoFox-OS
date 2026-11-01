#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Actual upstream CNetBoardLink over namespaces and the existing ICE/DTLS carrier."""
import json
from pathlib import Path
import queue
import runpy
import socket
import subprocess
import sys
import tempfile
import threading
import unittest

transport, endpoint, native = map(lambda p: str(Path(p).resolve()), sys.argv[1:4])
sys.argv = [sys.argv[0], transport]
Pair = runpy.run_path(str(Path(__file__).parents[1] / 'remote-play-stream/transport/check.py'))['Pair']


class NativeRingTests(unittest.TestCase):
    def test_forged_peer_or_oversized_frame_disconnects_without_killing_child(self):
        for payload in (b'\x00\x04\x03\x01\x03\x01', b'\xff\xff'):
            with self.subTest(frame=payload), tempfile.TemporaryDirectory() as temp:
                root = Path(temp); listeners, peers = [], []
                p = None
                try:
                    sockets = {}
                    for seat in (2, 3):
                        directory = root/str(seat); directory.mkdir()
                        path = directory/'cabinet.sock'; sockets[str(seat)] = str(path)
                        s = socket.socket(socket.AF_UNIX); s.settimeout(5); s.bind(str(path)); s.listen(); listeners.append(s)
                    config = root/'connection.json'
                    config.write_text(json.dumps(dict(protocol=2, seat=1, players=3, sockets=sockets))); config.chmod(0o600)
                    p = subprocess.Popen(['/usr/bin/bwrap', '--die-with-parent', '--unshare-net', '--bind', '/', '/', '--', endpoint,
                                          str(config), '/usr/bin/python3', '-u', '-c', 'print("ready"); input(); print("alive")'],
                                         stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
                    for s in listeners:
                        peer, _ = s.accept(); peer.settimeout(5); peers.append(peer)
                    self.assertEqual(p.stdout.readline().strip(), 'ready')
                    peers[0].sendall(payload)
                    for peer in peers: self.assertEqual(peer.recv(1), b'')
                    self.assertIsNone(p.poll()); p.stdin.write('\n'); p.stdin.flush()
                    self.assertEqual(p.stdout.readline().strip(), 'alive'); self.assertEqual(p.wait(timeout=5), 0)
                finally:
                    if p:
                        if p.poll() is None: p.kill(); p.wait()
                        p.stdin.close(); p.stdout.close(); p.stderr.close()
                    for s in peers + listeners: s.close()

    def test_native_two_three_four_ring_and_loss(self):
        for count in (2, 3, 4):
            with self.subTest(players=count), tempfile.TemporaryDirectory() as temp:
                pairs, children, events = [], [], []
                try:
                    for guest in range(2, count + 1):
                        pair = Pair(modes=['cabinet', 'cabinet']); pairs.append(pair)
                        self.assertTrue(pair.connect())
                    for seat in range(1, count + 1):
                        sockets = ({str(n+2): str(pair.ready[0].parent/'cabinet.sock') for n, pair in enumerate(pairs)}
                                   if seat == 1 else {'1': str(pairs[seat-2].ready[1].parent/'cabinet.sock')})
                        config = Path(temp)/str(seat)
                        config.write_text(json.dumps({'protocol': 2, 'seat': seat, 'players': count, 'sockets': sockets}))
                        config.chmod(0o600)
                        p = subprocess.Popen(['/usr/bin/bwrap', '--die-with-parent', '--unshare-net', '--bind', '/', '/', '--',
                                              endpoint, str(config), native, str(seat), str(count)],
                                             stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
                        children.append(p); events.append(queue.Queue())
                        def read(process=p, output=events[-1]):
                            for line in process.stdout:
                                if line.startswith('@'): output.put(line.strip())
                            output.put('@ended')
                        threading.Thread(target=read, daemon=True).start()
                        self.assertEqual(events[-1].get(timeout=10), '@ready')
                    def send_all(value):
                        for p in children: p.stdin.write(value+'\n'); p.stdin.flush()
                    def expect_all(value):
                        for q in events: self.assertEqual(q.get(timeout=15), value)
                    send_all('connect'); expect_all('@connected')
                    for size in (1, 32, 8192, 65536, 262144):
                        send_all('send '+str(size)); expect_all('@sent')
                        send_all('receive'); expect_all('@received '+str(size)+' 1')
                    # Receive is blocking in the actual emulator. Losing the carrier
                    # must wake it without killing/relaunching any game process.
                    send_all('receive')
                    for pair in pairs: pair.close()
                    expect_all('@received 0 1')
                    send_all('alive'); expect_all('@alive')
                    self.assertTrue(all(p.poll() is None for p in children))
                finally:
                    for p in children:
                        try: p.stdin.close(); p.wait(timeout=5)
                        except (BrokenPipeError, subprocess.TimeoutExpired): p.kill(); p.wait()
                        p.stdout.close()
                    for pair in pairs:
                        if any(p.poll() is None for p in pair.processes): pair.close()

    def test_refuses_host_network_before_launch(self):
        self.assertEqual(subprocess.run([endpoint, '/missing', '/bin/true', 'unused'], timeout=5).returncode, 2)


if __name__ == '__main__':
    unittest.main(argv=[sys.argv[0]])
