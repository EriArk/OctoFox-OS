# SPDX-License-Identifier: GPL-3.0-or-later
"""Native UDP over existing authenticated cabinet records, inside a private netns.

Host: one local UDP socket per admitted guest. Guest: one fixed loopback proxy.
No address or command is taken from a peer; datagram boundaries are preserved.
"""
import json
import selectors
import socket
import stat
import struct
from pathlib import Path

MAX_PACKET = 8192  # Odamex MAX_UDP_PACKET
MAX_QUEUE = 256 * 1024
SERVER = ('127.0.0.1', 10666)


def connection(filename):
    p = Path(filename)
    info = p.lstat()
    if not p.is_absolute() or not stat.S_ISREG(info.st_mode) or info.st_mode & 0o077 or info.st_size > 4096:
        raise ValueError('Unprotected connection')
    c = json.loads(p.read_text())
    if set(c) != {'protocol', 'seat', 'players', 'sockets'} or c['protocol'] != 2:
        raise ValueError('Connection protocol')
    seat, count, peers = c['seat'], c['players'], c['sockets']
    if type(seat) is not int or type(count) is not int or not 2 <= count <= 4 or not 1 <= seat <= count:
        raise ValueError('Connection seats')
    expected = {str(i) for i in range(2, count + 1)} if seat == 1 else {'1'}
    if not isinstance(peers, dict) or set(peers) != expected:
        raise ValueError('Connection peers')
    for path in peers.values():
        if not isinstance(path, str) or not Path(path).is_absolute() or Path(path).name != 'cabinet.sock':
            raise ValueError('Connection socket')
    return c


class Bridge:
    def __init__(self, c):
        self.selector = selectors.DefaultSelector()
        self.channels = []
        self.active = True
        try:
            for peer, path in c['sockets'].items():
                stream = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
                udp = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
                state = {'stream': stream, 'udp': udp, 'rx': bytearray(), 'tx': bytearray(),
                         'address': SERVER if c['seat'] == 1 else None, 'host': c['seat'] == 1}
                self.channels.append(state)
                stream.settimeout(3)
                stream.connect(path)
                stream.setblocking(False)
                udp.bind(('127.0.0.1', 0) if c['seat'] == 1 else SERVER)
                udp.setblocking(False)
                self.selector.register(stream, selectors.EVENT_READ, (state, True))
                self.selector.register(udp, selectors.EVENT_READ, (state, False))
        except BaseException:
            self.close()
            raise

    def close(self):
        self.active = False
        self.selector.close()
        for c in self.channels:
            c['stream'].close()
            c['udp'].close()
            c['rx'].clear()
            c['tx'].clear()

    def poll(self, timeout=.05):
        if not self.active:
            return
        try:
            for key, events in self.selector.select(timeout):
                c, stream = key.data
                if stream:
                    if events & selectors.EVENT_READ:
                        data = c['stream'].recv(32768)
                        if not data:
                            raise ValueError('Peer disconnected')
                        c['rx'].extend(data)
                        while len(c['rx']) >= 2:
                            size = struct.unpack_from('!H', c['rx'])[0]
                            if not 1 <= size <= MAX_PACKET:
                                raise ValueError('Invalid datagram size')
                            if len(c['rx']) < size + 2:
                                break
                            data = bytes(c['rx'][2:size + 2])
                            del c['rx'][:size + 2]
                            if c['address']:
                                c['udp'].sendto(data, c['address'])
                    if events & selectors.EVENT_WRITE:
                        sent = c['stream'].send(c['tx'])
                        if sent <= 0:
                            raise ValueError('Peer stopped accepting data')
                        del c['tx'][:sent]
                        if not c['tx']:
                            self.selector.modify(c['stream'], selectors.EVENT_READ, (c, True))
                else:
                    data, address = c['udp'].recvfrom(MAX_PACKET + 1)
                    if not data or len(data) > MAX_PACKET or address[0] != '127.0.0.1':
                        continue
                    if c['address'] is None:
                        c['address'] = address
                    if address != c['address']:
                        continue
                    if len(c['tx']) + len(data) + 2 > MAX_QUEUE:
                        raise ValueError('Peer is too slow')
                    c['tx'].extend(struct.pack('!H', len(data)) + data)
                    self.selector.modify(c['stream'], selectors.EVENT_READ | selectors.EVENT_WRITE, (c, True))
        except BlockingIOError:
            pass
        except (OSError, ValueError):
            self.close()
