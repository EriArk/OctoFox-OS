# SPDX-License-Identifier: GPL-3.0-or-later
"""ROM-free multi-process DS frontend check, using real cores and TLS helpers.

Run on Linux with a native frontend, Python transport venv and Qt offscreen/SDL
dummy drivers. This is lifecycle/determinism evidence, not wireless gameplay.
"""
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import selectors
import struct
import subprocess
import tempfile
import time


def cartridge():
    data = bytearray(0x10000)
    data[:12] = b'TRAINER TEST '
    data[12:16] = b'TST0'
    struct.pack_into('<IIII', data, 0x20, 0x200, 0x02000000, 0x02000000, 4)
    struct.pack_into('<IIII', data, 0x30, 0x204, 0x03800000, 0x03800000, 4)
    struct.pack_into('<II', data, 0x80, len(data), 0x200)
    struct.pack_into('<II', data, 0x200, 0xeafffffe, 0xeafffffe)
    return bytes(data)


def run(args, players):
    with tempfile.TemporaryDirectory() as temporary, selectors.DefaultSelector() as selector:
        root = Path(temporary)
        rom = root / 'test.nds'
        rom.write_bytes(cartridge())
        digest = hashlib.sha256(rom.read_bytes()).hexdigest()
        processes = {}
        exits = set()
        env = dict(os.environ, QT_QPA_PLATFORM='offscreen', SDL_AUDIODRIVER='dummy', SDL_VIDEODRIVER='dummy')

        def launch(seat, endpoint=None):
            assert 0 <= seat < players and seat not in processes
            staging = root / str(seat)
            staging.mkdir(mode=0o700)
            session = dict(version=2, ownerSeat=seat, content=digest,
                           seats=[dict(fresh=True) if i == seat else dict(peer=True) for i in range(players)])
            (staging / 'session.json').write_text(json.dumps(session))
            network = dict(host=seat == 0, players=players, identity='a' * 64, mode='nearby',
                           address='127.0.0.1', python=str(args.python.absolute()), helper=str(args.helper.resolve()))
            if endpoint:
                network.update(endpoint)
            config = staging / 'network.json'
            config.write_text(json.dumps(network))
            proc = subprocess.Popen([str(args.frontend.resolve()), str(rom), '--seats', str(players),
                                     '--prepared-session', str(staging), '--network-session', str(config),
                                     '--frames', '90', '--diagnostics'] + (['--interpreter'] if args.interpreter else []), env=env, stdout=subprocess.PIPE,
                                    stderr=subprocess.STDOUT)
            processes[seat] = (proc, bytearray(), bytearray())
            selector.register(proc.stdout, selectors.EVENT_READ, seat)

        try:
            launch(0)
            deadline = time.monotonic() + 120
            while time.monotonic() < deadline:
                for key, _ in selector.select(0.1):
                    seat = key.data
                    proc, pending, log = processes[seat]
                    data = os.read(key.fd, 65536)
                    if not data:
                        selector.unregister(key.fileobj)
                        continue
                    pending.extend(data)
                    log.extend(data)
                    while b'\n' in pending:
                        line, _, rest = pending.partition(b'\n')
                        pending[:] = rest
                        if line.startswith(b'TRAINEROS_DS_ENDPOINT '):
                            endpoint = json.loads(base64.b64decode(line.split(b' ', 1)[1]))
                            if players == 2:
                                launch(1, endpoint)
                            else:
                                launch(endpoint['seat'] - 1, endpoint['connection'])
                        if line.startswith(b'DS_NETWORK_EXIT checkpoints='):
                            assert int(line.split(b'=')[1]) >= players
                            exits.add(seat)
                        if line.startswith((b'[TrainerOSDs] error', b'DS_LOCAL_ERROR', b'DS_NETWORK_FAIL')):
                            raise RuntimeError(f'Frontend failed at seat {seat}')
                if len(processes) == players and all(p.poll() is not None for p, _, _ in processes.values()):
                    break
            assert len(processes) == players and len(exits) == players, 'Missing coordinated exit'
            receipts = []
            for seat, (proc, _, _) in processes.items():
                assert proc.wait(timeout=2) == 0
                receipt = json.loads((root / str(seat) / 'owner-return.json').read_text())
                assert receipt['ownerSeat'] == seat and receipt['content'] == digest
                assert receipt['hasSave'] is False and receipt['bytes'] == 0
                assert not (root / str(seat) / 'owner-return.sav').exists()
                receipts.append(receipt['frame'])
            assert len(set(receipts)) == 1
            assert rom.read_bytes() == cartridge()
            print(json.dumps(dict(players=players, independent_frontends=players, emulated_consoles=players**2,
                                  verified_exit=True, owner_receipts=players, return_frame=receipts[0], rom_unchanged=True)), flush=True)
        except Exception:
            for seat, (proc, _, log) in processes.items():
                safe_log = b'\n'.join(line for line in log.splitlines() if not line.startswith(b'TRAINEROS_DS_ENDPOINT '))
                print(f'FAILED seat={seat} exit={proc.poll()}: {safe_log[-5000:].decode(errors="replace")}')
            raise
        finally:
            for proc, _, _ in processes.values():
                if proc.poll() is None:
                    proc.terminate()
            for proc, _, _ in processes.values():
                try:
                    proc.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    proc.kill()
                    proc.wait()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('frontend', 'python', 'helper'):
        parser.add_argument(name, type=Path)
    parser.add_argument('--players', type=int, choices=(2, 3, 4), nargs='+', default=(2, 3, 4))
    parser.add_argument('--interpreter', action='store_true')
    options = parser.parse_args()
    for count in options.players:
        run(options, count)
