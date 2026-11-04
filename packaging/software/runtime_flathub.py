# SPDX-License-Identifier: GPL-3.0-or-later
"""Prepare pinned, signed Flathub commits without touching an installed ref.

The private staging repository is only a download cache. Activation and rollback
still use the existing Flatpak bundle transaction. No latest-version resolution,
user remotes, host installations or emulator configuration are used here.
"""
import os
from pathlib import Path
import re
import subprocess
import time
import installation as install
import releases as sw

URL = 'https://dl.flathub.org/repo/'
REFS = {
    'org.libretro.RetroArch/aarch64/stable',
    'org.DolphinEmu.dolphin-emu/aarch64/stable',
    'org.flycast.Flycast/aarch64/stable',
    'org.freedesktop.Platform/aarch64/25.08',
    'org.freedesktop.Platform.GL.default/aarch64/25.08',
    'org.freedesktop.Platform.GL.default/aarch64/25.08-extra',
    'org.freedesktop.Platform.codecs-extra/aarch64/25.08-extra',
    'org.kde.Platform/aarch64/6.10', 'org.kde.Platform/aarch64/6.11',
    'org.kde.KStyle.Adwaita/aarch64/6.10', 'org.kde.KStyle.Adwaita/aarch64/6.11',
}


def validate(row):
    delivery = row.get('delivery', {})
    if (set(delivery) != {'kind', 'keySha256'} or delivery['kind'] != 'flathub-commit'
            or row.get('ref') not in REFS
            or row.get('kind') != ('app' if row['ref'].startswith(('org.libretro.', 'org.DolphinEmu.', 'org.flycast.')) else 'runtime')
            or not isinstance(row.get('commit'), str) or not sw.HASH.fullmatch(row['commit'])
            or not isinstance(delivery['keySha256'], str) or not sw.HASH.fullmatch(delivery['keySha256'])
            or not re.fullmatch(r'[A-Za-z0-9_.-]+\.flatpak', row.get('file', ''))):
        raise ValueError('Unreviewed upstream Flatpak identity')


def prepare(stage, row, progress=lambda *args: None, runner=subprocess.run):
    validate(row)
    stage = Path(stage)
    key = stage / 'media/flatpak/flathub.gpg'
    if key.is_symlink() or sw.sha256(key) != row['delivery']['keySha256']:
        raise ValueError('Flathub signing key changed')
    cache = install.private(stage / 'downloads/flathub')
    output = cache / (row['commit'] + '.flatpak')
    receipt = cache / (row['commit'] + '.json')
    if output.is_symlink() or receipt.is_symlink(): raise ValueError('Redirected Flathub cache')
    saved = install.read(receipt)
    if saved:
        if (saved.get('ref') != row['ref'] or saved.get('commit') != row['commit']
                or saved.get('keySha256') != row['delivery']['keySha256']
                or not output.is_file() or sw.sha256(output) != saved.get('sha256')):
            raise ValueError('Prepared Flathub package changed')
        return dict(row, preparedFile=str(output), sha256=saved['sha256'], bytes=output.stat().st_size)
    repo = install.private(cache / 'repo')
    private_home = install.private(cache / 'home')
    env = dict(os.environ, HOME=str(private_home), XDG_DATA_HOME=str(private_home / '.local/share'),
               XDG_CONFIG_HOME=str(private_home / '.config'), FLATPAK_USER_DIR=str(private_home / '.local/share/flatpak'),
               TMPDIR=str(cache), LC_ALL='C')
    phase = 'Preparing runtime: ' + row['ref']

    def command(args, timeout=1800):
        if runner is not subprocess.run:
            result = runner(args, env=env, capture_output=True, text=True, timeout=timeout)
            status, stdout, stderr = result.returncode, result.stdout, result.stderr
        else:
            started = time.monotonic()
            with subprocess.Popen(args, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True) as process:
                try:
                    while True:
                        elapsed = time.monotonic() - started
                        if elapsed >= timeout: raise ValueError('Runtime preparation timed out: ' + row['ref'])
                        try:
                            stdout, stderr = process.communicate(timeout=min(10, timeout - elapsed))
                            status = process.returncode; break
                        except subprocess.TimeoutExpired:
                            elapsed = int(time.monotonic() - started)
                            progress(phase + ' (' + str(elapsed // 60) + 'm ' + str(elapsed % 60) + 's)')
                except BaseException:
                    process.terminate()
                    try: process.communicate(timeout=5)
                    except subprocess.TimeoutExpired: process.kill(); process.communicate()
                    raise
        if status: raise ValueError('Preparing Flathub package failed: ' + stderr[-2000:])
        return stdout.strip()

    ostree = ['ostree', '--repo=' + str(repo)]
    if not (repo / 'config').exists(): command([*ostree, 'init', '--mode=archive-z2'], 30)
    command([*ostree, 'remote', 'add', '--if-not-exists', '--gpg-import=' + str(key),
             '--set=gpg-verify=true', '--set=gpg-verify-summary=true', 'flathub', URL], 30)
    if command([*ostree, 'remote', 'show-url', 'flathub'], 30) != URL:
        raise ValueError('Flathub staging remote changed')
    for setting in ('gpg-verify', 'gpg-verify-summary'):
        if command([*ostree, 'config', 'get', 'remote "flathub".' + setting], 30) != 'true':
            raise ValueError('Flathub signature verification must remain enabled')
    ref = row['kind'] + '/' + row['ref']
    phase = 'Downloading verified runtime: ' + row['ref']; progress(phase)
    # Identify our downloader: the CDN rejects the bare libostree user-agent.
    # Keep HTTPS, GPG verification, commit bindings and content hashes enabled.
    command([*ostree, 'pull', '--http-header=User-Agent=TrainerOS-Setup/1',
             'flathub', ref + '@' + row['commit']])
    if command([*ostree, 'rev-parse', 'flathub:' + ref], 30) != row['commit']:
        raise ValueError('Downloaded Flatpak version differs')
    command([*ostree, 'refs', '--force', '--create=' + ref, row['commit']], 30)
    temporary = output.with_suffix('.partial')
    if temporary.is_symlink(): raise ValueError('Redirected Flatpak export')
    if temporary.exists(): temporary.unlink()
    name, arch, branch = row['ref'].split('/')
    phase = 'Preparing runtime: ' + row['ref']; progress(phase)
    command(['flatpak', 'build-bundle', '--arch=' + arch,
             *(['--runtime'] if row['kind'] == 'runtime' else []),
             str(repo), str(temporary), name, branch])
    sha = sw.sha256(temporary)
    os.replace(temporary, output)
    sw.atomic(receipt, {'ref': row['ref'], 'commit': row['commit'],
                       'keySha256': row['delivery']['keySha256'], 'sha256': sha})
    return dict(row, preparedFile=str(output), sha256=sha, bytes=output.stat().st_size)
