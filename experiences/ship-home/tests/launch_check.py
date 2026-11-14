#!/usr/bin/env python3
"""Check the installed Linux entry under Xvfb; close its real X11 window politely."""
# SPDX-License-Identifier: GPL-3.0-or-later
import ctypes as C
import os
from pathlib import Path
import subprocess
import sys
import time

launcher = Path(sys.argv[1]).resolve()
# A bare Xvfb has no WM to intern WM_DELETE_WINDOW before Godot starts.
x = C.CDLL('libX11.so.6')
x.XOpenDisplay.restype = C.c_void_p
display = x.XOpenDisplay(None)
assert display, 'X11 display unavailable'
x.XInternAtom.argtypes=[C.c_void_p,C.c_char_p,C.c_int];x.XInternAtom.restype=C.c_ulong
x.XInternAtom(display,b'WM_DELETE_WINDOW',0)
x.XInternAtom(display,b'WM_PROTOCOLS',0)
log = open(sys.argv[2], 'w')
child = subprocess.Popen([sys.executable, str(launcher)], stdout=log, stderr=log)
try:
    time.sleep(3)
    assert child.poll() is None, 'Installed game exited before opening'
    assert 'godot' in Path(f'/proc/{child.pid}/comm').read_text().lower(), 'Launcher did not retain its tracked PID'
    duplicate = subprocess.run([sys.executable, str(launcher)], env={**os.environ, 'PATH': ''}, capture_output=True, timeout=10)
    assert duplicate.returncode == 1 and b'already open' in duplicate.stderr, 'Duplicate writer was not rejected'
    x.XDefaultRootWindow.argtypes=[C.c_void_p];x.XDefaultRootWindow.restype=C.c_ulong
    x.XQueryTree.argtypes=[C.c_void_p,C.c_ulong,C.POINTER(C.c_ulong),C.POINTER(C.c_ulong),C.POINTER(C.POINTER(C.c_ulong)),C.POINTER(C.c_uint)]
    root=C.c_ulong();parent=C.c_ulong();children=C.POINTER(C.c_ulong)();count=C.c_uint()
    x.XQueryTree(display,x.XDefaultRootWindow(display),C.byref(root),C.byref(parent),C.byref(children),C.byref(count))
    x.XFetchName.argtypes=[C.c_void_p,C.c_ulong,C.POINTER(C.c_char_p)]
    target=0
    for i in range(count.value):
        name=C.c_char_p()
        if x.XFetchName(display,children[i],C.byref(name)) and name.value:
            if b'Ship Home' in name.value:target=children[i]
    assert target, 'Ship window not found'
    class Data(C.Union):
        _fields_=[('b',C.c_char*20),('s',C.c_short*10),('l',C.c_long*5)]
    class Message(C.Structure):
        _fields_=[('type',C.c_int),('serial',C.c_ulong),('send_event',C.c_int),('display',C.c_void_p),('window',C.c_ulong),('message_type',C.c_ulong),('format',C.c_int),('data',Data)]
    class Event(C.Union):
        _fields_=[('message',Message),('pad',C.c_long*24)]
    x.XInternAtom.argtypes=[C.c_void_p,C.c_char_p,C.c_int];x.XInternAtom.restype=C.c_ulong
    event=Event();m=event.message;m.type=33;m.display=display;m.window=target;m.format=32
    m.message_type=x.XInternAtom(display,b'WM_PROTOCOLS',0);m.data.l[0]=x.XInternAtom(display,b'WM_DELETE_WINDOW',0)
    x.XSendEvent.argtypes=[C.c_void_p,C.c_ulong,C.c_int,C.c_long,C.POINTER(Event)]
    assert x.XSendEvent(display,target,0,0,C.byref(event)) != 0
    x.XFlush.argtypes=[C.c_void_p];x.XFlush(display)
    assert child.wait(timeout=40)==0, 'Window close did not finish cleanly'
    print('INSTALLED SHIP LAUNCH / SINGLE INSTANCE / WINDOW CLOSE PASSED')
finally:
    if child.poll() is None:
        child.terminate();child.wait(timeout=5)
    log.close()
