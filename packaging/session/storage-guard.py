#!/usr/bin/python3 -I
# SPDX-License-Identifier: GPL-3.0-or-later
"""Bounded workaround for the observed Armada 7.2.6 Flip2 UFS deadlock.

Keep clock scaling disabled on the affected host until a kernel with the locking
fix is available. No boot image, clock rate, disk content or suspend policy changes.
"""
import os
from pathlib import Path
import platform

NODE = 'sys/bus/platform/devices/1d84000.ufshc/clkscale_enable'


def affected(root=Path('/'), kernel=None, machine=None):
    if (kernel or platform.release()) != '7.2.6' or (machine or platform.machine()) != 'aarch64':
        return False
    release = root / 'etc/os-release'
    compatible = root / 'proc/device-tree/compatible'
    return (release.is_file() and 'ID=armada' in release.read_text().splitlines()
            and compatible.is_file() and b'retroidpocket,rpflip2' in compatible.read_bytes().split(b'\0'))


def needed(root=Path('/'), **host):
    if not affected(root, **host): return False
    node = root / NODE
    if not node.is_file() or node.read_text().strip() not in ('0', '1'):
        raise RuntimeError('Cannot verify the Flip2 storage safety setting. Setup has not started; use a supported Armada kernel.')
    return node.read_text().strip() == '1'


def apply(root=Path('/'), **host):
    if not needed(root, **host): return False
    # Do not queue another write into a device which may already be deadlocked.
    pressure = (root / 'proc/pressure/io').read_text()
    if max(float(line.split('avg10=', 1)[1].split()[0]) for line in pressure.splitlines()) >= 20:
        raise RuntimeError('Storage is busy or stalled. Close other disk operations and retry. If the system is unresponsive, restart before installing.')
    node = root / NODE
    node.write_text('0\n')
    if node.read_text().strip() != '0': raise RuntimeError('Could not enable the Flip2 storage safety workaround.')
    return True


if __name__ == '__main__':
    if os.geteuid() != 0: raise SystemExit('The storage safety step requires administrator authorization.')
    print('Flip2 storage safety: ' + ('applied for this boot' if apply() else 'already safe or not affected'))
