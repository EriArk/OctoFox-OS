#!/usr/bin/env python3
"""Install the development ship game into a chosen XDG data directory."""
# SPDX-License-Identifier: GPL-3.0-or-later
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

APP = 'art.abysstail.octofox.ship-home'

def desktop_quote(value):
    return '"' + str(value).replace('\\', '\\\\').replace('"', '\\"').replace('`', '\\`').replace('$', '\\$').replace('%', '%%') + '"'

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', type=Path, required=True, help='Existing Godot 4.7.x executable; it is not copied or downloaded')
    parser.add_argument('--data-home', type=Path, default=Path(os.environ.get('XDG_DATA_HOME', Path.home()/'.local/share')))
    args = parser.parse_args()
    engine = args.godot.expanduser().resolve(strict=True)
    version = subprocess.run([str(engine), '--version'], check=True, capture_output=True, text=True).stdout.strip()
    if not version.startswith('4.7.'):
        parser.error('This development build requires the tested Godot 4.7.x runtime')
    source = Path(__file__).resolve().parent
    root = args.data_home.expanduser().resolve() / 'octofox' / 'ship-home'
    root.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='.stage-', dir=root) as temporary:
        stage = Path(temporary) / 'game'
        shutil.copytree(source, stage, ignore=shutil.ignore_patterns('.godot', 'addons', '__pycache__', '*.tmp', 'tests'))
        sdk = source.parents[1] / 'sdk' / 'godot'
        (stage/'addons'/'avatar').mkdir(parents=True)
        for name in ('avatar_client.gd', 'avatar_presenter.gd'):
            shutil.copy2(sdk/name, stage/'addons'/'avatar'/name)
        (stage/'runtime.json').write_text(json.dumps({'engine': str(engine)}))
        digest = hashlib.sha256()
        for path in sorted(stage.rglob('*')):
            if path.is_file():
                digest.update(str(path.relative_to(stage)).encode()); digest.update(path.read_bytes())
        revision = digest.hexdigest()[:16]
        result = subprocess.run([str(engine), '--headless', '--path', str(stage), '--editor', '--import', '--quit'], capture_output=True, text=True, timeout=120)
        if result.returncode or 'SCRIPT ERROR' in result.stderr or 'ERROR:' in result.stderr:
            raise RuntimeError('Godot import failed:\n'+result.stdout+result.stderr)
        destination = root/revision
        if destination.exists():
            for path in stage.rglob('*'):
                relative = path.relative_to(stage)
                if path.is_file() and relative.parts[0] != '.godot':
                    installed = destination/relative
                    if not installed.is_file() or installed.read_bytes() != path.read_bytes():
                        raise RuntimeError(f'Existing development copy was modified: {destination}. Close it and remove that copy before reinstalling; personal saves are elsewhere.')
        else:
            stage.rename(destination)
    desktop_dir = args.data_home.expanduser().resolve()/'applications'
    desktop_dir.mkdir(parents=True, exist_ok=True)
    target = desktop_dir/(APP+'.desktop')
    content = '\n'.join(('[Desktop Entry]', 'Type=Application', 'Name=OctoFox Ship Home',
        'Comment=Your personal ship — development preview',
        'Exec='+desktop_quote(sys.executable)+' '+desktop_quote(destination/'launch.py'),
        'Icon=applications-games', 'Terminal=false', 'Categories=Game;', 'StartupNotify=true', ''))
    temporary = target.with_suffix('.desktop.tmp')
    temporary.write_text(content); temporary.replace(target)
    print('Installed:', target)
    print('Runtime:', engine, '('+version+')')
    print('Game:', destination)
    print('No system files or handhelds changed.')

if __name__ == '__main__':
    main()
