# SPDX-License-Identifier: GPL-3.0-or-later
"""Preparation wire and own-save failure regressions; no game data required."""
import concurrent.futures
import hashlib
import json
from pathlib import Path
import runpy
import socket
import struct
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1] / 'packaging/emulators/ngpc'
state = runpy.run_path(str(ROOT / 'state.py'))
channel = runpy.run_path(str(ROOT / 'channel.py'))
CONTENT = hashlib.sha256(b'original cartridge fixture').hexdigest()
CAP = (0x200000, 0x200000)


def save(byte=1):
    return state['encode'](CONTENT, b'', bytes([byte])*16, bytes([byte])*0x3000, 1000)


def flash(blocks):
    data = b''.join(struct.pack('<IH2x', address, len(data))+data for address, data in blocks)
    return struct.pack('<HHI', 0x53, len(blocks), 8+len(data))+data


class Fragmented:
    def __init__(self, stream): self.stream=stream
    def setblocking(self, value): self.stream.setblocking(value)
    def send(self, data): return self.stream.send(data[:37])
    def recv(self, n): return self.stream.recv(min(n, 29))
    def close(self): self.stream.close()


class NgpcLinkTests(unittest.TestCase):
    def test_offline_clock_crosses_leap_day_without_changing_alarm(self):
        raw=bytes([1,0x24,2,0x28,0x23,0x59,0x59,3,1,2,3,4,5,0,0,0])
        advanced=state['advance_clock'](raw,86401)
        self.assertEqual(advanced[1:8],bytes([0x24,3,1,0,0,0,5]))
        self.assertEqual(advanced[8:],raw[8:])
        self.assertEqual(state['advance_clock'](b'\0'+raw[1:],86401),b'\0'+raw[1:])

    def test_flash_rejects_truncation_overlap_and_foreign_ranges(self):
        good=flash([(0x200000,b'one'),(0x800000,b'two')])
        self.assertEqual(len(state['unpack_flash'](good,CAP)),2)
        for bad in (good[:-1],good+b'x',flash([(0x1fffff,b'x')]),
                    flash([(0x3fffff,b'xx')]),flash([(0x200000,b'abc'),(0x200001,b'z')]),
                    flash([(0x200000,b'')])):
            with self.subTest(blob=bad), self.assertRaises(ValueError):state['unpack_flash'](bad,CAP)

    def test_state_rejects_wrong_identity_encoding_and_sizes(self):
        self.assertEqual(state['decode'](save(),CONTENT,CAP)['savedAt'],1000)
        for key,value in (('content','foreign'),('battery','AA=='),('rtc',[]),('savedAt',True),('extra',1)):
            bad=json.loads(save());bad[key]=value
            with self.subTest(key=key),self.assertRaises(ValueError):state['decode'](json.dumps(bad).encode(),CONTENT,CAP)

    def test_own_stores_reopen_and_never_exchange_ownership(self):
        with tempfile.TemporaryDirectory() as directory:
            a=state['Store'](Path(directory)/'a',CONTENT,CAP);b=state['Store'](Path(directory)/'b',CONTENT,CAP)
            a.commit(save(1));b.commit(save(2))
            a=state['Store'](a.root,CONTENT,CAP);b=state['Store'](b.root,CONTENT,CAP)
            self.assertEqual(a.raw,save(1));self.assertEqual(b.raw,save(2))
            self.assertEqual(len(list(a.root.glob('before-*.json'))),1)
            a.commit(save(3));self.assertEqual(b.path.read_bytes(),save(2))

    def test_changed_save_and_failed_atomic_replace_preserve_previous(self):
        with tempfile.TemporaryDirectory() as directory:
            store=state['Store'](directory,CONTENT,CAP);store.commit(save())
            with patch('os.replace',side_effect=OSError('disk full')),self.assertRaises(OSError):store.commit(save(2))
            self.assertEqual(store.path.read_bytes(),save());self.assertFalse(list(store.root.glob('*.tmp')))
            store.path.write_bytes(save(3))
            with self.assertRaises(ValueError):store.commit(save(2))
            self.assertEqual(store.path.read_bytes(),save(3))

    def test_symlink_save_is_not_followed(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);(root/'other').write_bytes(save());(root/'state.json').symlink_to(root/'other')
            with self.assertRaises(ValueError):state['Store'](root,CONTENT,CAP)
            self.assertEqual((root/'other').read_bytes(),save())

    def test_fragmented_preparation_and_mirror_stream(self):
        x,y=socket.socketpair();a=channel['Channel'](Fragmented(x));b=channel['Channel'](Fragmented(y))
        try:
            with concurrent.futures.ThreadPoolExecutor(2) as pool:
                left=pool.submit(a.exchange,save(1),b'i'*32,lambda:True,10)
                right=pool.submit(b.exchange,save(2),b'i'*32,lambda:True,10)
                self.assertEqual(left.result(),save(2));self.assertEqual(right.result(),save(1))
            a.send(b'upstream protocol bytes')
            received=b''
            for _ in range(100):
                a.flush();received+=b.recv()
                if received==b'upstream protocol bytes':break
            self.assertEqual(received,b'upstream protocol bytes')
            a.close()
            with self.assertRaises(ConnectionError):b.recv()
        finally:
            x.close();y.close()

    def test_wrong_identity_and_cancel_refuse_before_game(self):
        for identity,update,error in ((b'j'*32,lambda:True,ValueError),(b'i'*32,lambda:False,InterruptedError)):
            x,y=socket.socketpair();a=channel['Channel'](x)
            try:
                y.sendall(struct.pack('!H',33)+b'H'+identity)
                with self.assertRaises(error):a.exchange(save(),b'i'*32,update,.1)
            finally:x.close();y.close()

    def test_bad_frames_and_queue_are_bounded(self):
        x,y=socket.socketpair();a=channel['Channel'](x)
        try:
            y.sendall(b'\0\0')
            with self.assertRaises(ValueError):a.recv()
            with self.assertRaises(ValueError):a.send(b'x'*(300*1024))
        finally:x.close();y.close()


if __name__=='__main__':unittest.main()
