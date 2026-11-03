# SPDX-License-Identifier: GPL-3.0-or-later
"""Package verified Python source and notices from the actual runtime media.

No runtime is executed or installed. This supplement explicitly leaves native
transitive source and redistribution review open. Output is for release staging.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path
import tarfile
import zipfile

from source_capsule import relative
from release_inventory import notice


def digest(path):
    with path.open('rb') as stream: return hashlib.file_digest(stream, 'sha256').hexdigest()


def build(media, sources, source_index, supplement, output):
    media, sources, source_index, supplement, output = map(Path, (media, sources, source_index, supplement, output))
    index = json.loads(source_index.read_text())
    expected = {}
    for row in index['sources']:
        name = relative(row['sourceFile'])
        if '/' in name or name in expected or row['sourceStatus'] != 'downloaded-verified' or row['wheelMatchesPyPI'] is not True:
            raise ValueError('Invalid verified Python source index')
        path = sources / name
        if path.is_symlink() or not path.is_file() or path.stat().st_size != row['sourceBytes'] or digest(path) != row['sourceSha256']:
            raise ValueError('Python source changed: ' + name)
        expected[name] = row
    wheels = {}
    for path in sorted((media / 'python/wheels').glob('*.whl')):
        if path.is_symlink(): raise ValueError('Linked wheel')
        sha = digest(path)
        if sha in wheels: raise ValueError('Duplicate wheel')
        wheels[sha] = path
    if set(wheels) != {row['wheelSha256'] for row in expected.values()}:
        raise ValueError('Source list does not match distributed wheels')
    if output.exists() or output.is_symlink(): raise ValueError('Output already exists')
    entries, names = [], set()
    temp = output.with_suffix('.partial')
    if temp.exists() or temp.is_symlink(): raise ValueError('Existing partial source material retained')
    try:
        with tarfile.open(temp, 'x:gz') as tar:
            def add(name, blob):
                name = relative(name)
                if name in names: raise ValueError('Duplicate source material')
                if len(blob) > 128 * 1024**2: raise ValueError('Oversized source material')
                info = tarfile.TarInfo(name); info.size = len(blob); info.mode = 0o644
                tar.addfile(info, io.BytesIO(blob)); names.add(name)
                entries.append({'path': name, 'bytes': len(blob), 'sha256': hashlib.sha256(blob).hexdigest()})
            for name in sorted(expected): add('python/sources/' + name, (sources / name).read_bytes())
            add('python/source-index.json', source_index.read_bytes())
            for sha, path in sorted(wheels.items()):
                with zipfile.ZipFile(path) as wheel:
                    seen = set()
                    for item in wheel.infolist():
                        if item.filename in seen: raise ValueError('Duplicate wheel path')
                        seen.add(item.filename)
                        if not item.is_dir() and (notice(item.filename) or item.filename.endswith('.dist-info/METADATA')):
                            if item.file_size > 8 * 1024**2: raise ValueError('Oversized wheel notice')
                            add('python/notices/' + path.name + '/' + relative(item.filename), wheel.read(item))
            for manifest in sorted((media / 'runtimes').glob('*/component.json')):
                component = json.loads(manifest.read_text()); component_id = relative(component['id'])
                if '/' in component_id: raise ValueError('Invalid component ID')
                archive = manifest.parent / 'component.tar.gz'
                if archive.is_symlink() or digest(archive) != component['archive']['sha256']:
                    raise ValueError('Runtime component changed: ' + component_id)
                with tarfile.open(archive) as source:
                    for item in source:
                        if item.isfile() and (notice(item.name) or 'source-patches/' in item.name or item.name.endswith('.patch')):
                            if item.size > 8 * 1024**2: raise ValueError('Oversized native notice/patch')
                            add('runtime/notices/' + component_id + '/' + relative(item.name), source.extractfile(item).read())
            for path in sorted(supplement.rglob('*')):
                if path.is_symlink(): raise ValueError('Linked supplemental notice')
                if path.is_file(): add('supplemental-notices/' + path.relative_to(supplement).as_posix(), path.read_bytes())
            record = {'schema': 1, 'scope': 'verified Python sources and runtime notice/patch files',
                      'pythonSources': len(expected), 'wheels': len(wheels), 'files': entries,
                      'nativeCorrespondingSourceComplete': False, 'redistributionReviewed': False}
            add('materials.json', (json.dumps(record, indent=2) + '\n').encode())
        temp.replace(output)
    except BaseException:
        if temp.exists(): temp.unlink()
        raise
    return {'file': output.name, 'bytes': output.stat().st_size, 'sha256': digest(output),
            'pythonSources': len(expected), 'files': len(names), 'redistributionReviewed': False}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    for key in ('media', 'sources', 'source-index', 'supplement', 'output'): parser.add_argument('--' + key, type=Path, required=True)
    args = parser.parse_args(); print(json.dumps(build(args.media, args.sources, args.source_index, args.supplement, args.output)))
