# SPDX-License-Identifier: GPL-3.0-or-later
"""Actual SDL frontend: virtual pad, hotplug, focus neutralization and close."""
import ctypes as C
import os
from pathlib import Path
import runpy
import sys

root=Path(sys.argv[1]).resolve()
os.environ['SDL_VIDEODRIVER']='dummy';os.environ['SDL_AUDIODRIVER']='dummy'
api=runpy.run_path(str(root/'launch.py'));frontend=api['Frontend']()
sdl=C.CDLL('libSDL2-2.0.so.0')
sdl.SDL_JoystickOpen.argtypes=[C.c_int];sdl.SDL_JoystickOpen.restype=C.c_void_p
sdl.SDL_JoystickSetVirtualButton.argtypes=[C.c_void_p,C.c_int,C.c_uint8]
sdl.SDL_JoystickClose.argtypes=[C.c_void_p]
sdl.SDL_PushEvent.argtypes=[C.c_void_p]
index=sdl.SDL_JoystickAttachVirtual(1,6,21,1);assert index>=0
joystick=sdl.SDL_JoystickOpen(index);assert joystick

def focus(event):
    packet=C.create_string_buffer(56)
    C.c_uint32.from_buffer(packet).value=0x200
    packet[12]=bytes([event])
    assert sdl.SDL_PushEvent(packet)==1

try:
    focus(12);assert frontend.poll()
    assert sdl.SDL_JoystickSetVirtualButton(joystick,0,1)==0
    sdl.SDL_JoystickUpdate();assert frontend.poll() and frontend.pad&16,frontend.pad
    focus(13);assert frontend.poll() and frontend.pad==0
    assert sdl.SDL_JoystickSetVirtualButton(joystick,0,0)==0
    sdl.SDL_JoystickUpdate();focus(12);assert frontend.poll() and frontend.pad==0
    frontend.show(text='Link ready\nHome: game menu')
    sdl.SDL_JoystickClose(joystick);joystick=None
    assert sdl.SDL_JoystickDetachVirtual(index)==0
    assert frontend.poll() and frontend.pad==0
    event=C.create_string_buffer(56);C.c_uint32.from_buffer(event).value=0x100
    assert sdl.SDL_PushEvent(event)==1
    assert not frontend.poll()
    print('SDL virtual pad, focus neutralization, hotplug, render/audio startup and quit passed')
finally:
    if joystick:sdl.SDL_JoystickClose(joystick)
    frontend.close()
