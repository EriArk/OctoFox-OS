# SPDX-License-Identifier: GPL-3.0-or-later
"""Signed offline runtime generations and recoverable activation.

Only explicit code inputs are projected into emulator directories. Personal
configs, firmware, saves, ROMs and account files are never deployment inputs.
"""
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
import installation as install
import releases as sw
import runtime_payload
from runtime_transaction import Files

NATIVE = {'azahar-netplay', 'dolphin-lan', 'dolphin-netplay', 'flycast-lan', 'flycast-netplay',
          'flycast-online', 'melonds-netplay', 'neocd-netplay', 'ngpc', 'odamex', 'pcsx-rearmed-cbin',
          'ps2-lan', 'rmg-netplay', 'supermodel-link', 'vita3k-netplay', 'xemu-lan'}
IMAGES = {'ARMSX2', 'Azahar-Enhanced', 'Cemu', 'melonDS', 'DuckStation', 'eden', 'rpcs3'}
EXTRAS = {'retroarch-cores', 'linked-save', 'psp-content', 'psp-network', 'remote-play', 'game-capture'}
ENVIRONMENTS = {'voice', 'linked-save', 'melonds-netplay', 'azahar-netplay', 'rmg-netplay', 'vita3k-netplay'}
APP_REFS = {'org.libretro.RetroArch/aarch64/stable', 'org.ppsspp.PPSSPP/aarch64/traineros-relay',
            'org.DolphinEmu.dolphin-emu/aarch64/stable', 'org.flycast.Flycast/aarch64/stable'}


def checked_path(root, name):
    path = Path(root).joinpath(*runtime_payload.relative(name).parts)
    if path.is_symlink() or any(p.is_symlink() for p in path.parents): raise ValueError('Redirected runtime input')
    return path


def signed(path, key):
    raw = Path(path).read_bytes()
    if len(raw) > sw.MAX_MANIFEST: raise ValueError('Oversized runtime envelope')
    envelope = sw.decode(raw)
    if set(envelope) != {'signed', 'signature'}: raise ValueError('Invalid runtime envelope')
    value = envelope['signed']; sw.signature(value, key, envelope['signature'])
    if set(value) != {'schema', 'product', 'sequence', 'softwareSource', 'archive', 'files'} or value['schema'] != 1 or value['product'] != 'traineros-runtime-set':
        raise ValueError('Unsupported runtime set')
    if not sw.integer(value['sequence'], 1, 2**53-1) or not re.fullmatch('[0-9a-f]{40}', value['softwareSource']):
        raise ValueError('Invalid runtime release identity')
    if not sw.HASH.fullmatch(value['archive']['sha256']) or not sw.integer(value['archive']['bytes'], 1, 32*1024**3):
        raise ValueError('Invalid runtime archive')
    names = set(); total = 0
    if not 1 <= len(value['files']) <= 30000: raise ValueError('Invalid runtime inventory')
    for row in value['files']:
        name = str(runtime_payload.relative(row['path']))
        if name in names or not sw.HASH.fullmatch(row['sha256']) or not sw.integer(row['bytes'], 0, 8*1024**3):
            raise ValueError('Invalid runtime file identity')
        total += row['bytes']; names.add(name)
    if total > 32*1024**3: raise ValueError('Oversized runtime set')
    return envelope


def publish_manifest(media_index, archive, key, output, sequence, software_source):
    index = json.loads(Path(media_index).read_text())
    value = {'schema': 1, 'product': 'traineros-runtime-set', 'sequence': sequence,
             'softwareSource': software_source,
             'archive': {'bytes': Path(archive).stat().st_size, 'sha256': sw.sha256(archive)}, 'files': index['files']}
    sw.atomic(output, {'signed': value, 'signature': sw.signature(value, key)})


def extract(archive, destination, rows):
    """No extractall: only signed regular files, bounded lengths and exact hashes."""
    expected = {row['path']: row for row in rows}; seen = set()
    if len(expected) != len(rows): raise ValueError('Duplicate runtime entries')
    with tarfile.open(archive, 'r:*') as tar:
        for member in tar:
            # Full media's informational index is not executable or authoritative.
            if member.name == 'fullbundle.json' and member.name not in expected:
                if not member.isfile() or member.size > sw.MAX_MANIFEST: raise ValueError('Invalid media index')
                continue
            if member.name in seen or member.name not in expected or not member.isfile():
                raise ValueError('Unexpected runtime archive entry')
            row = expected[member.name]
            if member.size != row['bytes']: raise ValueError('Runtime archive size mismatch')
            target = checked_path(destination, member.name); target.parent.mkdir(parents=True, exist_ok=True)
            digest = hashlib.sha256()
            with tar.extractfile(member) as source, target.open('xb') as out:
                while chunk := source.read(1024**2): out.write(chunk); digest.update(chunk)
            if digest.hexdigest() != row['sha256']: raise ValueError('Runtime archive hash mismatch')
            target.chmod(row.get('mode', 0o644)); seen.add(member.name)
    if seen != set(expected): raise ValueError('Incomplete runtime archive')


def verify_media(stage, envelope):
    for row in envelope['signed']['files']:
        path = checked_path(stage / 'media', row['path'])
        if not path.is_file() or path.stat().st_size != row['bytes'] or sw.sha256(path) != row['sha256']:
            raise ValueError('Prepared runtime media changed: ' + row['path'])


def prepare(root, manifest, archive, progress=lambda *args: None):
    root = install.private(root); envelope = signed(manifest, root / 'trusted-key.pem')
    identity = hashlib.sha256(sw.canonical(envelope['signed'])).hexdigest()
    store = install.private(root / 'runtimes/versions'); stage = store / identity
    if stage.exists():
        if (stage / 'prepared.json').exists():
            verify_media(stage, envelope); return stage
        # Only incomplete, never-activated generations may be discarded.
        if install.read(root / 'runtimes/transaction.json') or identity in install.read(root / 'runtimes/receipt.json', {}).values():
            raise ValueError('Recover runtime activation before preparing again')
        signed(stage / 'release.json', root / 'trusted-key.pem')
        install.remove_owned_tree(stage, store)
    expected = envelope['signed']['archive']; archive = Path(archive)
    if archive.is_symlink() or archive.stat().st_size != expected['bytes'] or sw.sha256(archive) != expected['sha256']:
        raise ValueError('Runtime media does not match its signed identity')
    if shutil.disk_usage(store).free < expected['bytes'] * 4 + 2*1024**3:
        raise ValueError('Not enough space for runtime staging, dependencies and recovery copies')
    # Generation path is stable: virtualenv entry-point shebangs must not be moved.
    stage.mkdir(mode=0o700)
    sw.atomic(stage / 'release.json', envelope)
    try:
        progress('Preparing emulator packages')
        extract(archive, stage / 'media', envelope['signed']['files'])
        verify_media(stage, envelope)
        sw.atomic(stage / 'prepared.json', {'schema': 1, 'identity': identity})
    except BaseException:
        sw.atomic(stage / 'incomplete.json', {'phase': 'media'}); raise
    return stage


def component(stage, identity, progress=lambda *args: None):
    media = stage / 'media/runtimes' / identity
    record = json.loads((media / 'component.json').read_text())
    if record['id'] != identity or record['schema'] != 1 or len(record['files']) > 30000:
        raise ValueError('Invalid runtime component')
    if sum(row['bytes'] for row in record['files']) > 12*1024**3: raise ValueError('Oversized runtime component')
    for row in record['files']:
        runtime_payload.relative(row['path'])
        if row.get('mode') not in (0o644, 0o755) or not sw.HASH.fullmatch(row['sha256']) or not sw.integer(row['bytes'], 0, 2*1024**3):
            raise ValueError('Invalid runtime file metadata')
        if row['path'].startswith('firmware/'):
            raise ValueError('User firmware must not enter the runtime installer')
    upstream = 'delivery' in record
    if upstream:
        import runtime_upstream
        runtime_upstream.validate(record)
        if (media / 'component.tar.gz').exists(): raise ValueError('Upstream runtime must not be bundled')
    else:
        archive = media / 'component.tar.gz'
        if sw.sha256(archive) != record['archive']['sha256']: raise ValueError('Component archive changed')
    external = []
    if 'upstreamRuntime' in record:
        import runtime_vita_upstream
        external = runtime_vita_upstream.rows(record)
    target = stage / 'components' / identity
    def verify_component(directory):
        for row in record['files']:
            path = checked_path(directory, row['path'])
            if path.stat().st_size != row['bytes'] or sw.sha256(path) != row['sha256']:
                raise ValueError('Prepared component changed')
    if not target.exists():
        target.parent.mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(dir=target.parent, prefix='.component-') as tmp:
            if upstream:
                part = runtime_upstream.prepare(stage, record, progress)
                row = record['files'][0]; output = Path(tmp) / row['path']
                shutil.copyfile(part, output); output.chmod(row['mode'])
            else:
                extract(archive, Path(tmp), [row for row in record['files'] if row not in external])
                if external: runtime_vita_upstream.prepare(stage, record, Path(tmp), progress)
            verify_component(Path(tmp))
            os.replace(tmp, target)
    verify_component(target)
    return record, target


def environment(stage, name, python=sys.executable, *, recover_incomplete=False):
    locks = json.loads((stage / 'media/python/interpreters.json').read_text()); spec = locks[name]
    if sw.sha256(python) != spec['pythonSha256']:
        raise ValueError('Armada Python differs from the approved multiplayer runtime; use a compatible runtime set')
    lines = (stage / 'media/python' / (name + '.lock')).read_text().splitlines()
    if sorted(lines) != sorted(spec['requirements']) or any(not re.fullmatch(r'[A-Za-z0-9_.-]+==[A-Za-z0-9_.+!-]+', x) for x in lines):
        raise ValueError('Invalid pinned Python requirements')
    dest = stage / 'venvs' / name; ready = stage / 'venvs' / (name + '.json')
    if ready.exists() and recover_incomplete:
        # Only the coordinator may authorize rebuilding an unactivated stage.
        # A power loss can preserve the receipt before all venv files reach disk.
        try:
            intact = install.read(ready)['files'] == environment_files(dest)
        except (OSError, ValueError, KeyError, TypeError):
            intact = False
        if not intact:
            if ready.is_symlink() or ready.resolve().parent != (stage / 'venvs').resolve():
                raise ValueError('Redirected Python environment receipt')
            ready.unlink()
    if not ready.exists():
        if dest.exists(): install.remove_owned_tree(dest, stage / 'venvs')
        dest.parent.mkdir(exist_ok=True)
        subprocess.run([python, '-m', 'venv', str(dest)], check=True, timeout=120)
        env = dict(os.environ, TMPDIR=str(stage / 'tmp')); (stage / 'tmp').mkdir(exist_ok=True)
        subprocess.run([str(dest / 'bin/python'), '-m', 'pip', 'install', '--no-index', '--no-cache-dir', '--disable-pip-version-check',
                        '--no-deps', '--find-links', str(stage / 'media/python/wheels'), '-r', str(stage / 'media/python' / (name + '.lock'))],
                       env=env, check=True, timeout=600)
        subprocess.run([str(dest / 'bin/python'), '-m', 'pip', 'check'], check=True, timeout=60)
        sw.atomic(ready, {'requirements': lines, 'pythonSha256': spec['pythonSha256'],
                         'files': environment_files(dest)})
    if sw.sha256(dest / 'bin/python') != spec['pythonSha256']: raise ValueError('Python runtime changed')
    if install.read(ready)['files'] != environment_files(dest): raise ValueError('Prepared Python environment changed: ' + name)
    return dest


def environment_files(dest):
    # Bytecode is a regenerable cache, not environment code ownership.
    return {p.relative_to(dest).as_posix(): (os.readlink(p) if p.is_symlink() else sw.sha256(p))
            for p in sorted(dest.rglob('*')) if (p.is_file() or p.is_symlink()) and '__pycache__' not in p.parts and p.suffix != '.pyc'}


def destination(home, data, identity, name):
    runtime_payload.relative(name)
    if identity in NATIVE: return data / 'TrainerOS/emulators' / identity / name
    if identity in IMAGES:
        if name != identity + '.AppImage': raise ValueError('Unexpected AppImage payload')
        return home / 'Applications' / name
    if identity == 'retroarch-cores':
        if not (name.startswith('cores/') and name.endswith('_libretro.so') or name.startswith('info/') and name.endswith('.info')):
            raise ValueError('RetroArch payload must contain cores/info only')
        return home / '.var/app/org.libretro.RetroArch/config/retroarch' / name
    if identity == 'linked-save': return data / 'TrainerOS/runtime/linked-save-20261010.1' / name
    if identity in {'psp-content', 'psp-network'}: return data / 'traineros' / identity / name
    raise ValueError('Unknown user runtime destination')


def deployment(root, stage, home=None, data=None, make_environments=True, progress=lambda *args:None, *, recover_incomplete=False):
    import runtime_layout
    home, data = runtime_layout.paths(root)
    files = Files(Path(root) / 'runtimes/files', [home, data]); desired = {}; system = []
    present = {p.name for p in (stage / 'media/runtimes').iterdir() if p.is_dir()}
    if present != NATIVE | IMAGES | EXTRAS: raise ValueError('Incomplete or unknown runtime family set')
    expanded=sum(sum(f['bytes'] for f in json.loads((stage/'media/runtimes'/name/'component.json').read_text())['files']) for name in present)
    if expanded>20*1024**3: raise ValueError('Runtime files exceed the installation budget')
    bundles=sum(row['bytes'] for row in install.read(stage/'media/flatpak/flatpak-lock.json')['refs']) if (stage/'media/flatpak/flatpak-lock.json').exists() else 0
    needed=expanded*3+bundles*4+2*1024**3
    # Account for both managed staging/backups and projections on another disk.
    for location in {Path(root),home,data}:
        while not location.exists():location=location.parent
        if shutil.disk_usage(location).free<needed: raise ValueError('Not enough space for emulator installation and recovery on '+str(location))
    aliases = {}
    for identity in sorted(present):
        progress('Preparing emulator: '+identity)
        record, source = component(stage, identity, progress)
        for row in record['files']:
            name = row['path']; path = source / name
            if identity in {'remote-play', 'game-capture'}:
                target = ('remote-play/' + name) if identity == 'remote-play' else 'traineros-game-capture'
                if identity == 'game-capture' and name != 'libexec/traineros/traineros-game-capture': raise ValueError('Unknown capture payload')
                system.append({'path': target, 'source': str(path), 'sha256': row['sha256'], 'mode': row['mode']}); continue
            dest = destination(home, data, identity, name)
            files.path(str(dest))  # Reject aliases rather than following external installations.
            if name == 'manifest.json' and record.get('metadata', {}).get('manifestTemplate'):
                value = path.read_text().replace('${HOME}', json.dumps(str(home))[1:-1])
                rendered = stage / 'rendered' / identity / name; rendered.parent.mkdir(parents=True, exist_ok=True)
                rendered.write_text(value); path = rendered
            # Older candidates recorded downloaded AppImages as 0644. Repair
            # that metadata during projection without changing binary bytes or
            # adopting any other launcher's installation.
            desired[str(dest)] = files.import_file(path, 0o755 if identity in IMAGES else row['mode'])
    if make_environments:
        for name in sorted(ENVIRONMENTS):
            progress('Preparing offline Python: '+name)
            built = environment(stage, name, recover_incomplete=recover_incomplete)
            if name == 'voice': dest = data / 'traineros-voice'
            elif name == 'linked-save': dest = data / 'TrainerOS/runtime/linked-save-20261010.1/venv'
            else: dest = data / 'TrainerOS/emulators' / name / 'transport/venv'
            desired[str(dest)] = {'kind': 'link', 'target': str(built)}
    return files, desired, system, aliases


def flatpak_rows(stage, progress=lambda *args: None):
    rows = install.read(stage / 'media/flatpak/flatpak-lock.json')['refs']
    refs = set()
    for row in rows:
        if row['kind'] not in ('app', 'runtime') or not re.fullmatch(r'[A-Za-z][A-Za-z0-9_.-]+/aarch64/[A-Za-z0-9_.-]+', row['ref']):
            raise ValueError('Invalid Flatpak reference')
        if row['ref'] in refs or not sw.HASH.fullmatch(row['commit']): raise ValueError('Invalid Flatpak identity')
        refs.add(row['ref'])
        if 'delivery' in row:
            import runtime_flathub
            runtime_flathub.validate(row)
            if checked_path(stage / 'media/flatpak', row['file']).exists():
                raise ValueError('Upstream Flatpak must not be bundled')
            continue
        path = checked_path(stage / 'media/flatpak', row['file'])
        if path.stat().st_size != row['bytes'] or sw.sha256(path) != row['sha256']: raise ValueError('Flatpak bundle changed')
    if {r['ref'] for r in rows if r['kind']=='app'} != APP_REFS or len(rows) != 12:
        raise ValueError('Incomplete offline Flatpak set')
    result = []
    for row in rows:
        if 'delivery' in row:
            import runtime_flathub
            row = runtime_flathub.prepare(stage, row, progress)
        result.append(row)
    return result


def check_aliases(aliases):
    for name, target in aliases.items():
        if not Path(name).is_symlink() or os.readlink(name) != target:
            raise ValueError('Runtime directory link changed after review')


def idle(protected=(), owned_home=None):
    names = {'traineros'}  # Other launchers' emulators do not belong to this transaction.
    if not Path('/proc').is_dir(): raise ValueError('Runtime activation requires Linux')
    protected={str(Path(p).resolve()) for p in protected}
    environment_markers = {('HOME='+str(owned_home)).encode(),
                           ('FLATPAK_USER_DIR='+str(Path(owned_home)/'.local/share/flatpak')).encode()} if owned_home else set()
    for item in Path('/proc').iterdir():
        try:
            if not item.name.isdigit() or item.stat().st_uid != os.getuid(): continue
            if ((item / 'comm').read_text().strip().lower() in names or
                    protected and str((item/'exe').resolve()) in protected or
                    environment_markers and environment_markers.intersection((item/'environ').read_bytes().split(b'\0'))):
                raise ValueError('Close TrainerOS and emulators before runtime installation')
        except (FileNotFoundError, ProcessLookupError, PermissionError): continue
