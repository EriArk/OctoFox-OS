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


def build(archive, plan, output):
    archive, output = Path(archive), Path(output)
    if output.exists() or any(p.is_symlink() for p in output.parents):
        raise ValueError('Use a new non-redirected hybrid media file')
    if plan.get('schema') != 1 or not plan.get('components'):
        raise ValueError('Missing upstream delivery plan')
    fullbundle.verify(archive)
    replacements = {}; removed = set(); seen = set()
    with tarfile.open(archive, 'r:') as source:
        inventory = json.load(source.extractfile('fullbundle.json'))
        names = {r['path'] for r in inventory['files']}
        for spec in plan['components']:
            identity = spec['id']
            if identity in seen: raise ValueError('Duplicate upstream component')
            seen.add(identity)
            # Validate before constructing any path or accepting a repository.
            runtime_upstream.validate({'id': identity, 'delivery': spec['delivery'],
                'files': [{'path': identity + '.AppImage', 'mode': 0o755,
                           'bytes': spec['bytes'], 'sha256': spec['sha256']}]})
            prefix = 'runtimes/' + identity + '/'
            metadata = prefix + 'component.json'; payload = prefix + 'component.tar.gz'
            if metadata not in names or payload not in names:
                raise ValueError('Offline upstream component is missing')
            member = source.getmember(metadata)
            if member.size > 1024**2: raise ValueError('Oversized component metadata')
            record = json.load(source.extractfile(member))
            expected = [{'path': identity + '.AppImage', 'sha256': spec['sha256'],
                         'bytes': spec['bytes'], 'mode': 0o755}]
            actual = [dict(row) for row in record['files']]
            if len(actual) == 1 and actual[0].get('mode') in (0o644, 0o755):
                actual[0]['mode'] = 0o755
            if record['id'] != identity or actual != expected:
                raise ValueError('Upstream asset differs from selected runtime')
            payload_member = source.getmember(payload)
            with source.extractfile(payload_member) as stream:
                if (payload_member.size != record['archive']['bytes'] or
                        hashlib.file_digest(stream, 'sha256').hexdigest() != record['archive']['sha256']):
                    raise ValueError('Offline component archive identity differs')
            del record['archive']; record['delivery'] = spec['delivery']; record['files'] = expected
            runtime_upstream.validate(record)
            replacements[metadata] = (json.dumps(record, indent=2) + '\n').encode()
            removed.add(payload)
        inventory['files'] = [dict(row) for row in inventory['files'] if row['path'] not in removed]
        for row in inventory['files']:
            if row['path'] in replacements:
                blob = replacements[row['path']]
                row.update(bytes=len(blob), sha256=hashlib.sha256(blob).hexdigest())
        inventory['upstreamDownloads'] = sorted(seen)
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
            'sha256': fullbundle.payload.digest(output), 'upstreamDownloads': sorted(seen), 'published': False}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('archive', type=Path); parser.add_argument('--plan', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(build(args.archive, json.loads(args.plan.read_text()), args.output)))
