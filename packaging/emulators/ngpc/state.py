# SPDX-License-Identifier: GPL-3.0-or-later
"""Own linked-console progress. ROMs and the peer's state are never written."""
import base64
from datetime import datetime, timedelta
import json
import os
from pathlib import Path
import struct
import time
import uuid

MAX_STATE = 6 * 1024 * 1024


def advance_clock(raw, seconds):
    """Offline calendar only; preserve alarm/subsecond state and stopped clocks."""
    if len(raw)!=16:raise ValueError('Clock size')
    if not raw[0] or seconds<=0:return raw
    def unbcd(v):
        if v>>4>9 or v&15>9:raise ValueError('Invalid calendar')
        return (v>>4)*10+(v&15)
    try:
        fields=[unbcd(v) for v in raw[1:7]]
        before=datetime(2000+fields[0],*fields[1:])
        after=before+timedelta(seconds=min(seconds,366*86400*100))
        values=(after.year%100,after.month,after.day,after.hour,after.minute,after.second)
        result=bytearray(raw)
        result[1:7]=bytes(((n//10)<<4)|(n%10) for n in values)
        result[7]=(raw[7]+(after.date()-before.date()).days)%7
        return bytes(result)
    except ValueError:
        # Preserve the console's own invalid calendar registers unchanged.
        return raw


def unpack_flash(blob, capacities):
    if not blob:
        return []
    if len(blob) < 8 or len(blob) > 0x410000:
        raise ValueError('Flash size')
    magic, count, total = struct.unpack_from('<HHI', blob)
    if magic != 0x53 or total != len(blob) or count > 1024:
        raise ValueError('Flash header')
    pos, blocks, ranges = 8, [], []
    for _ in range(count):
        if pos + 8 > len(blob):
            raise ValueError('Flash header truncated')
        address, size = struct.unpack_from('<IH2x', blob, pos)
        pos += 8
        if size == 0 or pos + size > len(blob) or not any(
                base <= address and address + size <= base + cap
                for base, cap in zip((0x200000, 0x800000), capacities)):
            raise ValueError('Flash range')
        if any(address < end and start < address + size for start, end in ranges):
            raise ValueError('Overlapping flash')
        ranges.append((address, address + size))
        blocks.append((address, blob[pos:pos + size]))
        pos += size
    if pos != len(blob):
        raise ValueError('Trailing flash data')
    return blocks


def decode(raw, content, capacities):
    if len(raw) > MAX_STATE:
        raise ValueError('State too large')
    value = json.loads(raw)
    if not isinstance(value, dict) or set(value) != {'version', 'content', 'flash', 'rtc', 'battery', 'savedAt'}:
        raise ValueError('State fields')
    if value['version'] != 1 or value['content'] != content:
        raise ValueError('State belongs to another cartridge')
    if type(value['savedAt']) is not int or not 0 <= value['savedAt'] <= 0x7fffffffffffffff:
        raise ValueError('State clock')
    if any(not isinstance(value[k], str) for k in ('flash', 'rtc', 'battery')):
        raise ValueError('State encoding')
    result = {k: base64.b64decode(value[k], validate=True) for k in ('flash', 'rtc', 'battery')}
    result['savedAt'] = value['savedAt']
    if len(result['rtc']) != 16 or len(result['battery']) not in (0, 0x3000):
        raise ValueError('Console state size')
    result['blocks'] = unpack_flash(result['flash'], capacities)
    return result


def encode(content, flash, rtc, battery, saved_at=None):
    return json.dumps(dict(version=1, content=content, savedAt=int(time.time()) if saved_at is None else saved_at, **{
        k: base64.b64encode(v).decode() for k, v in
        (('flash', flash), ('rtc', rtc), ('battery', battery))}), sort_keys=True).encode()


class Store:
    def __init__(self, directory, content, capacities):
        self.root = Path(directory)
        self.root.mkdir(parents=True, exist_ok=True, mode=0o700)
        self.root.chmod(0o700)
        self.path = self.root / 'state.json'
        if self.path.is_symlink():
            raise ValueError('Linked state symlink')
        self.content, self.capacities = content, capacities
        self.raw = self.read()
        if self.raw is not None:
            decode(self.raw, content, capacities)
            backup = self.root / ('before-' + uuid.uuid4().hex + '.json')
            with backup.open('xb') as f:
                f.write(self.raw); f.flush(); os.fsync(f.fileno())

    def read(self):
        if self.path.is_symlink():raise ValueError('Linked state symlink')
        if not self.path.exists():return None
        if self.path.stat().st_size>MAX_STATE:raise ValueError('State too large')
        return self.path.read_bytes()

    def commit(self, raw):
        decode(raw, self.content, self.capacities)
        observed = self.read()
        if self.path.is_symlink() or observed != self.raw:
            raise ValueError('Your linked save changed outside this session')
        if raw == self.raw:
            return
        temporary = self.root / ('state-' + uuid.uuid4().hex + '.tmp')
        try:
            with temporary.open('xb') as f:
                f.write(raw); f.flush(); os.fsync(f.fileno())
            if temporary.read_bytes() != raw:
                raise OSError('State readback')
            os.replace(temporary, self.path)
            fd = os.open(self.root, os.O_DIRECTORY)
            try: os.fsync(fd)
            finally: os.close(fd)
            self.raw = raw
        finally:
            temporary.unlink(missing_ok=True)
