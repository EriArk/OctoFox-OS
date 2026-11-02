# SPDX-License-Identifier: GPL-3.0-or-later
"""NgpCraft byte pipe over the existing authenticated cabinet IPC records."""
import hashlib
import json
import socket
import stat
import struct
import time
from collections import deque
from pathlib import Path

MAX_RECORD = 0x4006
MAX_STATE = 6 * 1024 * 1024


def connection(filename):
    p = Path(filename); info = p.lstat()
    if not p.is_absolute() or not stat.S_ISREG(info.st_mode) or info.st_mode & 0o077 or info.st_size > 4096:
        raise ValueError('Unprotected connection')
    c = json.loads(p.read_text())
    if set(c) != {'protocol', 'seat', 'players', 'sockets'} or c['protocol'] != 2 or c['players'] != 2 or type(c['seat']) is not int or c['seat'] not in (1, 2):
        raise ValueError('Connection seats')
    if set(c['sockets']) != {str(3 - c['seat'])}:
        raise ValueError('Connection peers')
    path = c['sockets'][str(3 - c['seat'])]
    if not isinstance(path, str) or not Path(path).is_absolute() or Path(path).name != 'cabinet.sock':
        raise ValueError('Connection socket')
    return c['seat'], path


class Channel:
    def __init__(self, stream):
        self.stream = stream; stream.setblocking(False)
        self.rx = bytearray(); self.tx = bytearray(); self.records = deque()
        self.active = True

    def record(self, data):
        if not 1 <= len(data) <= MAX_RECORD or len(self.tx) + len(data) > 256 * 1024:
            raise ValueError('Channel queue')
        self.tx.extend(struct.pack('!H', len(data)) + data)

    def flush(self):
        if not self.active: raise ConnectionError('Link disconnected')
        try:
            if self.tx:
                n = self.stream.send(self.tx)
                if n <= 0: raise ConnectionError('Link stopped accepting data')
                del self.tx[:n]
        except BlockingIOError: pass

    def pump(self):
        self.flush()
        try:
            chunk = self.stream.recv(65536)
            if not chunk: raise ConnectionError('Link disconnected')
            self.rx.extend(chunk)
        except BlockingIOError: pass
        while len(self.rx) >= 2:
            n = struct.unpack_from('!H', self.rx)[0]
            if not 1 <= n <= MAX_RECORD: raise ValueError('Record size')
            if len(self.rx) < n + 2: break
            self.records.append(bytes(self.rx[2:n + 2])); del self.rx[:n + 2]
        if len(self.records) > 128: raise ValueError('Channel flood')

    def exchange(self, own, identity, update, timeout=120):
        if len(own) > MAX_STATE: raise ValueError('State size')
        hello = b'H' + identity
        connected = False; sent_header = False; ack = 0; sent = 0
        peer = bytearray(); wanted = None; digest = None; peer_done = False; end_sent = False
        next_hello = 0; deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if not update(): raise InterruptedError('Cancelled')
            now = time.monotonic()
            if not connected and now >= next_hello:
                self.record(hello); next_hello = now + .2
            self.pump()
            while self.records:
                packet = self.records.popleft(); kind, body = packet[:1], packet[1:]
                if kind == b'H':
                    if body != identity: raise ValueError('Different game or runtime')
                    if not connected: self.record(hello)
                    connected = True
                elif kind == b'S' and wanted is None and len(body) == 36:
                    wanted = struct.unpack_from('!I', body)[0]; digest = body[4:]
                    if wanted > MAX_STATE: raise ValueError('Peer state size')
                elif kind == b'D' and wanted is not None and len(body) >= 5:
                    offset = struct.unpack_from('!I', body)[0]
                    if offset != len(peer) or len(peer) + len(body) - 4 > wanted: raise ValueError('State sequence')
                    peer.extend(body[4:]); self.record(b'A' + struct.pack('!I', len(peer)))
                elif kind == b'A' and len(body) == 4:
                    value = struct.unpack('!I', body)[0]
                    if not ack <= value <= sent: raise ValueError('State receipt')
                    ack = value
                elif kind == b'E' and not body:
                    peer_done = True
                elif kind == b'M' and end_sent:
                    self.records.appendleft(packet); break
                else: raise ValueError('Preparation record')
            if connected and not sent_header:
                self.record(b'S' + struct.pack('!I', len(own)) + hashlib.sha256(own).digest()); sent_header = True
            if sent_header and sent == ack and sent < len(own):
                chunk = own[sent:sent + 8192]
                self.record(b'D' + struct.pack('!I', sent) + chunk); sent += len(chunk)
            if wanted is not None and len(peer) == wanted and ack == len(own) and not end_sent:
                if hashlib.sha256(peer).digest() != digest: raise ValueError('State checksum')
                self.record(b'E'); end_sent = True
            if peer_done and end_sent:
                self.flush(); return bytes(peer)
            time.sleep(.001)
        raise TimeoutError('Link preparation timed out')

    def send(self, data):
        # MirrorSession owns the emulation/input protocol; only framing lives here.
        for offset in range(0, len(data), 8192): self.record(b'M' + data[offset:offset + 8192])

    def recv(self):
        self.pump(); result = bytearray()
        while self.records:
            packet = self.records.popleft()
            if packet[:1] != b'M': raise ValueError('Unexpected running record')
            result.extend(packet[1:])
        return bytes(result)

    def close(self):
        self.active = False; self.stream.close()
