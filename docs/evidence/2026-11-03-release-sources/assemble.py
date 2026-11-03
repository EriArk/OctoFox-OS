"""Assemble the retained source-review candidate; never installs or publishes it."""
from pathlib import Path
import argparse
import hashlib
import io
import json
import tarfile


def digest(path):
    with path.open('rb') as stream: return hashlib.file_digest(stream, 'sha256').hexdigest()


def build(root):
    index = json.loads((root / 'source-capsules.json').read_text())
    assert index['sourceCapsules'] == 22 and len(index['capsules']) == 22
    files = []
    def add(path, name, expected=None):
        assert path.is_file() and not path.is_symlink()
        sha = digest(path)
        if expected: assert sha == expected, name
        files.append((path, {'path': name, 'bytes': path.stat().st_size, 'sha256': sha}))
    add(root / 'source-capsules.json', 'source-capsules.json')
    for row in index['capsules']:
        add(root / 'output' / row['file'], 'upstream/' + row['file'], row['sha256'])
        add(root / 'output' / (row['id'] + '.json'), 'upstream/' + row['id'] + '.json')
    add(root / 'incoming/TrainerOS-Python-Notices-CANDIDATE.tar.gz',
        'TrainerOS-Python-Notices-CANDIDATE.tar.gz', '98f4234b4edeef9f2ce792bd7c2653ebc811e00557d874b47f4bae47fa92460b')
    add(root / 'incoming/runtime-recipes-369e4087.tar.gz', 'runtime-recipes-369e4087.tar.gz',
        'b384024b70d3e60d469b9e75970412a6edd5ce40f5f24a2a51437df23885ba0e')
    record = {'schema': 1, 'product': 'traineros-source-review-candidate',
              'recipeCommit': '369e40872d504c4a215195d3e9d7e6d065f0ceab',
              'files': [row for _, row in files], 'completeRuntimeCorrespondingSource': False,
              'redistributionReviewed': False, 'published': False}
    output = root / 'TrainerOS-Sources-CANDIDATE.tar'
    with tarfile.open(output, 'x:') as tar:
        manifest = (json.dumps(record, indent=2) + '\n').encode()
        info = tarfile.TarInfo('sources.json'); info.size = len(manifest); info.mode = 0o644
        tar.addfile(info, io.BytesIO(manifest))
        for path, row in files:
            info = tarfile.TarInfo(row['path']); info.size = row['bytes']; info.mode = 0o644
            with path.open('rb') as stream: tar.addfile(info, stream)
    # Read the whole output independently, verifying content rather than just its size.
    with tarfile.open(output) as tar:
        manifest = json.load(tar.extractfile('sources.json'))
        assert manifest == record
        assert len(tar.getmembers()) == len(files) + 1
        for row in manifest['files']:
            member = tar.getmember(row['path']); assert member.isfile() and member.size == row['bytes']
            with tar.extractfile(member) as stream:
                assert hashlib.file_digest(stream, 'sha256').hexdigest() == row['sha256']
    result = {k: v for k, v in record.items() if k != 'files'}
    result.update(file=output.name, bytes=output.stat().st_size, sha256=digest(output),
                  files=len(files) + 1, allEntriesReadBack=True)
    (root / 'source-bundle.json').write_text(json.dumps(result, indent=2) + '\n')
    (root / 'SOURCE-SHA256SUMS').write_text(result['sha256'] + '  ' + output.name + '\n')
    print(json.dumps(result))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument('staging', type=Path)
    build(parser.parse_args().staging)
