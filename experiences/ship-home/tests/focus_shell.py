#!/usr/bin/env python3
"""Activate the isolated OctoFox window when running shell UI checks in bare Xvfb."""
# SPDX-License-Identifier: GPL-3.0-or-later
import ctypes as C
import subprocess,sys,time
x=C.CDLL('libX11.so.6');x.XOpenDisplay.restype=C.c_void_p;d=x.XOpenDisplay(None)
x.XDefaultRootWindow.argtypes=[C.c_void_p];x.XDefaultRootWindow.restype=C.c_ulong
x.XQueryTree.argtypes=[C.c_void_p,C.c_ulong,C.POINTER(C.c_ulong),C.POINTER(C.c_ulong),C.POINTER(C.POINTER(C.c_ulong)),C.POINTER(C.c_uint)]
x.XFetchName.argtypes=[C.c_void_p,C.c_ulong,C.POINTER(C.c_char_p)]
x.XSetInputFocus.argtypes=[C.c_void_p,C.c_ulong,C.c_int,C.c_ulong]
x.XFlush.argtypes=[C.c_void_p]
class Attributes(C.Structure):
 _fields_=[('x',C.c_int),('y',C.c_int),('width',C.c_int),('height',C.c_int),('border',C.c_int),('depth',C.c_int),('visual',C.c_void_p),('root',C.c_ulong),('cls',C.c_int),('bit_gravity',C.c_int),('win_gravity',C.c_int),('backing_store',C.c_int),('planes',C.c_ulong),('pixel',C.c_ulong),('save_under',C.c_int),('colormap',C.c_ulong),('installed',C.c_int),('map_state',C.c_int),('all',C.c_long),('mine',C.c_long),('no',C.c_long),('override',C.c_int),('screen',C.c_void_p)]
x.XGetWindowAttributes.argtypes=[C.c_void_p,C.c_ulong,C.POINTER(Attributes)]
p=subprocess.Popen(sys.argv[1:]);focused=False;deadline=time.monotonic()+20
while p.poll() is None and not focused and time.monotonic()<deadline:
 root=C.c_ulong();parent=C.c_ulong();children=C.POINTER(C.c_ulong)();count=C.c_uint()
 x.XQueryTree(d,x.XDefaultRootWindow(d),C.byref(root),C.byref(parent),C.byref(children),C.byref(count))
 for i in range(count.value):
  name=C.c_char_p();attr=Attributes()
  if x.XFetchName(d,children[i],C.byref(name)) and name.value==b'OctoFox OS' and x.XGetWindowAttributes(d,children[i],C.byref(attr)) and attr.map_state==2:
   x.XSetInputFocus(d,children[i],2,0);x.XFlush(d);focused=True;break
 time.sleep(.02)
print('QA window activated:',focused,flush=True)
sys.exit(p.wait())
