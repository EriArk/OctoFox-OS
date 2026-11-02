#!/usr/bin/python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Native mirror/save/SDL process check over real cabinet ICE/DTLS.

Usage: check.py SEALED_BUNDLE UPSTREAM_FREE_LINK_PROBE TRANSPORT_CHECK_PY
Run in an isolated Linux network namespace, never against a user's game/save.
"""
import concurrent.futures
import hashlib
import json
import os
from pathlib import Path
import queue
import runpy
import signal
import socket
import subprocess
import sys
import tempfile
import threading
import time

root,romfile,transport_check=map(lambda p:Path(p).resolve(),sys.argv[1:4])
api=runpy.run_path(str(root/'launch.py'))
sys.argv=['check',str(root/'stream_transport')]
Pair=runpy.run_path(str(transport_check))['Pair']
rom=romfile.read_bytes();content=hashlib.sha256(rom).hexdigest()
bios=(root/'bios_hle.bin').read_bytes();manifest=json.loads((root/'manifest.json').read_text())


def pair():
    p=Pair(modes=['cabinet','cabinet']);assert p.connect(15),p.output
    return p


def socket_path(p,i):
    return dict(line.split('=',1) for line in p.ready[i].read_text().splitlines())['socket']


def machine():
    m=api['NativeMachine'](rom,bios=bios,dll=root/'core.so')
    m.set_timing_silicon();m.set_language(1);m.reset(bios_handoff=True)
    return m


with tempfile.TemporaryDirectory(prefix='ngpc-check-') as directory:
    folder=Path(directory)
    # The free probe is smaller than a flash die. Give this disposable fixture
    # an erased 4-Mbit chip so persistence exercises a real native flash window.
    rom=rom.ljust(0x80000,b'\xff');romfile=folder/'flash-probe.ngc';romfile.write_bytes(rom)
    content=hashlib.sha256(rom).hexdigest()
    machines=[machine() for _ in range(4)];p=pair();pipes=[]
    try:
        capacities=[machines[0].flash_capacity(i) for i in (0,1)]
        originals=[machines[0].flash_peek(base,cap) if cap else b'' for base,cap in zip((0x200000,0x800000),capacities)]
        seeds=[];stores=[]
        for i in (0,1):
            own=machines[i*2];rtc=own.rtc();rtc.enable=1;rtc.year=0x26;rtc.month=1;rtc.day=i+1;own.set_rtc(rtc)
            own.flash_restore(0x200000+capacities[0]-256,bytes([0xa1+i])*256)
            seeds.append(api['snapshot'](own,content,originals))
            store=api['state']['Store'](folder/str(i),content,capacities);store.commit(seeds[-1]);stores.append(store)
            s=socket.socket(socket.AF_UNIX);s.connect(socket_path(p,i));pipes.append(api['channel']['Channel'](s))
        with concurrent.futures.ThreadPoolExecutor(2) as pool:
            jobs=[pool.submit(pipes[i].exchange,seeds[i],b'i'*32,lambda:True,15) for i in (0,1)]
            remote=[job.result() for job in jobs]
        sessions=[]
        for i in (0,1):
            own,peer=machines[2*i:2*i+2]
            api['apply'](own,seeds[i],content,capacities);api['apply'](peer,remote[i],content,capacities)
            sessions.append(api['MirrorSession'](own,peer,api['InProcessLink'](own,peer),pipes[i],
                api['Handshake'](rom_hash=content,bios_hash=hashlib.sha256(bios).hexdigest(),core_version=manifest['runtime'],host=i==0,delay=4,timing='silicon')))
        start=time.monotonic()
        while min(s.frames_run for s in sessions)<300 and time.monotonic()-start<15:
            for i,s in enumerate(sessions):
                if s.frames_run<300:s.step(8 if i==0 else 1)
                s.local.audio();s.peer.audio()
            assert all(not s.rejected and s.desync_at is None for s in sessions)
        assert [s.frames_run for s in sessions]==[300,300]
        assert machines[0].read(0x4000,0x2c00)==machines[3].read(0x4000,0x2c00)
        assert machines[1].read(0x4000,0x2c00)==machines[2].read(0x4000,0x2c00)
        assert machines[0].read(0x400a,1)==b'\x01' and machines[2].read(0x400a,1)==b'\x08'
        for i,store in enumerate(stores):
            store.commit(api['snapshot'](machines[i*2],content,originals))
            decoded=api['state']['decode'](store.raw,content,capacities)
            assert any(block==bytes([0xa1+i])*256 for _,block in decoded['blocks'])
        print(json.dumps({'native_frames_each':300,'transport':'cabinet ICE/DTLS','own_flash_and_rtc':True,'peer_buttons':True,'seconds':round(time.monotonic()-start,3)}),flush=True)
    finally:
        for pipe in pipes:pipe.close()
        for m in machines:m.close()
        p.close()

    # Two real launchers, SDL rendering/audio, protected persistent restart and
    # the same TERM/EOF boundaries used by the normal Home/exit flow.
    for lose_link in (False,True):
        p=pair();children=[];events=queue.Queue();logs=[[],[]]
        before=[(folder/str(i)/'state.json').read_bytes() for i in (0,1)]
        def read(i,child):
            for line in child.stdout:
                logs[i].append(line.strip());events.put((i,line.strip()))
        try:
            for i in (0,1):
                config=folder/('connection-'+str(i)+'.json')
                config.write_text(json.dumps(dict(protocol=2,seat=i+1,players=2,sockets={str(2-i):socket_path(p,i)})));config.chmod(0o600)
                env=dict(os.environ,SDL_VIDEODRIVER='dummy',SDL_AUDIODRIVER='dummy',LD_LIBRARY_PATH=str(root/'lib'))
                child=subprocess.Popen([sys.executable,'-I',str(root/'launch.py'),str(romfile),content,str(folder/str(i)),str(config)],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
                children.append(child);threading.Thread(target=read,args=(i,child),daemon=True).start()
            ready=set();end=time.monotonic()+15
            while len(ready)<2 and time.monotonic()<end:
                try:
                    i,line=events.get(timeout=.5)
                    if line=='TRAINEROS_NGPC_READY':ready.add(i)
                except queue.Empty:pass
                assert all(child.poll() is None for child in children),logs
            assert len(ready)==2,logs
            time.sleep(.5)
            if lose_link:
                p.close();time.sleep(.3)
                assert all(child.poll() is None for child in children),'Loss should keep the owned window'
            for child in children:child.send_signal(signal.SIGTERM)
            codes=[child.wait(timeout=4) for child in children]
            if lose_link:
                assert codes==[2,2],(codes,logs)
                assert before==[(folder/str(i)/'state.json').read_bytes() for i in (0,1)]
            else:assert all(code in (0,2) for code in codes) and 0 in codes,(codes,logs)
            for i in (0,1):
                saved=api['state']['decode']((folder/str(i)/'state.json').read_bytes(),content,capacities)
                assert any(block==bytes([0xa1+i])*256 for _,block in saved['blocks'])
            print(json.dumps({'two_sdl_launchers':True,'restart_kept_own_flash':True,'loss_keeps_window_and_checkpoint':lose_link,'exit_codes':codes,'logs':logs}),flush=True)
        finally:
            for child in children:
                if child.poll() is None:child.kill();child.wait()
                child.stdout.close()
            if not lose_link:p.close()
