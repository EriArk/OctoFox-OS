# SPDX-License-Identifier: GPL-3.0-or-later
"""GitHub-sized release parts with pinned identity and resumable preparation.

This transports an existing archive. It never signs a new release, upgrades a
runtime, publishes assets, or substitutes for the normal Setup verification.
"""
import argparse
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
import urllib.parse
import releases as sw

LIMIT = 2 * 1024**3
CHUNK = 1024**2


def filename(value):
    if not isinstance(value, str) or not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._+-]{0,180}', value):
        raise ValueError('Invalid release filename')
    return value


def validate(plan):
    if set(plan) != {'schema', 'product', 'repository', 'tag', 'archive', 'parts'} or plan['schema'] != 1 or plan['product'] != 'traineros-release-parts':
        raise ValueError('Invalid multipart release')
    if not re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+', plan['repository']):
        raise ValueError('Invalid GitHub repository')
    filename(plan['tag'])
    total = plan['archive']
    def row(item, maximum):
        if (set(item) != {'name', 'size', 'sha256'} or not sw.integer(item['size'], 1, maximum)
                or not isinstance(item['sha256'], str) or not sw.HASH.fullmatch(item['sha256'])):
            raise ValueError('Invalid release part identity')
        filename(item['name'])
    row(total, 32 * 1024**3)
    if not isinstance(plan['parts'], list) or not 1 <= len(plan['parts']) <= 128:
        raise ValueError('Invalid release part count')
    for i, part in enumerate(plan['parts'], 1):
        row(part, LIMIT - 1)
        if part['name'] != total['name'] + '.part' + str(i).zfill(3):
            raise ValueError('Release parts are missing or out of order')
    if sum(p['size'] for p in plan['parts']) != total['size']:
        raise ValueError('Release part sizes differ from archive')
    return plan


def split(archive, output, repository, tag, part_size=1024**3):
    archive, output = Path(archive), Path(output)
    if archive.is_symlink() or not archive.is_file() or output.exists():
        raise ValueError('Use an existing regular archive and a new output directory')
    if not sw.integer(part_size, 1, LIMIT - 1): raise ValueError('Each GitHub asset must be under 2 GiB')
    plan = {'schema': 1, 'product': 'traineros-release-parts', 'repository': repository, 'tag': tag,
            'archive': {'name': filename(archive.name), 'size': archive.stat().st_size, 'sha256': '0' * 64}, 'parts': []}
    # Validate even before creating an output, including the worst-case part count.
    count = (plan['archive']['size'] + part_size - 1) // part_size
    plan['parts'] = [{'name': archive.name + '.part' + str(i + 1).zfill(3),
                      'size': min(part_size, plan['archive']['size'] - i * part_size), 'sha256': '0' * 64} for i in range(min(count, 129))]
    validate(plan)
    output.mkdir(parents=True, mode=0o700)
    whole = hashlib.sha256()
    with archive.open('rb') as source:
        for part in plan['parts']:
            digest = hashlib.sha256(); remaining = part['size']
            with (output / part['name']).open('xb') as target:
                while remaining:
                    block = source.read(min(CHUNK, remaining))
                    if not block: raise ValueError('Archive shortened during splitting')
                    target.write(block); digest.update(block); whole.update(block); remaining -= len(block)
            part['sha256'] = digest.hexdigest()
        if source.read(1): raise ValueError('Archive grew during splitting')
    plan['archive']['sha256'] = whole.hexdigest()
    sw.atomic(output / 'parts.json', plan)
    return plan


def load(manifest, expected):
    manifest = Path(manifest)
    if manifest.is_symlink() or manifest.stat().st_size > 128 * 1024:
        raise ValueError('Invalid release parts manifest')
    raw = manifest.read_bytes()
    if not sw.HASH.fullmatch(expected) or hashlib.sha256(raw).hexdigest() != expected:
        raise ValueError('Release parts manifest differs from the trusted download kit')
    return validate(sw.decode(raw))


def assemble(manifest, expected, cache, download=False, progress=sw.event, opener=None):
    plan = load(manifest, expected)
    # An identity-specific private cache prevents collisions between releases.
    with sw.cache_lock(Path(cache)) as root:
        final = root / plan['archive']['name']
        if final.exists() or final.is_symlink():
            if final.is_symlink() or not final.is_file() or final.stat().st_size != plan['archive']['size'] or sw.sha256(final) != plan['archive']['sha256']:
                raise ValueError('Existing output differs; retained without overwrite')
            return final
        missing = sum(max(0, p['size'] - (root / p['name']).stat().st_size)
                      if (root / p['name']).is_file() else p['size'] for p in plan['parts'])
        if shutil.disk_usage(root).free < plan['archive']['size'] + (missing if download else 0) + 16 * CHUNK:
            raise ValueError('Not enough space for release parts and the assembled archive')
        base = 'https://github.com/' + plan['repository'] + '/releases/download/' + urllib.parse.quote(plan['tag'], safe='') + '/'
        for part in plan['parts']:
            path = root / part['name']
            if download:
                sw.download({'url': base + urllib.parse.quote(part['name'], safe=''), 'size': part['size'], 'sha256': part['sha256']},
                            path, lambda phase, done, total: progress(part['name'] + ' — ' + phase, done, total), opener)
            elif path.is_symlink() or not path.is_file() or path.stat().st_size != part['size'] or sw.sha256(path) != part['sha256']:
                raise ValueError('Missing or damaged release part: ' + part['name'])
        with tempfile.NamedTemporaryFile(dir=root, prefix='.assembling-', delete=False) as target:
            temporary = Path(target.name)
            try:
                whole = hashlib.sha256(); done = 0
                for part in plan['parts']:
                    digest = hashlib.sha256(); size = 0
                    with (root / part['name']).open('rb') as source:
                        while block := source.read(CHUNK):
                            size += len(block)
                            if size > part['size']: raise ValueError('Release part grew during assembly')
                            target.write(block); whole.update(block); digest.update(block); done += len(block)
                            progress('Assembling verified download', done, plan['archive']['size'])
                    if size != part['size'] or digest.hexdigest() != part['sha256']:
                        raise ValueError('Release part changed during assembly')
                if whole.hexdigest() != plan['archive']['sha256']: raise ValueError('Assembled archive hash mismatch')
                target.flush(); os.fsync(target.fileno())
            except BaseException:
                target.close(); temporary.unlink(); raise
        try:
            # The private cache lock serializes publication. Rename also works
            # on removable filesystems without hard-link support.
            if final.exists() or final.is_symlink(): raise ValueError('Output appeared during assembly')
            os.rename(temporary, final)
        finally: temporary.unlink(missing_ok=True)
        return final


def unpack_setup(archive, destination, progress=sw.event):
    destination = Path(destination)
    if destination.is_symlink(): raise ValueError('Redirected Setup folder retained')
    with tarfile.open(archive) as source:
        members = source.getmembers(); seen = set(); total = 0
        for member in members:
            # Setup's desktop launchers intentionally have spaces in their names.
            # Retain all other portable path restrictions used by Software.
            sw.relative(member.name.replace(' ', '_'))
            name = member.name
            if any(part.endswith((' ', '.')) for part in name.split('/')):
                raise ValueError('Ambiguous Setup archive path')
            if (name in seen or not (name == 'TrainerOS-Setup' or name.startswith('TrainerOS-Setup/'))
                    or not (member.isfile() or member.isdir()) or member.size < 0):
                raise ValueError('Unsafe Setup archive entry')
            seen.add(name); total += member.size
        if total > 32 * 1024**3 or 'TrainerOS-Setup/packaging/software/installer.py' not in seen:
            raise ValueError('Incomplete or oversized Setup archive')
        if destination.exists():
            if not destination.is_dir(): raise ValueError('Existing Setup destination is not a folder')
            files = {p.relative_to(destination).as_posix(): p for p in destination.rglob('*')
                     if not p.is_dir() or p.is_symlink()}
            expected = {m.name.removeprefix('TrainerOS-Setup/'): m for m in members if m.isfile()}
            if set(files) != set(expected): raise ValueError('Existing Setup folder changed; retained without overwrite')
            done = 0
            for name, member in expected.items():
                path = files[name]
                if path.is_symlink() or not path.is_file() or path.stat().st_size != member.size:
                    raise ValueError('Existing Setup file changed; retained without overwrite')
                with source.extractfile(member) as incoming:
                    digest = hashlib.file_digest(incoming, 'sha256').hexdigest()
                if sw.sha256(path) != digest: raise ValueError('Existing Setup file changed; retained without overwrite')
                if os.name != 'nt' and bool(path.stat().st_mode & 0o111) != bool(member.mode & 0o111):
                    raise ValueError('Existing Setup permissions changed; retained without overwrite')
                done += member.size; progress('Verifying existing Setup', done, total)
            return destination
        if shutil.disk_usage(destination.parent).free < total + 16 * CHUNK: raise ValueError('Not enough space to extract Setup')
        with tempfile.TemporaryDirectory(dir=destination.parent, prefix='.setup-download-') as tmp:
            done = 0
            for member in members:
                path = Path(tmp) / member.name
                if member.isdir(): path.mkdir(parents=True, exist_ok=True); continue
                path.parent.mkdir(parents=True, exist_ok=True)
                with source.extractfile(member) as incoming, path.open('xb') as target:
                    while block := incoming.read(CHUNK):
                        target.write(block); done += len(block); progress('Extracting verified Setup', done, total)
                path.chmod(0o755 if member.mode & 0o111 else 0o644)
            if destination.exists(): raise ValueError('Setup destination appeared during extraction')
            os.rename(Path(tmp) / 'TrainerOS-Setup', destination)
    return destination


def kit(parts, output):
    """A small reviewed bootstrap pins its local manifest before any download."""
    import installer
    parts, output = Path(parts), Path(output)
    manifest = parts / 'parts.json'; digest = sw.sha256(manifest); load(manifest, digest)
    if output.exists(): raise ValueError('Download kit output already exists')
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp); tree = root / 'TrainerOS-Download'; tree.mkdir()
        holder = root / 'bootstrap'; holder.mkdir()
        installer.bootstrap(holder, Path(__file__).resolve().parents[1])
        shutil.copytree(holder / 'bootstrap/packaging', tree / 'packaging')
        shutil.copyfile(manifest, tree / 'parts.json')
        launch = tree / 'Download TrainerOS.sh'
        launch.write_bytes(('#!/bin/sh\nset -eu\nHERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)\n'
                           'exec /usr/bin/python3 "$HERE/packaging/software/release_parts.py" gui '
                           '"$HERE/parts.json" --sha256 ' + digest + '\n').encode())
        launch.chmod(0o755)
        (tree / 'README.txt').write_text('Extract this folder in Armada Desktop and open Download TrainerOS.sh.\n'
            'Choose storage with space for the download and extraction. Interrupted downloads resume.\n'
            'Setup opens after all parts and the complete archive are verified. Do not run as root.\n'
            'This download kit does not itself approve or publish a release.\n', encoding='utf-8')
        def public_metadata(member):
            member.uid = member.gid = member.mtime = 0
            member.uname = member.gname = ''
            member.mode = 0o755 if member.isdir() or member.name.endswith('.sh') else 0o644
            return member
        with tarfile.open(output, 'x:gz') as archive:
            archive.add(tree, arcname=tree.name, filter=public_metadata)
    return {'file': output.name, 'sha256': sw.sha256(output), 'manifestSha256': digest}


def main():
    parser = argparse.ArgumentParser(description=__doc__); commands = parser.add_subparsers(dest='command', required=True)
    p = commands.add_parser('split'); p.add_argument('archive'); p.add_argument('output'); p.add_argument('--repository', required=True); p.add_argument('--tag', required=True)
    p = commands.add_parser('kit'); p.add_argument('parts'); p.add_argument('output')
    for command in ('join', 'fetch', 'gui'):
        p = commands.add_parser(command); p.add_argument('manifest'); p.add_argument('--sha256', required=True)
        if command != 'gui': p.add_argument('--cache', required=True)
    args = parser.parse_args()
    try:
        if args.command == 'split': result = split(args.archive, args.output, args.repository, args.tag)
        elif args.command == 'kit': result = kit(args.parts, args.output)
        elif args.command == 'gui':
            import installer
            if os.geteuid() == 0: raise ValueError('Run the download as your desktop user')
            plan = load(args.manifest, args.sha256)
            choice = installer.dialog('--getexistingdirectory', str(Path.home()), '--title', 'Choose storage for TrainerOS Setup')
            if choice.returncode: return 0
            parent = Path(choice.stdout.strip())
            if not parent.is_dir(): raise ValueError('Choose an existing storage folder')
            cache = parent / ('TrainerOS-download-' + plan['archive']['sha256'][:16])
            with installer.Progress() as progress:
                archive = assemble(args.manifest, args.sha256, cache, True, progress.update)
                target = unpack_setup(archive, cache / 'TrainerOS-Setup', progress.update)
            return subprocess.call([sys.executable, str(target / 'packaging/software/installer.py'), '--gui'],
                                   env={**os.environ, 'PYTHONDONTWRITEBYTECODE': '1'})
        else: result = {'archive': str(assemble(args.manifest, args.sha256, args.cache, args.command == 'fetch'))}
        print(json.dumps(result)); return 0
    except (OSError, ValueError, RuntimeError, KeyError, TypeError, tarfile.TarError) as error:
        if args.command == 'gui':
            import installer
            installer.dialog('--error', str(error) + '\nDownloaded parts are retained for retry.')
        else: print(str(error), file=sys.stderr)
        return 1


if __name__ == '__main__': raise SystemExit(main())
