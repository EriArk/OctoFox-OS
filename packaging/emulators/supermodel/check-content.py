#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
import importlib.util
import os
from pathlib import Path
import tempfile
import subprocess
import sys
import time
import unittest
from unittest.mock import patch
from types import SimpleNamespace

spec = importlib.util.spec_from_file_location('model3_content', Path(__file__).with_name('content.py'))
content = importlib.util.module_from_spec(spec); spec.loader.exec_module(content)


class ContentTests(unittest.TestCase):
    @unittest.skipUnless(sys.platform.startswith('linux'), 'Linux native process lifetime')
    def test_cancelled_scan_cannot_leave_native_reader_running(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); (root/'bin').mkdir(); archive = root/'fixture.zip'; archive.write_bytes(b'fixture')
            launcher = root/'bin/supermodel'
            launcher.write_text('#!/usr/bin/python3\nimport os,sys,time\nfrom pathlib import Path\n'
                                'Path(sys.argv[-1]+".pid").write_text(str(os.getpid()))\ntime.sleep(60)\n')
            launcher.chmod(0o755); identity = Path(str(archive)+'.pid'); pid = None
            helper = subprocess.Popen([sys.executable, str(Path(content.__file__)), 'identity', str(root), str(archive)],
                                      stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            def running():
                try: return Path('/proc', str(pid), 'stat').read_text().split(') ')[1][0] != 'Z'
                except FileNotFoundError: return False
            try:
                deadline = time.monotonic()+5
                while not identity.exists() and helper.poll() is None and time.monotonic()<deadline: time.sleep(.02)
                self.assertTrue(identity.exists()); pid = int(identity.read_text())
                helper.kill(); helper.wait(timeout=5)
                deadline = time.monotonic()+5
                while running() and time.monotonic()<deadline: time.sleep(.02)
                self.assertFalse(running(), 'Cancelled native reader survived its owner')
            finally:
                if helper.poll() is None: helper.kill(); helper.wait(timeout=5)
                if pid and running(): os.kill(pid, 9)

    def test_native_identity_not_filename_and_parent_dependency(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); archive = root/'arbitrary title.zip'; archive.write_bytes(b'own set')
            result = SimpleNamespace(stdout=b'[TrainerOSModel3] {"name":"native_set","parent":"native_parent","link":true}\n')
            with patch.object(content.subprocess, 'run', return_value=result) as native:
                first = content.identity(root, archive)
                self.assertEqual(first['name'], 'native_set')
                self.assertIn(str(archive), native.call_args.args[0])
                self.assertEqual(native.call_args.kwargs['env']['TRAINEROS_SUPERMODEL_INSPECT'], '1')
                parent = root/'native_parent.zip'; parent.write_bytes(b'own parent')
                self.assertNotEqual(content.identity(root, archive)['content'], first['content'])
                result.stdout = result.stdout.replace(b'true', b'false')
                with self.assertRaises(ValueError): content.identity(root, archive)
                result.stdout = b'not a native identification'
                with self.assertRaises(ValueError): content.identity(root, archive)

    def test_own_settings_seed_once_and_cabinet_progress_persists(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); bundle = root/'bundle'; (bundle/'Config').mkdir(parents=True)
            (bundle/'Config/Supermodel.ini').write_bytes(b'packaged controls')
            config = root/'own.ini'; config.write_bytes(b'own preferences')
            nvram = root/'nvram'; nvram.mkdir(); original = nvram/'native_set.nv'; original.write_bytes(b'own progress')
            for seat in (1, 2, 3, 4):
                stage = root/('seat'+str(seat))
                content.prepare(bundle, stage, config, nvram, 'native_set')
                self.assertEqual((stage/'Config/Supermodel.ini').read_bytes(), b'own preferences')
                saved = stage/'NVRAM/native_set.nv'
                self.assertEqual(saved.read_bytes(), b'own progress')
                saved.write_bytes(b'cabinet identity and progress')
                content.prepare(bundle, stage, config, nvram, 'native_set')
                self.assertEqual(saved.read_bytes(), b'cabinet identity and progress')
                self.assertEqual(original.read_bytes(), b'own progress')
                self.assertEqual(config.read_bytes(), b'own preferences')
            config.unlink(); stage = root/'new-seat'
            content.prepare(bundle, stage, config, nvram, 'native_set')
            self.assertEqual((stage/'Config/Supermodel.ini').read_bytes(), b'packaged controls')

    def test_refuses_symlink_write_targets(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); bundle = root/'bundle'; (bundle/'Config').mkdir(parents=True)
            (bundle/'Config/Supermodel.ini').write_bytes(b'default')
            stage = root/'seat'; stage.mkdir(); target = root/'protected'; target.mkdir()
            (stage/'NVRAM').symlink_to(target, target_is_directory=True)
            with self.assertRaises(ValueError): content.prepare(bundle, stage, root/'absent', root/'absent', 'native_set')
            self.assertEqual(list(target.iterdir()), [])


if __name__ == '__main__': unittest.main()
