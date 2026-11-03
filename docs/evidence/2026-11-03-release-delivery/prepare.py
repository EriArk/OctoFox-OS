# SPDX-License-Identifier: GPL-3.0-or-later
"""Private staging verification; no publishing, installation or signing."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import sys
import tarfile

p = argparse.ArgumentParser()
p.add_argument('--code', type=Path, required=True)
p.add_argument('--hybrid', type=Path, required=True)
p.add_argument('--sources', type=Path, required=True)
p.add_argument('--output', type=Path, required=True)
p.add_argument('--resume-delivery', action='store_true')
a = p.parse_args()
sys.path.insert(0, str(a.code / 'packaging/software'))
import release_parts as parts
import source_archive as source

a.output.mkdir(exist_ok=True)
def save(name, value):
    (a.output / name).write_text(json.dumps(value, indent=2) + '\n')
    print(name, json.dumps(value), flush=True)
def digest(stream): return hashlib.file_digest(stream, 'sha256').hexdigest()

def prepare_candidate():
    original_source = a.hybrid / 'TrainerOS-2a6c9c9b-source.tar.gz'
    assert parts.sw.sha256(original_source) == 'f58ac54924f6e976ceb77b9bd744e7f61a8436fd295da3fd885726699e5c082b'
    filtered = a.output / 'TrainerOS-2a6c9c9b-software-source.tar.gz'
    save('software-source.json', source.build(original_source, filtered))

    old = a.hybrid / 'candidate-hybrid09/TrainerOS-Full-Setup-CANDIDATE.tar'
    assert parts.sw.sha256(old) == 'b8ea4951fafa5066d8d0bef1dc728055bd8f3d81938caa0fd41a21cb31fdce44'
    new = a.output / 'TrainerOS-Full-Setup-CANDIDATE.tar'
    replacement = 'TrainerOS-Setup/sources/traineros-source.tar.gz'
    records = []
    with tarfile.open(old) as incoming, tarfile.open(new, 'x:') as target:
        for member in incoming:
            if member.isfile():
                if member.name == replacement:
                    member.size = filtered.stat().st_size
                    with filtered.open('rb') as stream: target.addfile(member, stream)
                    sha = parts.sw.sha256(filtered)
                else:
                    with incoming.extractfile(member) as stream: sha = digest(stream)
                    with incoming.extractfile(member) as stream: target.addfile(member, stream)
                records.append({'name': member.name, 'bytes': member.size, 'sha256': sha})
            else:
                assert member.isdir(); target.addfile(member)
    assert sum(row['name'] == replacement for row in records) == 1
    with tarfile.open(new) as archive:
        for row in records:
            member = archive.getmember(row['name']); assert member.size == row['bytes']
            with archive.extractfile(member) as stream: assert digest(stream) == row['sha256']
    save('candidate.json', {'file': new.name, 'bytes': new.stat().st_size, 'sha256': parts.sw.sha256(new),
        'softwareSource': '2a6c9c9b00b58e914525bd779c76896c8fcf5006', 'runtimeSequence': 12,
        'changedMembers': [replacement], 'unchangedFiles': len(records) - 1,
        'allFilesReadBack': True, 'redistributionReviewed': False, 'published': False, 'installed': False})

    return new

if a.resume_delivery:
    record = json.loads((a.output / 'candidate.json').read_text())
    new = a.output / record['file']
    assert new.is_file() and parts.sw.sha256(new) == record['sha256']
    assert record['allFilesReadBack'] and record['changedMembers'] == ['TrainerOS-Setup/sources/traineros-source.tar.gz']
else:
    new = prepare_candidate()

if a.resume_delivery and (a.output / 'parts/parts.json').is_file():
    plan = parts.load(a.output / 'parts/parts.json', parts.sw.sha256(a.output / 'parts/parts.json'))
    assert plan['archive']['sha256'] == parts.sw.sha256(new)
else:
    plan = parts.split(new, a.output / 'parts', 'EriArk/TrainerOS', 'v0.1.0-prebeta.1')
pin = parts.sw.sha256(a.output / 'parts/parts.json')
joined = parts.assemble(a.output / 'parts/parts.json', pin, a.output / 'parts', progress=lambda *args: None)
assert parts.sw.sha256(joined) == parts.sw.sha256(new)
target = parts.unpack_setup(joined, a.output / 'extracted-Setup', progress=lambda *args: None)
assert parts.unpack_setup(joined, target, progress=lambda *args: None) == target
kit = parts.kit(a.output / 'parts', a.output / 'TrainerOS-Download-CANDIDATE.tar.gz')
save('delivery.json', {'archiveSha256': parts.sw.sha256(new), 'manifestSha256': pin, 'parts': plan['parts'],
    'allPartsUnder2GiB': all(row['size'] < parts.LIMIT for row in plan['parts']),
    'assembledArchiveMatches': True, 'fullSetupExtractedAndRetryVerified': True, 'kit': kit,
    'githubDownloadTested': False, 'installed': False, 'published': False})

rows = [json.loads((a.sources / 'output' / (name + '.json')).read_text())
        for name in ('azahar-appimage', 'melonds-appimage', 'rpcs3-appimage')]
supplement = a.output / 'TrainerOS-AppImage-Sources-02-CANDIDATE.tar'
inventory = []
with tarfile.open(supplement, 'x:') as archive:
    for row in rows:
        for name in (row['file'], row['id'] + '.json'):
            path = a.sources / 'output' / name; sha = parts.sw.sha256(path)
            if name == row['file']: assert sha == row['sha256']
            member = tarfile.TarInfo(name); member.size = path.stat().st_size; member.mode = 0o644
            with path.open('rb') as stream: archive.addfile(member, stream)
            inventory.append({'name': name, 'bytes': member.size, 'sha256': sha})
with tarfile.open(supplement) as archive:
    for row in inventory:
        with archive.extractfile(row['name']) as stream: assert digest(stream) == row['sha256']
save('source-supplement.json', {'file': supplement.name, 'bytes': supplement.stat().st_size,
    'sha256': parts.sw.sha256(supplement), 'files': inventory, 'allFilesReadBack': True,
    'sourceCapsules': 3, 'sourceTrees': sum(len(row['trees']) for row in rows),
    'completeRuntimeCorrespondingSource': False, 'redistributionReviewed': False, 'published': False})
