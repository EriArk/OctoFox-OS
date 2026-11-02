#!/usr/bin/python3
# SPDX-License-Identifier: GPL-3.0-or-later
import ctypes as C
from datetime import datetime, timezone
import fcntl
import hashlib
import json
import os
from pathlib import Path
import runpy
import signal
import socket
import sys
import time

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / 'upstream.zip'))
from core.native import NativeMachine, RtcState
from core.link import InProcessLink
from core.netplay import MirrorSession, Handshake
from core.flash_file import diff_blocks, pack

state = runpy.run_path(str(ROOT / 'state.py'))
channel = runpy.run_path(str(ROOT / 'channel.py'))
STOP = False


def quit_signal(*_):
    global STOP
    STOP = True


class Frontend:
    def __init__(self):
        self.lib = C.CDLL(str(ROOT / 'frontend.so'))
        self.lib.ngpc_frontend_open.argtypes = [C.c_char_p]
        self.lib.ngpc_frontend_present.argtypes = [C.c_void_p, C.c_void_p, C.c_int, C.c_char_p]
        self.lib.ngpc_frontend_poll.restype = C.c_int
        if self.lib.ngpc_frontend_open(str(ROOT / 'font.ttf').encode()) != 0:
            raise RuntimeError('Could not open the game window')
        self.pixels = (C.c_uint16 * (160 * 152))()
        self.pad = 0

    def poll(self):
        self.pad = self.lib.ngpc_frontend_poll()
        return not STOP and self.pad >= 0

    def show(self, machine=None, text=''):
        samples = b''
        if machine is not None:
            machine._lib.ngpc_get_framebuffer(machine._h, self.pixels, len(self.pixels))
            samples = machine.audio()
        self.lib.ngpc_frontend_present(self.pixels, C.c_char_p(samples) if samples else None, len(samples), text.encode())

    def close(self): self.lib.ngpc_frontend_close()


def apply(machine, raw, content, capacities):
    data = state['decode'](raw, content, capacities)
    machine.set_battery_ram(data['battery'])
    machine.reset(bios_handoff=True)
    machine.set_rtc(RtcState.from_buffer_copy(data['rtc']))
    for address, block in data['blocks']: machine.flash_restore(address, block)
    machine.flash_clear_dirty()


def snapshot(machine, content, originals):
    blocks = []
    for base, original in zip((0x200000, 0x800000), originals):
        if original: blocks += diff_blocks(original, machine.flash_peek(base, len(original)), base)
    return state['encode'](content, pack(blocks), bytes(machine.rtc()), machine.battery_ram())


def main():
    romfile, expected, directory, config = sys.argv[1:5]
    rom = Path(romfile).read_bytes()
    if not 64 <= len(rom) <= 0x400000 or hashlib.sha256(rom).hexdigest() != expected:
        raise ValueError('The cartridge changed')
    seat, path = channel['connection'](config)
    folder = Path(directory);folder.mkdir(parents=True, exist_ok=True)
    lock = (folder / 'runtime.lock').open('a+b');fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    manifest = json.loads((ROOT / 'manifest.json').read_text())
    bios = (ROOT / 'bios_hle.bin').read_bytes()
    own = peer = pipe = frontend = store = None
    normal = False; playing = False; failed = False; error_text = ''
    try:
        own = NativeMachine(rom, bios=bios, dll=ROOT / 'core.so')
        peer = NativeMachine(rom, bios=bios, dll=ROOT / 'core.so')
        for machine in (own, peer):
            machine.set_timing_silicon();machine.set_language(1);machine.reset(bios_handoff=True)
        capacities = [own.flash_capacity(i) or max(0,min(0x200000,len(rom)-i*0x200000)) for i in (0,1)]
        originals = [own.flash_peek(base, cap) if cap else b'' for base, cap in zip((0x200000,0x800000), capacities)]
        store = state['Store'](folder, expected, capacities)
        if store.raw:
            apply(own,store.raw,expected,capacities)
            saved = state['decode'](store.raw,expected,capacities)['savedAt']
            # Only the owner advances its clock; both mirrored copies then receive
            # the exact same prepared seed, independent of the peer's wall clock.
            own.set_rtc(RtcState.from_buffer_copy(state['advance_clock'](bytes(own.rtc()),max(0,int(time.time())-saved))))
        else:
            now = datetime.now(timezone.utc)
            bcd = lambda n: ((n//10)<<4)|(n%10)
            rtc = own.rtc();rtc.enable=1
            for key,value in (('year',now.year%100),('month',now.month),('day',now.day),('hour',now.hour),('minute',now.minute),('second',now.second),('weekday',(now.weekday()+1)%7)):
                setattr(rtc,key,bcd(value))
            own.set_rtc(rtc)
        seed = snapshot(own, expected, originals)
        apply(own, seed, expected, capacities)
        frontend = Frontend()
        stream = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM);stream.settimeout(3);stream.connect(path)
        pipe = channel['Channel'](stream)
        identity = hashlib.sha256((expected + '/' + manifest['settings'] + '/' + manifest['runtime']).encode()).digest()
        def waiting():
            frontend.show(text='Preparing Link...\nHome: game menu');return frontend.poll()
        remote = pipe.exchange(seed, identity, waiting)
        apply(peer, remote, expected, capacities)
        hs = Handshake(rom_hash=expected,bios_hash=hashlib.sha256(bios).hexdigest(),
                       core_version=manifest['runtime'],host=seat==1,delay=4,timing='silicon')
        session = MirrorSession(own, peer, InProcessLink(own, peer), pipe, hs)
        deadline = time.monotonic();last_frame = deadline;last_save = deadline
        playing = True
        while frontend.poll():
            now = time.monotonic()
            if failed:
                frontend.show(text=error_text);time.sleep(.02);continue
            try:
                result = session.step(frontend.pad)
                if len(session.peer_inputs)>4096 or len(session._checks)>4096:
                    raise ValueError('Peer input queue exceeded')
                if session.rejected or session.desync_at is not None or now-last_frame>15:
                    raise ConnectionError('Link lost or inconsistent')
                if result == 'ran':
                    if session.frames_run==1:print('TRAINEROS_NGPC_READY',flush=True)
                    last_frame=now;frontend.show(own);peer.audio()
                    deadline += 515*199/6144000
                    if now-last_save>15:
                        try:store.commit(snapshot(own,expected,originals));last_save=now
                        except (OSError,ValueError):
                            error_text='Could not save your progress. Previous saves are kept.\nReturn to the lobby.'
                            raise
                    time.sleep(max(0, min(.02, deadline-time.monotonic())))
                else:
                    deadline=now
                    if now-last_frame>.5:frontend.show(text='Waiting for the other player...\nHome: game menu')
                    time.sleep(.001)
            except (OSError, ValueError, ConnectionError):
                error_text=error_text or 'Link disconnected. Your last saved progress is kept.\nReturn to the lobby to reconnect.'
                failed=True;pipe.close()
        normal = not failed
    except (OSError, ValueError, RuntimeError, TimeoutError) as error:
        print('NGPC preparation failed: '+type(error).__name__,file=sys.stderr,flush=True)
        if frontend:
            while frontend.poll():
                frontend.show(text='Could not prepare Link. Your saves are kept.\nReturn to the lobby and try again.');time.sleep(.02)
        else: print('NGPC Link could not start. Your saves were kept.',file=sys.stderr)
    finally:
        if normal and playing and store:
            try:store.commit(snapshot(own,expected,originals))
            except (OSError,ValueError):
                normal=False
                print('NGPC Link could not save progress. Previous saves were kept.',file=sys.stderr)
        if pipe:pipe.close()
        if own:own.close()
        if peer:peer.close()
        if frontend:frontend.close()
        lock.close()
        if playing:print('NGPC frames: '+str(session.frames_run),flush=True)
    return 0 if normal else 2


if __name__ == '__main__':
    signal.signal(signal.SIGTERM,quit_signal);signal.signal(signal.SIGINT,quit_signal)
    sys.exit(main())
