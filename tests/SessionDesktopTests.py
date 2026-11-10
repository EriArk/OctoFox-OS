"""Desktop handoff regressions; temporary files and fake D-Bus only."""
import copy
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock, patch

ROOT = Path(__file__).resolve().parents[1]


def module(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'packaging/session' / (name + '.py'))
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


class DesktopLogoutTests(unittest.TestCase):
    def test_activatable_kde_shutdown_is_not_a_live_desktop(self):
        helper = module('desktop-logout')
        bus = Mock(); bus.name_has_owner.return_value = False
        request = Mock()
        with patch.object(helper.subprocess, 'call') as execute:
            self.assertEqual(helper.logout(bus, request), 10)
        request.assert_not_called(); execute.assert_not_called()

    def test_standalone_logout_and_service_gate(self):
        helper = module('desktop-logout')
        bus = Mock(); bus.name_has_owner.return_value = True
        for service_result in (0, 3):
            request = Mock()
            with patch.object(helper.subprocess, 'call', return_value=service_result):
                self.assertEqual(helper.logout(bus, request), 0 if service_result == 0 else 10)
            self.assertEqual(request.call_count, int(service_result == 0))

    def test_accepted_or_failed_logout_never_forces_sddm(self):
        helper = module('control')
        for result in (0, 1, 10):
            with self.subTest(result=result), tempfile.TemporaryDirectory() as folder:
                helper.OVERRIDE = Path(folder) / 'autologin'
                helper.MARKER = Path(folder) / 'marker'
                with patch.object(helper.os, 'geteuid', return_value=0), \
                     patch.object(helper.sys, 'argv', ['control.py', 'traineros']), \
                     patch.object(helper.Path, 'is_file', return_value=True), \
                     patch.dict(os.environ, SUDO_UID='1000'), \
                     patch.object(helper, 'session_pids', return_value=[]), \
                     patch.object(helper, 'logout_desktop', return_value=result) as logout, \
                     patch.object(helper.subprocess, 'call', return_value=0) as execute:
                    self.assertEqual(helper.main(), 1 if result == 1 else 0)
                    logout.assert_called_once_with('1000')
                    self.assertEqual(execute.call_count, int(result == 10))
                    if result == 10:
                        execute.assert_called_once_with(['/usr/bin/systemctl', '--no-block', 'restart', 'sddm'])


class GracefulTransitionTests(unittest.TestCase):
    def test_only_same_user_standalone_shell_gets_normal_exit(self):
        helper = module('control')
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder); parent = root/'10'; parent.mkdir()
            (parent/'status').write_text('Name:\tsudo\nPPid:\t11\nUid:\t0 0 0 0\n')
            (parent/'cgroup').write_text('0::/user.slice/traineros-session.service\n')
            shell = root/'11'; shell.mkdir()
            (shell/'status').write_text('Name:\ttraineros\nPPid:\t1\nUid:\t1000 1000 1000 1000\n')
            (shell/'cgroup').write_text('0::/user.slice/traineros-session.service\n')
            self.assertTrue(helper.from_standalone_shell('1000', root, 10))
            self.assertFalse(helper.from_standalone_shell('1001', root, 10))
            (shell/'cgroup').write_text('0::/app.slice/desktop.scope\n')
            self.assertFalse(helper.from_standalone_shell('1000', root, 10))

    def test_ui_handoff_selects_destination_without_killing_launcher(self):
        helper = module('control')
        for graceful in (False, True):
            for mode in ('desktop', 'steam'):
                with tempfile.TemporaryDirectory() as folder:
                    helper.MARKER = Path(folder)/'transition'
                    with patch.object(helper.os, 'geteuid', return_value=0), \
                         patch.object(helper.sys, 'argv', ['control.py', mode]), \
                         patch.dict(os.environ, SUDO_UID='1000'), \
                         patch.object(helper, 'session_pids', return_value=[42]), \
                         patch.object(helper, 'from_standalone_shell', return_value=graceful), \
                         patch.object(helper.subprocess, 'call', return_value=0) as execute:
                        self.assertEqual(helper.main(), 0)
                        self.assertEqual(execute.call_count, 1 if graceful else 2)
                        self.assertEqual(execute.call_args_list[0].args[0][-1],
                                         'default-desktop' if mode == 'desktop' else 'default-gamemode')
                        self.assertEqual(json.loads(helper.MARKER.read_text())['pids'], [42])


class ManagedBootTests(unittest.TestCase):
    def test_literal_system_install_targets_can_be_owned_and_removed(self):
        # Exercise the real installer destinations against the ownership policy.
        # A missing allowlist entry previously rejected the entire clean install
        # only after Software and runtimes had already been committed.
        import ast
        ownership = module('ownership')
        tree = ast.parse((ROOT/'packaging/session/install.py').read_text())
        names = {node.args[0].value for node in ast.walk(tree)
                 if isinstance(node, ast.Call) and isinstance(node.func, ast.Name)
                 and node.func.id == 'install' and node.args
                 and isinstance(node.args[0], ast.Constant)
                 and isinstance(node.args[0].value, str)
                 and node.args[0].value.startswith('/etc/')}
        self.assertIn('/etc/systemd/system/armada-session-default.service.d/traineros-storage.conf', names)
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            owner = ownership.Ownership(root/'journal.json', 'fixture', root)
            for name in names:
                path = owner.check(name); path.parent.mkdir(parents=True, exist_ok=True)
                owner.preparing(name, b'owned'); path.write_bytes(b'owned')
            with self.assertRaises(ValueError):
                owner.check('/etc/systemd/system/armada-session-default.service.d/unrelated.conf')
            owner.uninstall()
            self.assertTrue(all(not owner.target(name).exists() for name in names))

    def test_removal_restores_desktop_only_for_our_active_session(self):
        helper = module('install'); ownership = module('ownership')
        for selected in ('traineros.desktop', 'plasma.desktop', 'gamescope-session.desktop'):
            with self.subTest(selected=selected), tempfile.TemporaryDirectory() as folder:
                root = Path(folder); owner = ownership.Ownership(root/'journal.json', 'fixture', root)
                path = owner.target(helper.BOOT_DEFAULT); path.parent.mkdir(parents=True)
                owner.preparing(helper.BOOT_DEFAULT, b'owned'); path.write_bytes(b'owned')
                override = root/'autologin'; override.write_text('[Autologin]\nSession='+selected+'\n')
                choose = Mock(); helper.prepare_uninstall(owner, override, choose)
                self.assertEqual(choose.call_count, int(selected == 'traineros.desktop'))
                owner.uninstall(); self.assertFalse(path.exists())

    def test_modified_or_unowned_default_refuses_before_switch(self):
        helper = module('install'); ownership = module('ownership')
        for known in (False, True):
            with tempfile.TemporaryDirectory() as folder:
                root = Path(folder); owner = ownership.Ownership(root/'journal.json', 'fixture', root)
                path = owner.target(helper.BOOT_DEFAULT); path.parent.mkdir(parents=True)
                if known: owner.preparing(helper.BOOT_DEFAULT, b'owned')
                path.write_bytes(b'user changed')
                override = root/'autologin'; override.write_text('Session=traineros.desktop')
                choose = Mock()
                with self.assertRaises(ValueError): helper.prepare_uninstall(owner, override, choose)
                choose.assert_not_called(); self.assertEqual(path.read_bytes(), b'user changed')


class BrightnessTests(unittest.TestCase):
    def setUp(self):
        self.helper = module('plasma-brightness')
        self.tmp = tempfile.TemporaryDirectory(); self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.path = self.root / 'kwinoutputconfig.json'
        self.config = [{'name': 'outputs', 'data': [
            {'connectorName': 'DSI-1', 'brightness': .33, 'scale': 2, 'transform': 'Rotated90',
             'automaticBrightness': False, 'highDynamicRange': False, 'uuid': 'panel'},
            {'connectorName': 'HDMI-A-1', 'brightness': .4, 'uuid': 'tv'}]},
            {'name': 'setups', 'data': [{'lidClosed': False, 'outputs': [{'outputIndex': 0}]}]}]
        self.path.write_text(json.dumps(self.config))

    def test_handoff_changes_only_identified_panel_and_keeps_first_backup(self):
        before = self.path.read_bytes()
        self.assertTrue(self.helper.sync(self.path, ('DSI-1', 190 / 254)))
        expected = copy.deepcopy(self.config); expected[0]['data'][0]['brightness'] = 190 / 254
        self.assertEqual(json.loads(self.path.read_bytes()), expected)
        self.assertTrue(self.helper.sync(self.path, ('DSI-1', .6)))
        self.assertEqual(self.path.with_name(self.path.name + '.before-traineros-brightness').read_bytes(), before)

    def test_automatic_hdr_ambiguous_and_unknown_configs_are_preserved(self):
        for kind in ('automaticBrightness', 'highDynamicRange', 'ambiguous', 'unknown'):
            with self.subTest(kind=kind):
                config = copy.deepcopy(self.config)
                if kind in ('automaticBrightness', 'highDynamicRange'):
                    config[0]['data'][0][kind] = True
                elif kind == 'ambiguous':
                    config[0]['data'].append(copy.deepcopy(config[0]['data'][0]))
                else:
                    config = {'future-format': config}
                self.path.write_text(json.dumps(config)); before = self.path.read_bytes()
                self.assertFalse(self.helper.sync(self.path, ('DSI-1', .75)))
                self.assertEqual(self.path.read_bytes(), before)

    def test_redirected_file_is_preserved(self):
        target = self.root / 'user-config'; self.path.rename(target); self.path.symlink_to(target)
        before = target.read_bytes()
        self.assertFalse(self.helper.sync(self.path, ('DSI-1', .75)))
        self.assertEqual(target.read_bytes(), before)

    def test_panel_identity_raw_range_and_blank_state(self):
        light = self.root / 'backlight/panel'; light.mkdir(parents=True)
        (light / 'max_brightness').write_text('255'); (light / 'brightness').write_text('191')
        connector = self.root / 'drm/card1-DSI-1'; connector.mkdir(parents=True)
        (connector / 'status').write_text('connected')
        read = lambda: self.helper.panel_value(light.parent, connector.parent)
        self.assertEqual(read(), ('DSI-1', 190 / 254))
        (light / 'brightness').write_text('0'); self.assertIsNone(read())
        (light / 'brightness').write_text('256'); self.assertIsNone(read())
        (light / 'brightness').write_text('191')
        (light.parent / 'other').mkdir(); self.assertIsNone(read())


if __name__ == '__main__':
    unittest.main()
