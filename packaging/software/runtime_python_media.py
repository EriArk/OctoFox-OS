# SPDX-License-Identifier: GPL-3.0-or-later
"""Rebind candidate media to an explicitly tested Armada interpreter.

Build-time only: never changes installed files or relaxes runtime identity checks.
The caller must validate the unchanged offline wheels on the selected ARM host.
"""
import hashlib
import io
import json
from pathlib import Path
import re
import tarfile
import fullbundle
import runtime_set

NATIVE = {'azahar-netplay', 'melonds-netplay', 'rmg-netplay', 'vita3k-netplay'}


def encoded(value):
    return (json.dumps(value, indent=2) + '\n').encode()


def identity(blob):
    return {'bytes': len(blob), 'sha256': hashlib.sha256(blob).hexdigest()}


def replace(archive, expected, plan, output):
    archive, output = Path(archive), Path(output)
    if (output.exists() or output.is_symlink() or any(p.is_symlink() for p in output.parents)
            or archive.is_symlink() or archive.stat().st_size != expected['bytes']
            or fullbundle.payload.digest(archive) != expected['sha256']):
        raise ValueError('Use pinned input and a new non-redirected output')
    if (set(plan) != {'schema', 'previousSha256', 'pythonSha256', 'pythonVersion', 'host'}
            or plan['schema'] != 1
            or not all(isinstance(plan[k], str) and re.fullmatch(r'[a-f0-9]{64}', plan[k])
                       for k in ('previousSha256', 'pythonSha256'))
            or plan['previousSha256'] == plan['pythonSha256']
            or not re.fullmatch(r'Python 3\.\d+\.\d+', plan['pythonVersion'])):
        raise ValueError('An explicit reviewed interpreter replacement is required')
    fullbundle.verify(archive)
    with tarfile.open(archive) as source:
        index = json.load(source.extractfile('fullbundle.json'))
        locks = json.load(source.extractfile('python/interpreters.json'))
        if set(locks) != runtime_set.ENVIRONMENTS:
            raise ValueError('Incomplete Python environment set')
        for spec in locks.values():
            if spec['pythonSha256'] != plan['previousSha256']:
                raise ValueError('Previous Python identity differs')
            spec.update(pythonSha256=plan['pythonSha256'], pythonVersion=plan['pythonVersion'])
        replacements = {'python/interpreters.json': encoded(locks)}
        for name in sorted(NATIVE):
            prefix = 'runtimes/' + name + '/'
            record = json.load(source.extractfile(prefix + 'component.json'))
            inventory = {r['path']: r for r in record['files']}
            if record['id'] != name or len(inventory) != len(record['files']):
                raise ValueError('Invalid native runtime inventory')
            original = source.extractfile(prefix + 'component.tar.gz').read()
            if identity(original) != record['archive']:
                raise ValueError('Native runtime archive differs')
            manifest_row = inventory['manifest.json']
            output_blob = io.BytesIO(); seen = set()
            with tarfile.open(fileobj=io.BytesIO(original)) as old:
                with tarfile.open(fileobj=output_blob, mode='w:gz', compresslevel=3) as new:
                    for member in old:
                        if not member.isfile() or member.name not in inventory or member.name in seen:
                            raise ValueError('Unexpected native runtime entry')
                        blob = old.extractfile(member).read(); row = inventory[member.name]
                        if identity(blob) != {k: row[k] for k in ('bytes', 'sha256')}:
                            raise ValueError('Native runtime content differs')
                        seen.add(member.name)
                        if member.name == 'manifest.json':
                            manifest = json.loads(blob)
                            if manifest['interpreterSha256'] != plan['previousSha256']:
                                raise ValueError('Native interpreter identity differs')
                            manifest['interpreterSha256'] = plan['pythonSha256']
                            blob = encoded(manifest); manifest_row.update(identity(blob))
                            member.size = len(blob)
                        new.addfile(member, io.BytesIO(blob))
            if seen != set(inventory): raise ValueError('Incomplete native runtime')
            blob = output_blob.getvalue(); record['archive'] = identity(blob)
            replacements[prefix + 'component.tar.gz'] = blob
            replacements[prefix + 'component.json'] = encoded(record)
        for row in index['files']:
            if row['path'] in replacements: row.update(identity(replacements[row['path']]))
        index['redistributionReviewed'] = False
        index['installerAcceptance'] = False
        with tarfile.open(output, 'x:') as target:
            blob = encoded(index); member = tarfile.TarInfo('fullbundle.json')
            member.size = len(blob); member.mode = 0o644; target.addfile(member, io.BytesIO(blob))
            for row in index['files']:
                member = tarfile.TarInfo(row['path']); member.size = row['bytes']; member.mode = 0o644
                with (io.BytesIO(replacements[row['path']]) if row['path'] in replacements
                      else source.extractfile(row['path'])) as stream:
                    target.addfile(member, stream)
    fullbundle.verify(output)
    return {'bytes': output.stat().st_size, 'sha256': fullbundle.payload.digest(output),
            'changedPaths': sorted(replacements), 'published': False}
