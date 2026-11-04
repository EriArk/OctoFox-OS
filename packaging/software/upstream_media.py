# SPDX-License-Identifier: GPL-3.0-or-later
"""Replace selected offline payloads with exact upstream descriptors, not binaries."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import tarfile
import fullbundle
import runtime_upstream
import runtime_flathub
import runtime_vita_upstream


def build(archive, plan, output):
    archive, output = Path(archive), Path(output)
    if output.exists() or any(p.is_symlink() for p in output.parents):
        raise ValueError('Use a new non-redirected hybrid media file')
    if plan.get('schema') != 1 or not (plan.get('components') or plan.get('flatpak') or plan.get('vita')):
        raise ValueError('Missing upstream delivery plan')
    fullbundle.verify(archive)
    replacements = {}; removed = set(); seen = set()
    with tarfile.open(archive, 'r:') as source:
        inventory = json.load(source.extractfile('fullbundle.json'))
        names = {r['path'] for r in inventory['files']}
        for spec in plan.get('components', []):
            identity = spec['id']
            if identity in seen: raise ValueError('Duplicate upstream component')
            seen.add(identity)
            # Validate before constructing any path or accepting a repository.
            runtime_upstream.validate({'id': identity, 'delivery': spec['delivery'],
                'files': [{'path': identity + '.AppImage', 'mode': 0o755,
                           'bytes': spec['bytes'], 'sha256': spec['sha256']}]})
            prefix = 'runtimes/' + identity + '/'
            metadata = prefix + 'component.json'; payload = prefix + 'component.tar.gz'
            if metadata not in names:
                raise ValueError('Offline upstream component is missing')
            member = source.getmember(metadata)
            if member.size > 1024**2: raise ValueError('Oversized component metadata')
            record = json.load(source.extractfile(member))
            expected = [{'path': identity + '.AppImage', 'sha256': spec['sha256'],
                         'bytes': spec['bytes'], 'mode': 0o755}]
            actual = [dict(row) for row in record['files']]
            if len(actual) == 1 and actual[0].get('mode') in (0o644, 0o755):
                actual[0]['mode'] = 0o755
            previous = spec.get('replaces')
            old_expected = ([{'path': identity + '.AppImage', 'sha256': previous['sha256'],
                              'bytes': previous['bytes'], 'mode': 0o755}] if previous else expected)
            if record['id'] != identity or actual != old_expected:
                raise ValueError('Upstream asset differs from selected runtime')
            if 'delivery' in record:
                if previous or record['delivery'] != spec['delivery'] or payload in names:
                    raise ValueError('Existing upstream descriptor differs')
                runtime_upstream.validate(record)
                continue
            if payload not in names: raise ValueError('Offline upstream component is missing')
            payload_member = source.getmember(payload)
            with source.extractfile(payload_member) as stream:
                if (payload_member.size != record['archive']['bytes'] or
                        hashlib.file_digest(stream, 'sha256').hexdigest() != record['archive']['sha256']):
                    raise ValueError('Offline component archive identity differs')
            del record['archive']; record['delivery'] = spec['delivery']; record['files'] = expected
            runtime_upstream.validate(record)
            replacements[metadata] = (json.dumps(record, indent=2) + '\n').encode()
            removed.add(payload)
        if plan.get('flatpak'):
            spec = plan['flatpak']; key = Path(spec['keyFile'])
            if key.is_symlink() or not key.is_file() or key.stat().st_size > 65536:
                raise ValueError('Invalid Flathub signing key input')
            blob = key.read_bytes()
            if hashlib.sha256(blob).hexdigest() != spec['keySha256']:
                raise ValueError('Flathub signing key input changed')
            refs = set(spec['refs'])
            if len(refs) != len(spec['refs']) or not refs or not refs <= runtime_flathub.REFS:
                raise ValueError('Unreviewed Flathub reference set')
            metadata = 'flatpak/flatpak-lock.json'
            lock = json.load(source.extractfile(metadata)); found = set()
            for row in lock['refs']:
                if row['ref'] not in refs: continue
                if 'delivery' in row: raise ValueError('Flatpak already uses upstream delivery')
                row['delivery'] = {'kind': 'flathub-commit', 'keySha256': spec['keySha256']}
                runtime_flathub.validate(row)
                payload = 'flatpak/' + row['file']
                if payload not in names: raise ValueError('Selected Flatpak bundle is missing')
                member = source.getmember(payload)
                with source.extractfile(member) as stream:
                    if member.size != row['bytes'] or hashlib.file_digest(stream, 'sha256').hexdigest() != row['sha256']:
                        raise ValueError('Selected Flatpak bundle changed')
                removed.add(payload); found.add(row['ref'])
            if found != refs: raise ValueError('Selected Flatpak reference is absent')
            replacements[metadata] = (json.dumps(lock, indent=2) + '\n').encode()
            keyname = 'flatpak/flathub.gpg'
            if keyname in names: raise ValueError('Flathub key already exists in media')
            replacements[keyname] = blob
            inventory['files'].append({'path': keyname, 'bytes': len(blob), 'sha256': spec['keySha256']})
            seen.update(refs)
        if plan.get('vita'):
            if plan['vita'] != runtime_vita_upstream.SPEC:
                raise ValueError('Unreviewed Vita upstream plan')
            prefix = 'runtimes/vita3k-netplay/'
            record = json.load(source.extractfile(prefix + 'component.json'))
            if 'upstreamRuntime' in record: raise ValueError('Vita already uses upstream delivery')
            record['upstreamRuntime'] = plan['vita']
            external = {r['path'] for r in runtime_vita_upstream.rows(record)}
            expected = {r['path']: r for r in record['files']}; found = set()
            blob = io.BytesIO()
            with tarfile.open(fileobj=source.extractfile(prefix + 'component.tar.gz')) as old:
                with tarfile.open(fileobj=blob, mode='w:gz', compresslevel=3) as new:
                    for member in old:
                        if not member.isfile() or member.name not in expected or member.name in found:
                            raise ValueError('Unexpected Vita component entry')
                        row = expected[member.name]; data = old.extractfile(member).read()
                        if len(data) != row['bytes'] or hashlib.sha256(data).hexdigest() != row['sha256']:
                            raise ValueError('Vita component input changed')
                        found.add(member.name)
                        if member.name not in external: new.addfile(member, io.BytesIO(data))
            if found != set(expected): raise ValueError('Incomplete Vita component')
            packed = blob.getvalue()
            record['archive'] = {'bytes': len(packed), 'sha256': hashlib.sha256(packed).hexdigest()}
            replacements[prefix + 'component.tar.gz'] = packed
            replacements[prefix + 'component.json'] = (json.dumps(record, indent=2) + '\n').encode()
            seen.add('vita3k-netplay')
        inventory['files'] = [dict(row) for row in inventory['files'] if row['path'] not in removed]
        for row in inventory['files']:
            if row['path'] in replacements:
                blob = replacements[row['path']]
                row.update(bytes=len(blob), sha256=hashlib.sha256(blob).hexdigest())
        inventory['upstreamDownloads'] = sorted(set(inventory.get('upstreamDownloads', [])) | seen)
        with tarfile.open(output, 'x:') as target:
            blob = (json.dumps(inventory, indent=2) + '\n').encode()
            member = tarfile.TarInfo('fullbundle.json'); member.size = len(blob); member.mode = 0o644
            target.addfile(member, io.BytesIO(blob))
            for row in inventory['files']:
                member = tarfile.TarInfo(row['path']); member.size = row['bytes']; member.mode = 0o644
                if row['path'] in replacements:
                    target.addfile(member, io.BytesIO(replacements[row['path']]))
                else:
                    with source.extractfile(row['path']) as stream: target.addfile(member, stream)
    result = fullbundle.verify(output)
    return {**result, 'file': output.name, 'archiveBytes': output.stat().st_size,
            'sha256': fullbundle.payload.digest(output), 'upstreamDownloads': inventory['upstreamDownloads'], 'published': False}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('archive', type=Path); parser.add_argument('--plan', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    plan = json.loads(args.plan.read_text())
    if plan.get('flatpak'):
        key = Path(plan['flatpak']['keyFile'])
        if not key.is_absolute(): plan['flatpak']['keyFile'] = str(args.plan.parent / key)
    print(json.dumps(build(args.archive, plan, args.output)))
