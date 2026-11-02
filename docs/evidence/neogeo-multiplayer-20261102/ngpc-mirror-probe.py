# SPDX-License-Identifier: GPL-3.0-or-later
from pathlib import Path
import sys,time,json
root=Path(sys.argv[1]);sys.path.insert(0,str(root/'ngpcraft'))
from core.native import NativeMachine
from core.link import InProcessLink
from core.netplay import MirrorSession,Handshake,ListPipe
rom=(root/'ngpcraft/tests/roms/link_probe.ngc').read_bytes();bios=(root/'ngpcraft/hle_bios/bios_hle.bin').read_bytes();core=root/'ngpc-build/ngpcraft_libretro.so'
results=[]
for delay in (0,6):
 pa,pb=ListPipe.pair(delay)
 def side(pipe,host):
  a=NativeMachine(rom,bios=bios,dll=core);b=NativeMachine(rom,bios=bios,dll=core)
  for m in (a,b):m.set_timing_silicon();m.reset(bios_handoff=True)
  return MirrorSession(a,b,InProcessLink(a,b),pipe,Handshake(rom_hash='probe',bios_hash='hle',core_version='pinned',host=host,delay=4))
 a,b=side(pa,True),side(pb,False);started=time.monotonic()
 try:
  rejected=0
  for n in range(240):
   rejected+=a.step(8)=='rejected';rejected+=b.step(1)=='rejected'
  for _ in range(4*(delay+2)):
   if a.frames_run==b.frames_run:break
   if a.frames_run<b.frames_run:a.step(8)
   else:b.step(1)
  assert not rejected and a.desync_at is None and b.desync_at is None
  assert a.frames_run==b.frames_run and a.frames_run>=230
  assert a.local.read(0x4000,0x2c00)==b.peer.read(0x4000,0x2c00)
  assert a.peer.read(0x4000,0x2c00)==b.local.read(0x4000,0x2c00)
  assert a.local.read(0x400a,1)[0]==1 and a.peer.read(0x400a,1)[0]==8
  results.append({'delay_pumps':delay,'frames_each':a.frames_run,'native_consoles':4,'matched_memory':True,'peer_pad_received':True,'wall_seconds':round(time.monotonic()-started,3)})
 finally:
  for s in (a,b):s.local.close();s.peer.close()
print(json.dumps(results))
