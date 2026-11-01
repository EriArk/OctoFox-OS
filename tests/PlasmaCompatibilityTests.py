"""Version guards and managed removal for the bounded host library repair."""
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]


def load(path):
    spec = importlib.util.spec_from_file_location(path.stem, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


class PlasmaCompatibilityTests(unittest.TestCase):
    def test_host_update_and_damaged_artifact_use_stock_environment(self):
        wrapper = load(ROOT / 'packaging/host/pulseaudio-qt/plasmashell.py')
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder); stock = root / 'stock'; stock.write_bytes(b'host')
            library = root / 'libKF6PulseAudioQt.so.5'; library.write_bytes(b'patched')
            manifest = {'stock_sha256': hashlib.sha256(b'host').hexdigest(),
                        'patched_sha256': hashlib.sha256(b'patched').hexdigest()}
            (root / 'manifest.json').write_text(json.dumps(manifest))
            original = {'WAYLAND_DISPLAY': 'wayland-0', 'LD_PRELOAD': '/existing.so'}
            self.assertEqual(wrapper.environment(root, stock, original)['LD_PRELOAD'], str(library) + ' /existing.so')
            stock.write_bytes(b'updated host')
            self.assertEqual(wrapper.environment(root, stock, original), original)
            stock.write_bytes(b'host'); library.write_bytes(b'corrupted')
            self.assertEqual(wrapper.environment(root, stock, original), original)
            (root / 'manifest.json').unlink()
            self.assertEqual(wrapper.environment(root, stock, original), original)

    def test_payload_validation_and_owned_removal(self):
        repair = load(ROOT / 'packaging/host/pulseaudio-qt/integration.py')
        ownership = load(ROOT / 'packaging/session/ownership.py')
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder); stock = root / 'stock'; stock.write_bytes(b'host')
            artifact = root / 'library'; artifact.write_bytes(b'wrong architecture')
            with self.assertRaisesRegex(ValueError, 'reviewed'):
                repair.files(artifact, stock)
            with patch.object(repair, 'STOCK_SHA256', hashlib.sha256(b'host').hexdigest()):
                with self.assertRaisesRegex(ValueError, 'aarch64'):
                    repair.files(artifact, stock)
                artifact.write_bytes(b'\x7fELF\x02\x01' + b'\0' * 12 + b'\xb7\x00' + b'fixture')
                payload = repair.files(artifact, stock)
            owned = ownership.Ownership(root / 'journal', 'fixture', root)
            for name, data, mode in payload:
                path = owned.target(name); path.parent.mkdir(parents=True, exist_ok=True)
                owned.preparing(name, data); path.write_bytes(data)
            changed = owned.target(repair.DROPIN); changed.write_bytes(b'user edit')
            with self.assertRaises(ValueError):
                owned.uninstall()
            self.assertTrue(all(owned.target(name).exists() for name, _, _ in payload))
            changed.write_bytes(payload[-1][1]); owned.uninstall()
            self.assertTrue(all(not owned.target(name).exists() for name, _, _ in payload))


if __name__ == '__main__':
    unittest.main()
