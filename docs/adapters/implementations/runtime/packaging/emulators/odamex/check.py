#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
import importlib.util
import json
import marshal
import os
from pathlib import Path
import shutil
import socket
import struct
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent
def load(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / (name + '.py'))
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result

content, endpoint = load('content'), load('endpoint')


def wad(path, names, magic=b'IWAD'):
    data = b'x'
    path.write_bytes(struct.pack('<4sii', magic, len(names), 13) + data
                     + b''.join(struct.pack('<ii8s', 12, 1, n) for n in names))


class Content(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.base = self.root / 'any name.wad'
        wad(self.base, [b'PLAYPAL', b'COLORMAP', b'PNAMES', b'TEXTURE1', b'STTNUM0', b'MAP01'])

    def test_filename_independence_and_mod_order(self):
        copy = self.root / 'different.wad'; shutil.copyfile(self.base, copy)
        self.assertEqual(content.content(self.base)['content'], content.content(copy)['content'])
        for name in ['one', 'two']:
            wad(self.root / (name + '.wad'), [name.encode()], b'PWAD')
        p = self.root / 'game.doom'
        recipe = dict(version=1, iwad=self.base.name, files=['one.wad', 'two.wad'])
        p.write_text(json.dumps(recipe)); first = content.content(p)
        recipe['files'].reverse(); p.write_text(json.dumps(recipe))
        self.assertNotEqual(first['content'], content.content(p)['content'])
        self.assertEqual(4, len(set(first['dependencies'])))

    def test_bounds_missing_base_and_unknown_options(self):
        pwad = self.root / 'mod.wad'; wad(pwad, [b'MAP01'], b'PWAD')
        with self.assertRaises(ValueError): content.content(pwad)
        p = self.root / 'game.doom'
        p.write_text(json.dumps(dict(version=1, iwad='missing.wad')))
        with self.assertRaises(OSError): content.content(p)
        p.write_text(json.dumps(dict(version=1, iwad=self.base.name, command='anything')))
        with self.assertRaises(ValueError): content.content(p)
        raw = bytearray(self.base.read_bytes()); struct.pack_into('<i', raw, 13, 1000000); self.base.write_bytes(raw)
        with self.assertRaises(ValueError): content.content(self.base)

    def test_custom_map_lump_names(self):
        mod = self.root / 'maps.wad'; wad(mod, [b'ARENA'], b'PWAD')
        recipe = self.root / 'match.doom'
        recipe.write_text(json.dumps(dict(version=1, iwad=self.base.name, files=[mod.name], map='arena')))
        self.assertEqual('ARENA', content.content(recipe)['map'])

    def test_unsealed_bytecode_cannot_replace_verified_source(self):
        for name in ['content.py', 'endpoint.py', 'launch.py']:
            shutil.copy2(ROOT / name, self.root / name)
        source = self.root / 'content.py'
        cache = Path(importlib.util.cache_from_source(str(source)))
        cache.parent.mkdir()
        # Valid timestamp/size header containing different executable code.
        cache.write_bytes(importlib.util.MAGIC_NUMBER + struct.pack('<III', 0, int(source.stat().st_mtime), source.stat().st_size)
                          + marshal.dumps(compile("raise RuntimeError('unsealed code ran')", str(source), 'exec')))
        result = subprocess.run([sys.executable, '-I', '-c',
            "import runpy,sys; assert runpy.run_path(sys.argv[1])['content'](sys.argv[2])['content']",
            str(self.root / 'launch.py'), str(self.base)], capture_output=True, text=True)
        self.assertEqual(0, result.returncode, result.stderr)

    def test_hidden_bex_dependency_is_rejected(self):
        p = self.root / 'game.doom'
        patch = self.root / 'patch.bex'; patch.write_text('include missing.bex\n')
        p.write_text(json.dumps(dict(version=1, iwad=self.base.name, deh=[patch.name])))
        with self.assertRaises(ValueError): content.content(p)

    def test_options_and_dependency_changes_are_identity(self):
        p = self.root / 'game.doom'
        recipe = dict(version=1, iwad=self.base.name)
        p.write_text(json.dumps(recipe)); before = content.content(p)['content']
        recipe['mode'] = 'deathmatch'; p.write_text(json.dumps(recipe))
        self.assertNotEqual(before, content.content(p)['content'])
        recipe['map'] = 'MAP01;quit'; p.write_text(json.dumps(recipe))
        with self.assertRaises(ValueError): content.content(p)
        with self.base.open('ab') as f: f.write(b'changed')
        self.assertNotEqual(before, content.content(self.base)['content'])


@unittest.skipUnless(os.name == 'posix', 'Linux UNIX-socket transport')
class Transport(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(); self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)

    def bridge(self, seat=1, count=2):
        listeners = []
        peers = {}
        for peer in (range(2, count + 1) if seat == 1 else [1]):
            d = self.root / str(peer); d.mkdir()
            path = str(d / 'cabinet.sock')
            s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM); s.bind(path); s.listen()
            self.addCleanup(s.close); listeners.append(s); peers[str(peer)] = path
        c = dict(protocol=2, seat=seat, players=count, sockets=peers)
        file = self.root / 'connection.json'; file.write_text(json.dumps(c)); file.chmod(0o600)
        b = endpoint.Bridge(endpoint.connection(file)); self.addCleanup(b.close)
        streams = [s.accept()[0] for s in listeners]
        for s in streams: s.settimeout(.5); self.addCleanup(s.close)
        return b, streams

    def test_host_three_guests_keep_addresses_and_datagrams_separate(self):
        native = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.addCleanup(native.close); native.bind(endpoint.SERVER); native.settimeout(.5)
        b, peers = self.bridge(count=4)
        addresses = []
        for i, peer in enumerate(peers):
            payload = bytes([i + 1]) * endpoint.MAX_PACKET
            packet = struct.pack('!H', len(payload)) + payload
            peer.sendall(packet[:1]); b.poll(.01); peer.sendall(packet[1:]); b.poll(.01)
            data, address = native.recvfrom(9000); self.assertEqual(payload, data); addresses.append(address)
            native.sendto(b'reply', address); b.poll(.01); b.poll(.01)
            self.assertEqual(b'\0\x05reply', peer.recv(99))
        self.assertEqual(3, len(set(addresses)))
        peers[1].close(); b.poll(.01); self.assertFalse(b.active)

    def test_guest_fixed_target_rejects_other_local_sender(self):
        b, peers = self.bridge(seat=2)
        native = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        other = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.addCleanup(native.close); self.addCleanup(other.close); native.settimeout(.5)
        native.sendto(b'join', endpoint.SERVER); b.poll(.01); b.poll(.01)
        self.assertEqual(b'\0\x04join', peers[0].recv(99))
        other.sendto(b'inject', endpoint.SERVER); b.poll(.01)
        self.assertEqual(b'', bytes(b.channels[0]['tx']))
        peers[0].sendall(b'\0\x02ok'); b.poll(.01)
        self.assertEqual(b'ok', native.recvfrom(99)[0])
        peers[0].sendall(b'\xff\xff'); b.poll(.01); self.assertFalse(b.active)

    def test_private_connection_rejects_extra_seat_and_unprotected_file(self):
        p = self.root / 'connection.json'
        c = dict(protocol=2, seat=2, players=2, sockets={'1': '/tmp/cabinet.sock', '3': '/tmp/cabinet.sock'})
        p.write_text(json.dumps(c)); p.chmod(0o600)
        with self.assertRaises(ValueError): endpoint.connection(p)
        del c['sockets']['3']; p.write_text(json.dumps(c)); p.chmod(0o644)
        with self.assertRaises(ValueError): endpoint.connection(p)


if __name__ == '__main__':
    unittest.main()
