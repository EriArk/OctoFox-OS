# SPDX-License-Identifier: GPL-3.0-or-later
"""Read a full bundle's manifest/notice inventory without installing or approving it.

Hashes identify the already verified candidate's artifacts. A source revision or
an embedded licence filename alone does not prove Corresponding Source delivery.
No executable, AppImage or Flatpak from the input is run.
"""
import argparse
from email.parser import BytesParser
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import tarfile
import zipfile


def notice(name):
    return any(word in PurePosixPath(name).name.lower() for word in ('license', 'licence', 'copying', 'notice', 'copyright'))


def inspect(archive):
    components, wheels, source_archives = [], [], []
    with tarfile.open(archive, 'r:') as outer:
        def read(member, maximum):
            if not member.isfile() or member.size > maximum:
                raise ValueError('Invalid or oversized inventory member')
            return outer.extractfile(member).read()
        members = outer.getmembers()
        names = [member.name for member in members]
        if len(names) != len(set(names)): raise ValueError('Duplicate bundle entries')
        for member in members:
            name = member.name
            if name.startswith('runtimes/') and name.endswith('/component.json'):
                data = json.loads(read(member, 8 * 1024**2))
                files = data['files']
                row = {'id': data['id'], 'archive': data['archive'],
                       'declaredSource': data.get('metadata', {}).get('source'),
                       'noticeFiles': [item['path'] for item in files if notice(item['path'])],
                       'patchFiles': [item['path'] for item in files if 'patch' in item['path'].lower()],
                       'correspondingSourceVerified': False}
                if data['id'] == 'retroarch-cores':
                    row['cores'] = [{'path': item['path'], 'sha256': item['sha256']} for item in files if item['path'].endswith('.so')]
                components.append(row)
            elif name.startswith('python/wheels/') and name.endswith('.whl'):
                blob = read(member, 128 * 1024**2)
                with zipfile.ZipFile(io.BytesIO(blob)) as wheel:
                    metadata = [info for info in wheel.infolist() if info.filename.endswith('.dist-info/METADATA')]
                    if len(metadata) != 1 or metadata[0].file_size > 1024**2:
                        raise ValueError('Missing or oversized wheel metadata')
                    headers = BytesParser().parsebytes(wheel.read(metadata[0]))
                    wheels.append({'file': PurePosixPath(name).name, 'sha256': hashlib.sha256(blob).hexdigest(),
                                   'name': headers.get('Name'), 'version': headers.get('Version'),
                                   'declaredLicense': headers.get('License-Expression') or headers.get('License'),
                                   'licenseClassifiers': [v for v in headers.get_all('Classifier', []) if v.startswith('License ::')],
                                   'noticeFiles': [info.filename for info in wheel.infolist() if notice(info.filename)],
                                   'redistributionReviewed': False})
            elif name.startswith('sources/'):
                source_archives.append({'path': name, 'bytes': member.size})
        lock = json.loads(read(outer.getmember('flatpak/flatpak-lock.json'), 1024**2))
    return {'schema': 1, 'scope': 'manifest and embedded wheel metadata; no execution or new gameplay check',
            'components': sorted(components, key=lambda row: row['id']),
            'flatpak': lock['refs'], 'wheels': sorted(wheels, key=lambda row: row['name']),
            'sourceArchives': source_archives, 'redistributionReviewed': False,
            'remaining': ['Match each distributed binary to exact upstream source, patches and build dependencies',
                          'Provide applicable complete notices and corresponding source for cores, AppImages and Flatpak',
                          'Review avatar incorporated distribution separately from software licences']}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('archive', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    record = inspect(args.archive)
    with args.output.open('x', encoding='utf-8') as stream:
        json.dump(record, stream, ensure_ascii=False, indent=2)
        stream.write('\n')
    print(json.dumps({'components': len(record['components']), 'flatpak': len(record['flatpak']),
                      'wheels': len(record['wheels']), 'redistributionReviewed': False}))
