# SPDX-License-Identifier: GPL-3.0-or-later
# Synthetic empty disc: no game or proprietary BIOS needed. Checks state transport, not gameplay.
import ctypes as C,sys,hashlib,json,subprocess,tempfile
from pathlib import Path
if len(sys.argv)==2:
 with tempfile.TemporaryDirectory(prefix='neocd-state-') as tmp:
  root=Path(tmp);results=[]
  for name,extra in [('a',[]),('b',[]),('foreign',[str(root/'a/state.bin')])]:
   result=subprocess.run([sys.executable,__file__,sys.argv[1],str(root/name)]+extra,capture_output=True,text=True,timeout=30)
   if result.returncode:raise RuntimeError(result.stderr or result.stdout)
   results.append(json.loads(result.stdout))
  assert results[0]['state_hash']==results[1]['state_hash'], 'ASLR-dependent serialized state'
  assert len({r['after_hash'] for r in results})==1, 'Cross-process state replay differs'
  assert all(r['video_replay_equal'] and r['state_replay_equal'] for r in results)
  print(json.dumps({'independent_processes':3,'cross_process_equal':True,'repeat_replay_equal':True,'state_size':results[0]['size']}))
 sys.exit(0)
lib=C.CDLL(sys.argv[1]);out=Path(sys.argv[2]);out.mkdir(exist_ok=True)
class Game(C.Structure):_fields_=[('path',C.c_char_p),('data',C.c_void_p),('size',C.c_size_t),('meta',C.c_char_p)]
class Var(C.Structure):_fields_=[('key',C.c_char_p),('value',C.c_char_p)]
root=str(out).encode();opts={};callbacks=[];frames=[]
def env(cmd,data):
 cmd=cmd&0xffff
 if cmd in (9,31):C.cast(data,C.POINTER(C.c_char_p))[0]=root;return True
 if cmd==15:
  x=C.cast(data,C.POINTER(Var)).contents;x.value=opts.get(x.key);return x.value is not None
 if cmd==16:
  p=C.cast(data,C.POINTER(Var));i=0
  while p[i].key:
   if p[i].value and b'; ' in p[i].value:opts[p[i].key]=p[i].value.split(b'; ',1)[1].split(b'|')[0]
   i+=1
  return True
 if cmd==17:C.cast(data,C.POINTER(C.c_bool))[0]=False;return True
 return cmd in (10,11,18,44,45,60,63)
def video(p,w,h,pitch):
 if p:frames.append(hashlib.sha256(C.string_at(p,pitch*h)).hexdigest())
def setup(name,restype,args,fn):
 cb=C.CFUNCTYPE(restype,*args)(fn);callbacks.append(cb);getattr(lib,name)(cb)
setup('retro_set_environment',C.c_bool,[C.c_uint,C.c_void_p],env)
setup('retro_set_video_refresh',None,[C.c_void_p,C.c_uint,C.c_uint,C.c_size_t],video)
setup('retro_set_audio_sample_batch',C.c_size_t,[C.c_void_p,C.c_size_t],lambda p,n:n)
setup('retro_set_audio_sample',None,[C.c_int16,C.c_int16],lambda a,b:None)
setup('retro_set_input_poll',None,[],lambda:None)
setup('retro_set_input_state',C.c_int16,[C.c_uint]*4,lambda *a:0)
lib.retro_init()
lib.retro_load_game.argtypes=[C.POINTER(Game)];lib.retro_load_game.restype=C.c_bool
lib.retro_serialize_size.restype=C.c_size_t
lib.retro_serialize.argtypes=[C.c_void_p,C.c_size_t];lib.retro_serialize.restype=C.c_bool
lib.retro_unserialize.argtypes=[C.c_void_p,C.c_size_t];lib.retro_unserialize.restype=C.c_bool
cue=out/'probe.cue';disc=out/'probe.bin';disc.write_bytes(bytes(2048*64));cue.write_text('FILE "probe.bin" BINARY\n TRACK 01 MODE1/2048\n INDEX 01 00:00:00\n')
assert lib.retro_load_game(C.byref(Game(str(cue).encode(),None,0,None)))
lib.retro_get_memory_data.argtypes=[C.c_uint];lib.retro_get_memory_data.restype=C.c_void_p
sram=lib.retro_get_memory_data(0);assert sram
C.cast(sram,C.POINTER(C.c_ubyte))[0]=0x23
for _ in range(20):lib.retro_run()
n=lib.retro_serialize_size();assert 0<n<64*1024*1024
buf=C.create_string_buffer(n);assert lib.retro_serialize(buf,n);(out/'state.bin').write_bytes(buf.raw)
if len(sys.argv)>3:
 foreign=Path(sys.argv[3]).read_bytes();assert len(foreign)==n
 buf=C.create_string_buffer(foreign,n);assert lib.retro_unserialize(buf,n)
frames.clear()
for _ in range(20):lib.retro_run()
a=frames[:];after=C.create_string_buffer(n);assert lib.retro_serialize(after,n)
C.cast(sram,C.POINTER(C.c_ubyte))[0]=0x7c
assert lib.retro_unserialize(buf,n)
assert C.cast(sram,C.POINTER(C.c_ubyte))[0]==0x23, 'Backup RAM not restored'
frames.clear()
for _ in range(20):lib.retro_run()
b=frames[:];again=C.create_string_buffer(n);assert lib.retro_serialize(again,n)
(out/'after.bin').write_bytes(after.raw);(out/'replay.bin').write_bytes(again.raw)
print(json.dumps({'size':n,'state_hash':hashlib.sha256(buf.raw).hexdigest(),'video_replay_equal':a==b,'frames':len(a),'state_replay_equal':after.raw==again.raw,'after_hash':hashlib.sha256(after.raw).hexdigest()}))
assert a==b and after.raw==again.raw, 'Replay offsets: '+str([i for i,(x,y) in enumerate(zip(after.raw,again.raw)) if x!=y][:80])
lib.retro_unload_game();lib.retro_deinit()
