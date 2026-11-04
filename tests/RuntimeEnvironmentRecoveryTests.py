# SPDX-License-Identifier: GPL-3.0-or-later
"""Interrupted preparation must recover without accepting changed active code."""
from pathlib import Path
import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'packaging/software'))
import runtime_set as runtime
import releases as sw


class RuntimeEnvironmentRecoveryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.stage = Path(self.temp.name)
        self.python = self.stage / 'python'
        self.python.write_bytes(b'approved interpreter')
        media = self.stage / 'media/python'
        media.mkdir(parents=True)
        (media / 'test.lock').write_text('fixture==1\n')
        (media / 'interpreters.json').write_text(json.dumps({'test': {
            'pythonSha256': sw.sha256(self.python), 'requirements': ['fixture==1']}}))
        self.dest = self.stage / 'venvs/test'
        self.dest.mkdir(parents=True)
        self.ready = self.stage / 'venvs/test.json'
        self.create()
        sw.atomic(self.ready, {'files': runtime.environment_files(self.dest)})
        (self.dest / 'module.py').unlink()
        self.calls = []

    def create(self):
        (self.dest / 'bin').mkdir(exist_ok=True)
        shutil.copyfile(self.python, self.dest / 'bin/python')
        (self.dest / 'module.py').write_text('valid code')

    def run_command(self, args, **kwargs):
        self.calls.append(args)
        if args[1:3] == ['-m', 'venv']:
            self.dest.mkdir(parents=True)
            self.create()
        return subprocess.CompletedProcess(args, 0)

    def test_changed_environment_stays_rejected_without_staging_authority(self):
        with patch.object(runtime.subprocess, 'run') as run:
            with self.assertRaisesRegex(ValueError, 'environment changed: test'):
                runtime.environment(self.stage, 'test', str(self.python))
        run.assert_not_called()
        self.assertTrue(self.ready.exists())

    def test_interrupted_stage_is_rebuilt_from_pinned_offline_inputs(self):
        with patch.object(runtime.subprocess, 'run', side_effect=self.run_command):
            result = runtime.environment(self.stage, 'test', str(self.python), recover_incomplete=True)
            runtime.environment(self.stage, 'test', str(self.python), recover_incomplete=True)
        self.assertEqual(result, self.dest)
        self.assertEqual(len(self.calls), 3)
        self.assertIn('--no-index', self.calls[1])
        self.assertEqual(json.loads(self.ready.read_text())['files'], runtime.environment_files(self.dest))

    def test_failed_rebuild_has_no_ready_receipt_and_can_retry(self):
        with patch.object(runtime.subprocess, 'run', side_effect=subprocess.TimeoutExpired('venv', 120)):
            with self.assertRaises(subprocess.TimeoutExpired):
                runtime.environment(self.stage, 'test', str(self.python), recover_incomplete=True)
        self.assertFalse(self.ready.exists())
        with patch.object(runtime.subprocess, 'run', side_effect=self.run_command):
            runtime.environment(self.stage, 'test', str(self.python), recover_incomplete=True)


if __name__ == '__main__':
    unittest.main()
