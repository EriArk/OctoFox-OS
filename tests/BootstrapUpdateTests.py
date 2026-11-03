import hashlib
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]/'packaging/software'))
import bootstrap_update as update
import releases as sw


@unittest.skipUnless(sys.platform == 'linux', 'Atomic Linux directory exchange')
class BootstrapUpdateTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)/'owned'; self.root.mkdir(mode=0o700)
        self.source = Path(self.temp.name)/'source'; self.source.mkdir()
        self.name = 'software/launcher.py'
        self.old_file = self.root/'bootstrap/packaging'/self.name
        self.old_file.parent.mkdir(parents=True); self.old_file.write_bytes(b'old launcher')
        self.new_file = self.source/self.name
        self.new_file.parent.mkdir(parents=True); self.new_file.write_bytes(b'new launcher')
        self.old = {self.name: sw.sha256(self.old_file)}
        self.new = {self.name: sw.sha256(self.new_file)}
        sw.atomic(self.root/'bootstrap-files.json', self.old)
        (self.root/'trusted-key.pem').write_bytes(b'unchanged key')

    def run_update(self, **kwargs):
        return update.replace(self.root, self.source, [self.new_file], self.new, lambda: True, **kwargs)

    def assert_complete(self):
        update.verify(self.root/'bootstrap', self.new)
        self.assertEqual(sw.decode((self.root/'bootstrap-files.json').read_bytes()), self.new)
        self.assertFalse((self.root/'bootstrap-update.json').exists())
        backups = list((self.root/'bootstrap-updates').glob('*/tree'))
        self.assertEqual(len(backups), 1); update.verify(backups[0], self.old)
        self.assertEqual((self.root/'trusted-key.pem').read_bytes(), b'unchanged key')

    def test_update_keeps_complete_previous_bootstrap_and_trust(self):
        self.assertTrue(self.run_update()); self.assert_complete()

    def test_cancel_does_not_write(self):
        self.assertFalse(update.replace(self.root, self.source, [self.new_file], self.new, lambda: False))
        update.verify(self.root/'bootstrap', self.old)
        self.assertFalse((self.root/'bootstrap-updates').exists())

    def test_interruption_before_exchange(self): self.interrupted('prepared')
    def test_interruption_after_exchange(self): self.interrupted('exchanged')
    def test_interruption_after_receipt(self): self.interrupted('recorded')

    def interrupted(self, phase):
        def stop(current):
            if current == phase: raise RuntimeError('interrupted')
        with self.assertRaisesRegex(RuntimeError, 'interrupted'): self.run_update(checkpoint=stop)
        update.verify(self.root/'bootstrap', self.old if phase == 'prepared' else self.new)
        self.run_update(); self.assert_complete()

    def test_modified_owned_file_is_not_overwritten(self):
        self.old_file.write_bytes(b'user modification')
        with self.assertRaisesRegex(ValueError, 'modified'): self.run_update()
        self.assertEqual(self.old_file.read_bytes(), b'user modification')
        self.assertFalse((self.root/'bootstrap-update.json').exists())

    def test_busy_runtime_and_pending_install_are_not_modified(self):
        with sw.cache_lock(self.root/'runtime'):
            with self.assertRaises((ValueError, RuntimeError, OSError)): self.run_update()
        sw.atomic(self.root/'setup-pending.json', {'action':'install'})
        with self.assertRaisesRegex(ValueError, 'interrupted installation'): self.run_update()
        update.verify(self.root/'bootstrap', self.old)

    def test_failed_exchange_keeps_old_tree_and_can_resume(self):
        with patch.object(update, 'exchange', side_effect=OSError('unsupported')):
            with self.assertRaisesRegex(OSError, 'unsupported'): self.run_update()
        update.verify(self.root/'bootstrap', self.old)
        self.run_update(); self.assert_complete()


if __name__ == '__main__': unittest.main()
