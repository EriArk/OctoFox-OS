"""Optional, version-bounded Plasma repair payload for the session installer."""
import hashlib
import json
from pathlib import Path

STOCK_SHA256 = '44f26f2756392f174123ab04e2f7305d23bc5187ef31ff0fea3009e78dc2a489'
ROOT = '/var/opt/traineros/host/pulseaudio-qt/'
DROPIN = '/etc/systemd/user/plasma-plasmashell.service.d/50-traineros-audio-teardown.conf'


def files(library, stock=Path('/usr/lib64/libKF6PulseAudioQt.so.5')):
    if hashlib.sha256(stock.read_bytes()).hexdigest() != STOCK_SHA256:
        raise ValueError('PulseAudioQt repair is only reviewed for Fedora 44 aarch64 1.8.1-1')
    data = Path(library).read_bytes()
    if data[:6] != b'\x7fELF\x02\x01' or data[18:20] != b'\xb7\x00':
        raise ValueError('Expected the reviewed aarch64 shared-library build')
    manifest = {'stock_sha256': STOCK_SHA256, 'patched_sha256': hashlib.sha256(data).hexdigest(),
                'upstream': '10786fe31e640858f4f5db5366aed9c56d77bfab', 'repair': 'shutdown-v1'}
    source = Path(__file__).parent
    return [(ROOT + 'libKF6PulseAudioQt.so.5', data, 0o644),
            (ROOT + 'manifest.json', (json.dumps(manifest, indent=2) + '\n').encode(), 0o644),
            (ROOT + 'plasmashell.py', (source / 'plasmashell.py').read_bytes().replace(b'\r\n', b'\n'), 0o755),
            (DROPIN, (source / 'plasmashell.conf').read_bytes().replace(b'\r\n', b'\n'), 0o644)]
