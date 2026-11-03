# SPDX-License-Identifier: GPL-3.0-or-later
"""Read retained AppImage/ELF bytes; never execute emulator code or shadow inspect."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import tarfile

p = argparse.ArgumentParser(); p.add_argument('staging', type=Path); p.add_argument('output', type=Path)
a = p.parse_args(); rows = []
identities = [
    ('Azahar-Enhanced', 'shared/bin/azahar', 'd162991403ff3a77ed623b6dd29b5074c4f45819',
     'azahar-emu/azahar', 'd162991403ff3a77ed623b6dd29b5074c4f45819'),
    ('melonDS', 'usr/bin/melonDS', 'Commit: 12891b6d064171e8a70c7ef146b9ba068d702b26',
     'melonDS-emu/melonDS', '12891b6d064171e8a70c7ef146b9ba068d702b26'),
    ('rpcs3', 'usr/bin/rpcs3', '20291-ffba2bf0',
     'RPCS3/rpcs3', 'ffba2bf09ef3980638f9327b25240d81414034ab'),
]
for name, binary, marker, repo, revision in identities:
    image = a.staging / 'appimage-inspection' / (name + '.AppImage')
    if name == 'melonDS':
        meta = next(row for row in json.loads((a.staging / 'appimage-source-metadata.json').read_text()) if row['id'] == name)
        raw = subprocess.check_output(['unsquashfs', '-cat', '-o', str(meta['squashfsOffset']), str(image), binary])
    else:
        with tarfile.open(a.staging / 'appimage-inspection' / (name + '.dwarfs.tar')) as archive:
            raw = archive.extractfile(binary).read()
    assert raw.startswith(b'\x7fELF') and marker.encode() in raw
    with image.open('rb') as stream: image_hash = hashlib.file_digest(stream, 'sha256').hexdigest()
    rows.append({'id': name, 'appImageSha256': image_hash, 'elfPath': binary, 'elfBytes': len(raw),
                 'elfSha256': hashlib.sha256(raw).hexdigest(), 'marker': marker, 'markerOffset': raw.index(marker.encode()),
                 'repository': 'https://github.com/' + repo + '.git', 'commit': revision,
                 'upstreamCommitUrl': 'https://github.com/' + repo + '/commit/' + revision,
                 'exactBuildRecipeAndDependenciesReviewed': False, 'redistributionReviewed': False})
a.output.write_text(json.dumps({'schema': 1, 'method': 'Read ELF marker, resolve exact upstream commit, collect pinned source with gitlinks.',
                               'components': rows}, indent=2) + '\n')
print('Verified embedded identities:', len(rows))
