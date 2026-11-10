#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Armada desktop installer/recovery entry; downloads from the pinned bootstrap."""
import argparse
import hashlib
import importlib.util
import time
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import shlex
import tarfile
import installation as install
import releases as sw
import runtime_set as runtimes
import runtime_manager

CRATES_FILES = ('catalogue.py', 'catalogue-key.pem', 'installer.py', 'launch.py', 'packages.json')
SESSION_FILES = ('armada-session-default.conf', 'client.py', 'compositor.sh', 'control.py',
                 'desktop-entry.py', 'desktop-logout.py', 'install.py', 'ownership.py',
                 'org.traineros.Session.desktop', 'plasma-brightness.conf',
                 'plasma-brightness.py', 'start-session.sh', 'traineros-session.service',
                 'traineros.desktop')


def atomic_file(path, data, mode):
    path = Path(path); install.private(path.parent)
    if path.is_symlink(): raise ValueError('Refusing a redirected launcher')
    fd, temporary = tempfile.mkstemp(dir=path.parent)
    try:
        with os.fdopen(fd, 'wb') as stream:
            stream.write(data); stream.flush(); os.fsync(stream.fileno())
        os.chmod(temporary, mode); os.replace(temporary, path)
    finally:
        if os.path.exists(temporary): os.unlink(temporary)


def shortcut_contents(root, home=None):
    root, home = Path(root), Path(home or Path.home())
    helper = root / 'bootstrap/packaging/software'
    def quoted(value): return '"' + str(value).replace('\\', '\\\\').replace('"', '\\"').replace('%', '%%') + '"'
    launch = ('#!/bin/sh\nexec /usr/bin/python3 ' + shlex.quote(str(helper / 'launcher.py')) +
              ' --root ' + shlex.quote(str(root)) + ' "$@"\n').encode()
    def desktop(name, entry, extra=''):
        return ('[Desktop Entry]\nType=Application\nName=' + name + '\nExec=/usr/bin/python3 ' + quoted(helper / entry) +
                ' --root ' + quoted(root) + extra + '\nIcon=applications-games\nTerminal=false\nCategories=Game;\n').encode()
    return {home / '.local/bin/traineros': (launch, 0o755),
            home / '.local/share/applications/org.traineros.TrainerOS.desktop': (desktop('TrainerOS', 'launcher.py'), 0o644),
            home / '.local/share/applications/org.traineros.Recovery.desktop': (desktop('TrainerOS Setup and Recovery', 'installer.py', ' --gui'), 0o644)}


def shortcuts(root, home=None, preflight=False):
    previous = {r['path']: r['sha256'] for r in install.read(Path(root) / 'shortcuts.json', [])}
    contents = shortcut_contents(root, home)
    for path in contents:
        if path.is_symlink() or path.exists() and (str(path) not in previous or sw.sha256(path) != previous[str(path)]):
            raise ValueError('Existing unmanaged launcher requires explicit migration: ' + str(path))
    if preflight: return
    records = [{'path': str(p), 'sha256': hashlib.sha256(data).hexdigest()} for p, (data, _) in contents.items()]
    # Write ownership before creating files: interruption remains reinstallable.
    sw.atomic(Path(root) / 'shortcuts.json', records)
    for path, (data, mode) in contents.items(): atomic_file(path, data, mode)


def bootstrap(root, source, confirm_update=None):
    root, source = Path(root), Path(source)
    destination = root / 'bootstrap'
    wanted = [*source.joinpath('software').glob('*.py'), *source.joinpath('session').glob('*'),
              *source.joinpath('integrations').glob('*.py'),
              *(source / 'pc' / name for name in ('launch.py', 'steam.py', 'runtimes.py')),
              *(source / 'crates' / name for name in CRATES_FILES)]
    # These are consumed by session/install.py, including on a fresh machine.
    # A developer checkout can mask an incomplete Setup archive.
    for name in ('software/launcher.py', *('session/' + name for name in SESSION_FILES), 'integrations/emulator_support.py',
                 'pc/launch.py', 'pc/steam.py', 'pc/runtimes.py',
                 'integrations/install-radio-control.py', 'integrations/radio-control.py',
                 'integrations/network-control.py', 'integrations/nearby-control.py',
                 'integrations/nearby-bluetooth.py',
                 *('crates/' + name for name in CRATES_FILES)):
        path = source / name
        if path.is_symlink() or not path.is_file():
            raise ValueError('Incomplete Setup: missing ' + name)
    files = [p for p in wanted if p.is_file() and not p.is_symlink()]
    records = {p.relative_to(source).as_posix(): sw.sha256(p) for p in files}
    if destination.exists():
        old = install.read(root / 'bootstrap-files.json')
        if old != records or (root/'bootstrap-update.json').exists():
            import bootstrap_update
            return bootstrap_update.replace(root, source, files, records, confirm_update)
        for name, digest in records.items():
            path = destination / 'packaging' / name
            if path.is_symlink() or not path.is_file() or sw.sha256(path) != digest: raise ValueError('Bootstrap was modified')
        return True
    with tempfile.TemporaryDirectory(dir=root, prefix='.bootstrap-') as tmp:
        stage = Path(tmp) / 'tree'; stage.mkdir()
        for path in files:
            target = stage / 'packaging' / path.relative_to(source)
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(path, target); target.chmod(0o755 if path.suffix in ('.py', '.sh') else 0o644)
        sw.atomic(root / 'bootstrap-files.json', records)
        os.replace(stage, destination)
    return True


def integrate(root, remove=False):
    import pwd
    root = Path(root)
    # pkexec authenticates this one reviewed installation operation. No new broad
    # permanent root command or package-manager permission is granted.
    helper = root / 'bootstrap/packaging/session/install.py'
    for name, digest in install.read(root / 'bootstrap-files.json').items():
        path = root / 'bootstrap/packaging' / name
        if path.is_symlink() or sw.sha256(path) != digest: raise ValueError('Bootstrap integrity check failed')
    configured = install.read(root / 'integration.json', {}).get('bootDefaultConfigured', False)
    command = ['pkexec', '/usr/bin/python3', '-I', str(helper), '--user', pwd.getpwuid(os.getuid()).pw_name,
               '--uninstall' if remove else '--managed']
    if not remove and not configured: command.append('--default')
    subprocess.run(command, check=True)
    sw.atomic(root / 'integration.json', {'systemInstalled': not remove, 'bootDefaultConfigured': not remove})


def dialog(*args):
    return subprocess.run(['kdialog', '--title', 'TrainerOS Setup', *args], capture_output=True, text=True)


class Cancelled(RuntimeError):
    pass


class Progress:
    def __enter__(self):
        self.dbus = shutil.which('qdbus6') or shutil.which('qdbus-qt6') or shutil.which('qdbus')
        if not self.dbus: raise ValueError('The Armada KDE qdbus utility is required for progress and cancellation')
        result = dialog('--progressbar', 'Preparing TrainerOS...', '100')
        self.ref = result.stdout.strip().split(); self.last = 0; self.phase = ''
        if result.returncode or len(self.ref) != 2: raise ValueError('Could not open installation progress')
        self.call('setAutoClose', 'false'); self.call('showCancelButton', 'true')
        return self
    def call(self, *args):
        return subprocess.run([self.dbus, *self.ref, *args], capture_output=True, text=True, timeout=5)
    def update(self, phase, done=0, total=0):
        sw.event(phase, done, total)
        # Avoid a DBus process for each download buffer. Losing the progress
        # window is treated like Cancel, including KDE versions that destroy it.
        now = time.monotonic()
        if phase == self.phase and now - self.last < .25: return
        self.last = now; self.phase = phase
        state = self.call('wasCancelled')
        if state.returncode or state.stdout.strip() == 'true': raise Cancelled('Download cancelled. Reopen Setup to resume.')
        self.call('setLabelText', {'download': 'Downloading TrainerOS', 'extract': 'Preparing verified files',
                                 'verify-archive': 'Verifying download', 'prepared': 'Download verified'}.get(phase, phase))
        self.call('Set', '', 'maximum', '100' if total else '0')
        self.call('Set', '', 'value', str(int(done * 100 / total) if total else 0))
    def __exit__(self, *unused):
        try: self.call('close')
        except (OSError, subprocess.SubprocessError): pass


def prerequisites(source):
    for binary in ('/usr/bin/python3', '/usr/bin/pkexec', '/usr/sbin/visudo', '/usr/bin/ldd'):
        if not os.access(binary, os.X_OK): raise ValueError('Missing Armada installer dependency: ' + binary)
    spec = importlib.util.spec_from_file_location('emulator_support', Path(source) / 'integrations/emulator_support.py')
    support = importlib.util.module_from_spec(spec); spec.loader.exec_module(support)
    support.prerequisites()


def payload_dependencies(prepared):
    payload = Path(prepared) / 'payload'
    env = dict(os.environ)
    if (payload / 'lib').is_dir(): env['LD_LIBRARY_PATH'] = str(payload / 'lib')
    result = subprocess.run(['/usr/bin/ldd', str(payload / 'bin/traineros')], env=env, capture_output=True, text=True, timeout=30)
    if result.returncode or 'not found' in result.stdout:
        raise ValueError('The signed TrainerOS build needs unavailable system libraries. Use a matching Armada build; installation was not activated.')


def resolve_offline(root, media, prepare=False, progress=sw.event, allow_current=False):
    root, media = Path(root), Path(media)
    release = sw.verified(media / 'release.json', root / 'trusted-key.pem')['signed']
    config = install.configuration(root)
    install.host.compatible(release, install.host.schemas(config['dataDirectory']))
    current = install.receipt(root)
    if current['active']:
        previous=install.version(root,current['active'])
        if release['sequence']<=previous['sequence'] and not (allow_current and release==previous):
            raise ValueError('Offline media is not newer than the installed release; use Recovery for rollback')
    result = {'status': 'available', 'version': release['version'], 'sequence': release['sequence'], 'downloadBytes': 0}
    if prepare:
        path = sw.prepare(media / 'release.json', root / 'trusted-key.pem', root / 'cache',
                          progress=progress, archive_path=media / 'traineros.tar.gz')
        result.update(status='prepared', prepared=str(path))
    return result


def recover_full(root, source):
    choice=dialog('--menu','An interrupted full installation must be recovered before launching TrainerOS.',
                  'resume','Continue installation','undo','Restore the previous installation')
    if choice.returncode: return 0
    with sw.cache_lock(root/'runtime'),sw.cache_lock(root/'transaction'):
        install.ensure_no_orphans(root); runtimes.idle()
        with Progress() as progress:
            progress.call('showCancelButton','false')
            result=runtime_manager.apply(root,reverse=choice.stdout.strip()=='undo',checkpoint=lambda phase:progress.update('Recovering '+phase))
            if result['status']=='installed':
                prerequisites(source);result=finish_setup(root,'install')
            elif result['status']=='runtimes-removed':
                result=finish_setup(root,'uninstall')
            else:(root/'setup-pending.json').unlink(missing_ok=True)
    dialog('--msgbox',result['status']); return 0


def finish_setup(root, action):
    job=install.read(root/'setup-pending.json',{'action':action})
    if job['action']!=action:raise ValueError('Conflicting Setup recovery operation')
    sw.atomic(root/'setup-pending.json',job)
    if action=='install':
        if job.get('prepared') and install.receipt(root)['active']!=job['expected']:
            payload_dependencies(job['prepared']);install.install_prepared(root,job['prepared'])
        install.version(root,install.receipt(root)['active'])
        if job.get('channel'):install.select_channel(root,job['channel'])
        shortcuts(root);integrate(root)
        result={'status':'installed'}
    elif action=='uninstall':
        install.uninstall(root,preflight=True)
        if runtime_manager.receipt(root)['active']:
            runtimes.idle();plan=runtime_manager.plan(root,remove=True)
            runtime_manager.begin(root,plan);runtime_manager.apply(root)
        if install.read(root/'integration.json',{}).get('systemInstalled'):integrate(root,remove=True)
        result=install.uninstall(root)
    else:raise ValueError('Unknown Setup recovery operation')
    (root/'setup-pending.json').unlink()
    return result


def gui(root, config_path, offline=None, runtime_manifest=None, runtime_archive=None):
    if not shutil.which('kdialog'): raise ValueError('Armada KDE kdialog is required to run the graphical installer')
    report = install.host.probe(root)
    if not report['supported']: raise ValueError('\n'.join(report['errors']))
    source = Path(__file__).resolve().parents[1]
    if offline is None and (source.parent / 'offline').is_dir(): offline = source.parent / 'offline'
    if not (root / 'config.json').exists():
        config = sw.decode(Path(config_path).read_bytes())
        if not {'schema', 'feeds', 'publicKey'} <= set(config) or set(config) - {'schema', 'feeds', 'publicKey', 'defaultChannel'} or config.get('schema') != 1: raise ValueError('Invalid publisher bootstrap')
        channel = config.get('defaultChannel', 'alpha')
        if channel not in install.channels.ACTIVE_CHANNELS: raise ValueError('Publisher update channel is not available yet')
        key = Path(config_path).parent / sw.relative(config['publicKey'])
        # The normal Qt application data path; never the Software versions root.
        data = Path(os.environ.get('XDG_DATA_HOME', str(Path.home() / '.local/share'))) / 'TrainerOS/TrainerOS'
        install.initialize(root, config['feeds'], key, data)
        install.select_channel(root, channel)
    # Reject a legacy channel contract before replacing its working Recovery.
    install.configuration(root)
    if not bootstrap(root, source, confirm_update=lambda: dialog('--yesno',
            'Update TrainerOS Setup and Recovery components?\nThe previous version will be retained for recovery. '
            'Close TrainerOS and games first. Personal data and the trusted signing key are kept.').returncode == 0): return 0
    if runtime_manager.pending(root): return recover_full(root,source)
    if (root/'setup-pending.json').exists():
        job=install.read(root/'setup-pending.json')
        if dialog('--yesno','Continue finishing '+job['action']+'? Personal data is kept.').returncode:return 0
        with sw.cache_lock(root/'runtime'),sw.cache_lock(root/'transaction'):
            install.ensure_no_orphans(root);runtimes.idle()
            result=finish_setup(root,job['action'])
        dialog('--msgbox',result['status']);return 0
    if runtime_manifest is None and (source.parent/'runtime-set.json').is_file():
        runtime_manifest=source.parent/'runtime-set.json'; runtime_archive=source.parent/'runtimes.tar'
    if bool(runtime_manifest)!=bool(runtime_archive): raise ValueError('Both the signed runtime manifest and its archive are required')
    current = install.receipt(root)
    action = 'install'
    if current['active'] or install.read(root/'shortcuts.json',[]) or runtime_manager.receipt(root)['active']:
        choice = dialog('--menu', 'TrainerOS installation and recovery', 'install', 'Update / install full runtime set', 'audit', 'Check installation', 'repair', 'Repair installed files',
                        'rollback', 'Return to the previous compatible version', 'cache', 'Clear downloaded update files', 'uninstall', 'Uninstall TrainerOS')
        if choice.returncode: return 0
        action = choice.stdout.strip()
    disk = report['osStorage']
    if action == 'audit':
        result = install.audit(root)
        if runtime_manager.receipt(root)['active']:
            runtime_result=runtime_manager.audit(root)
            result['problems']+=runtime_result['problems']
            result['problems'].append('Runtime files: '+runtime_result['status'])
        dialog('--msgbox', 'Software files: ' + result['status'] + '\nSession integration: ' + result.get('sessionIntegration', 'not-recorded') + '\n' + '\n'.join(result['problems'])); return 0
    if action != 'install':
        if dialog('--yesno', 'Continue with ' + action + '? Personal profiles, games and saves will be kept.').returncode: return 0
        with sw.cache_lock(root / 'runtime'), sw.cache_lock(root / 'transaction'):
            install.ensure_no_orphans(root)
            if action == 'uninstall':
                result=finish_setup(root,'uninstall')
            elif action == 'cache': result = install.clean_cache(root)
            elif action == 'rollback':
                if runtime_manager.receipt(root)['previous']:
                    runtimes.idle(); job=runtime_manager.rollback_plan(root)
                    runtime_manager.begin(root,job); result=runtime_manager.apply(root)
                else: result = install.rollback(root)
            else:
                prerequisites(source)
                with Progress() as progress:
                    progress.update('Repairing installed files')
                    if install.audit(root)['status']=='ready':
                        progress.call('showCancelButton','false');result={'status':'installed'}
                    elif offline is not None:
                        candidate=resolve_offline(root,offline,prepare=True,progress=progress.update,allow_current=True)
                        progress.call('showCancelButton','false')
                        result=install.install_prepared(root,candidate['prepared'],repair=True)
                    else: result=install.repair(root,progress=progress.update,before_install=lambda:progress.call('showCancelButton','false'))
                    result=finish_setup(root,'install')
        dialog('--msgbox', result['status']); return 0
    prerequisites(source)
    shortcuts(root, preflight=True)
    choice = dialog('--radiolist', 'Choose an update channel. Beta and Stable are not available yet.',
                    'alpha', 'Alpha — early testing', 'on')
    if choice.returncode: return 0
    channel = choice.stdout.strip()
    if channel not in install.channels.ACTIVE_CHANNELS: raise ValueError('Update channel is not available yet')
    with Progress() as progress:
        progress.update('Checking update channel')
        candidate = resolve_offline(root, offline, allow_current=bool(runtime_manifest)) if offline is not None else install.resolve(root, channel)
    if candidate['status'] != 'available': raise ValueError('No compatible release is available for this installation')
    description = (f"Install TrainerOS {candidate['version']}?\nSoftware download: {candidate['downloadBytes'] / 1048576:.1f} MiB\n"
                   + ('The emulator set may require additional downloads from its original providers.\n' if runtime_manifest else '')
                   + f"OS: {report['system']}\nOS storage: {disk['location']} ({disk['disk']})\n"
                   f"Free installation space: {report['freeBytes'] / 1073741824:.1f} GiB\n"
                   'Your OS, games, profiles and saves will be kept. TrainerOS becomes the boot default on first setup; Desktop and Steam remain available. Later updates keep your choice.')
    if dialog('--yesno', description).returncode: return 0
    with Progress() as progress:
        result = (resolve_offline(root, offline, prepare=True, progress=progress.update, allow_current=bool(runtime_manifest)) if offline is not None else
                  install.resolve(root, channel, prepare=True, expected=candidate['sequence'], progress=progress.update))
        if result['status'] != 'prepared': raise ValueError('Release changed. Check again before installation')
        if result.get('sequence', candidate['sequence']) != candidate['sequence']:
            raise ValueError('Release changed. Check again before installation')
        with sw.cache_lock(root / 'runtime'), sw.cache_lock(root / 'transaction'):
            install.ensure_no_orphans(root)
            progress.update('Checking application dependencies')
            payload_dependencies(result['prepared'])
            job=None
            if runtime_manifest:
                runtimes.idle()
                for utility in ('flatpak', 'ostree', 'unsquashfs'):
                    if not shutil.which(utility): raise ValueError('The Armada ' + utility + ' utility is required for the full emulator set')
                progress.update('Verifying the emulator set and pinned downloads')
                stage=runtimes.prepare(root,runtime_manifest,runtime_archive,progress.update)
                try: job=runtime_manager.plan(root,stage,result['prepared'],progress=progress.update)
                except ValueError as error:
                    if 'needs migration with a recovery copy' not in str(error): raise
                    if dialog('--yesno','An earlier TrainerOS system helper needs updating. Setup will retain its original for recovery. Your other emulators are not modified.\n\n'+str(error)+'\n\nUpdate this TrainerOS helper?').returncode: return 0
                    job=runtime_manager.plan(root,stage,result['prepared'],migrate=True,progress=progress.update)
            progress.update('Installing verified files')
            progress.call('showCancelButton', 'false')
            if job:
                install.select_channel(root,channel)
                runtime_manager.begin(root,job)
                sw.atomic(root/'setup-pending.json',{'action':'install','channel':channel})
                runtime_manager.apply(root,checkpoint=lambda phase:progress.update('Installing '+phase))
            else:
                release=sw.verified(Path(result['prepared'])/'release.json',root/'trusted-key.pem')['signed']
                sw.atomic(root/'setup-pending.json',{'action':'install','channel':channel,'prepared':result['prepared'],
                          'expected':hashlib.sha256(sw.canonical(release)).hexdigest()})
                install.install_prepared(root,result['prepared'])
            finish_setup(root,'install')
    if not dialog('--yesno', 'TrainerOS is installed. Start TrainerOS now?\nSave any open desktop work before switching.').returncode:
        # Follow the installed Return to TrainerOS entry: the product runs in
        # its own session, including first run, rather than inside Plasma.
        subprocess.Popen(['/usr/bin/sudo', '-n', '/var/opt/traineros/session/control.py', 'traineros'], start_new_session=True)
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=install.DEFAULT_ROOT)
    parser.add_argument('--config', type=Path, default=Path(__file__).resolve().parents[2] / 'bootstrap.json')
    parser.add_argument('--gui', action='store_true')
    parser.add_argument('--offline', type=Path, help='Local signed Software media; no download fallback')
    parser.add_argument('--runtime-manifest',type=Path,help='Signed runtime set with optional pinned upstream downloads')
    parser.add_argument('--runtime-archive',type=Path)
    args = parser.parse_args()
    try:
        if sys.platform != 'linux': raise ValueError('The installer requires Armada Linux')
        if os.getuid() == 0: raise ValueError('Run Setup as your desktop user; only session integration requests system authorization')
        if not args.gui: parser.error('Use --gui from the installer launcher')
        return gui(args.root, args.config, args.offline, args.runtime_manifest, args.runtime_archive)
    except Cancelled as error:
        dialog('--msgbox', str(error)); return 0
    except (OSError, ValueError, RuntimeError, KeyError, TypeError, ImportError, tarfile.TarError, subprocess.SubprocessError) as error:
        if shutil.which('kdialog'): dialog('--error', str(error) + '\nYou can reopen Setup to retry or repair. Personal data is preserved.')
        else: print(str(error), file=sys.stderr)
        return 1


if __name__ == '__main__': raise SystemExit(main())
