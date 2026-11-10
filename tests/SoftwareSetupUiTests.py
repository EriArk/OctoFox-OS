"""Setup completion and failure boundaries; isolated files/processes, no real install."""
import contextlib
import io
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'packaging/software'))
import installer


class SetupUiTests(unittest.TestCase):
    def tearDown(self):
        installer.Progress.failed = None

    def test_storage_authorization_waits_for_user_and_checks_result(self):
        from unittest.mock import MagicMock
        guard = MagicMock(); guard.needed.side_effect = [True, False]
        with patch.object(installer.importlib.util, 'module_from_spec', return_value=guard), \
             patch.object(installer.importlib.util, 'spec_from_file_location') as spec, \
             patch.object(installer.subprocess, 'run') as run:
            installer.protect_storage(Path('/fixture'))
            self.assertEqual(run.call_args.args[0][0], 'pkexec')
            self.assertNotIn('timeout', run.call_args.kwargs)
            self.assertEqual(guard.needed.call_count, 2)

    def test_success_switches_directly_and_handoff_failure_is_distinct(self):
        with patch.object(installer, 'dialog') as dialog, patch.object(installer.subprocess, 'run') as run:
            self.assertEqual(installer.complete_gui({'status': 'installed'}), 0)
            dialog.assert_not_called()
            self.assertEqual(run.call_args.args[0][-2:], ['/var/opt/traineros/session/control.py', 'traineros'])
            self.assertTrue(run.call_args.kwargs['check'])
            run.side_effect = subprocess.CalledProcessError(1, ['fixture'])
            with self.assertRaisesRegex(RuntimeError, 'installed, but switching'):
                installer.complete_gui({'status': 'installed'})

    def test_noninstallation_results_do_not_launch(self):
        with patch.object(installer, 'dialog'), patch.object(installer.subprocess, 'run') as run:
            for status in ('removed', 'rolled-back', 'cache-cleaned'):
                installer.complete_gui({'status': status})
            run.assert_not_called()

    def test_failure_keeps_progress_until_error_is_acknowledged(self):
        progress = installer.Progress(); progress.phase = 'Preparing KDE'; error = ValueError('failed <download>')
        with patch.object(progress, 'call', return_value=subprocess.CompletedProcess([], 0, '')) as call:
            progress.__exit__(ValueError, error, None)
            self.assertNotIn(('close',), [c.args for c in call.call_args_list])
            label = next(c.args[1] for c in call.call_args_list if c.args[0] == 'setLabelText')
            self.assertIn('Preparing KDE', label); self.assertIn('&lt;download&gt;', label)
            with patch.object(installer, 'dialog', side_effect=OSError('display unavailable')), contextlib.redirect_stderr(io.StringIO()):
                self.assertTrue(installer.show_error(error))
            self.assertNotIn(('close',), [c.args for c in call.call_args_list])
            with patch.object(installer, 'dialog', return_value=subprocess.CompletedProcess([], 0)), contextlib.redirect_stderr(io.StringIO()):
                self.assertTrue(installer.show_error(error))
            self.assertEqual(call.call_args.args, ('close',))

    def test_user_cancel_and_success_close_progress(self):
        for error in (None, installer.Cancelled('cancelled')):
            progress = installer.Progress()
            with patch.object(progress, 'close') as close:
                progress.__exit__(type(error), error, None)
                close.assert_called_once()
            self.assertIsNone(installer.Progress.failed)

    def test_unexpected_worker_exception_reaches_error_reporting(self):
        error = ZeroDivisionError('unexpected fixture bug')
        with patch.object(sys, 'argv', ['installer.py', '--gui', '--worker']), \
             patch.object(installer.os, 'getuid', return_value=1000), \
             patch.object(installer, 'gui', side_effect=error), \
             patch.object(installer, 'show_error', return_value=False) as report, \
             contextlib.redirect_stderr(io.StringIO()) as stderr:
            self.assertEqual(installer.main(), 1)
        self.assertIs(report.call_args.args[0], error)
        self.assertIn('ZeroDivisionError', stderr.getvalue())

    def test_parent_retains_log_and_reports_unhandled_exit_or_signal(self):
        for code, message in [(7, 'exit 7'), (-9, 'signal 9')]:
            with self.subTest(code=code), tempfile.TemporaryDirectory() as folder:
                script = "import os,sys;print('fixture diagnostic',flush=True);" + (
                    'os.kill(os.getpid(),9)' if code < 0 else 'sys.exit(7)')
                with patch.dict(os.environ, XDG_STATE_HOME=folder), patch.object(installer, 'show_error') as report:
                    self.assertEqual(installer.supervise([sys.executable, '-c', script]), max(code, 1))
                self.assertIn(message, report.call_args.args[0])
                log = Path(report.call_args.args[1])
                self.assertIn('fixture diagnostic', log.read_text())
                self.assertEqual(log.stat().st_mode & 0o777, 0o600)

    def test_parent_does_not_repeat_acknowledged_error_or_report_success(self):
        for script in ["print('success')", "import os,sys;os.write(int(os.environ['TRAINEROS_SETUP_ERROR_FD']),b'shown');sys.exit(1)"]:
            with tempfile.TemporaryDirectory() as folder, patch.dict(os.environ, XDG_STATE_HOME=folder), \
                 patch.object(installer, 'show_error') as report:
                installer.supervise([sys.executable, '-c', script])
                report.assert_not_called()


if __name__ == '__main__':
    unittest.main()
