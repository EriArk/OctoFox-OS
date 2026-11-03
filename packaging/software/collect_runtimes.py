#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Collect an allowlisted installed runtime set without touching its installation.

Only run on a maintainer's ARM64 build machine. Outputs are candidates, not a
redistribution approval. Firmware requirements remain in manifests; firmware
bytes, accounts, emulator preferences and saved games are not collected.
"""
import argparse
import json
from pathlib import Path
import shutil
import tempfile

import runtime_payload as payload


def portable(value, home):
    home = Path(home).as_posix()
    if isinstance(value, dict): return {k: portable(v, home) for k, v in value.items()}
    if isinstance(value, list): return [portable(v, home) for v in value]
    if isinstance(value, str):
        if value == str(home): return '${HOME}'
        if value.startswith(str(home) + '/'): return '${HOME}' + value[len(str(home)):]
        if '/var/home/' in value or '/home/' in value:
            raise ValueError('Unreviewed machine-specific path in runtime manifest')
    return value


def collect(recipe, source, destination, home):
    source, destination = Path(source), Path(destination)
    destination.mkdir(parents=True, exist_ok=True)
    results = []
    for component in recipe['components']:
        identity = component['id']
        if len(payload.relative(identity).parts) != 1: raise ValueError('Invalid component id')
        output = destination / identity
        if output.exists(): raise ValueError('Use a new collection destination: ' + identity)
        root = (source / identity).resolve(strict=True)
        manifest = json.loads((root / 'manifest.json').read_text())
        for key, value in component.get('identity', {}).items():
            if manifest.get(key) != value:
                raise ValueError('Runtime identity changed since review: ' + identity + '/' + key)
        expected = component['expected']
        for name, checksum in expected.items():
            if payload.digest(root.joinpath(*payload.relative(name).parts)) != checksum:
                raise ValueError('Runtime changed since review: ' + identity + '/' + name)
        # Temporary staging lives beside the output (on the build disk), not /tmp.
        with tempfile.TemporaryDirectory(dir=destination, prefix='.stage-') as tmp:
            stage = Path(tmp)
            files = payload.selected(root, component['include'])
            for name, path in files.items():
                target = stage / name; target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(path, target); target.chmod(path.stat().st_mode & 0o777)
            # Installed manifests are templates where they refer to the home.
            # Their protocol/settings/hash identities are not rewritten.
            (stage / 'manifest.json').write_text(json.dumps(portable(manifest, home), indent=2) + '\n')
            metadata = {'source': manifest.get('source'), 'settings': manifest.get('settings'),
                        'requiredUserFiles': component.get('requiredUserFiles', []),
                        'manifestTemplate': True, 'recipeRevision': recipe['revision']}
            result = payload.build(stage, [*files, 'manifest.json'], output, identity, expected, metadata)
        results.append({'id': identity, 'archive': result['archive'], 'files': len(result['files'])})
        print(json.dumps(results[-1]), flush=True)
    (destination / 'collection.json').write_text(json.dumps({'schema': 1, 'components': results}, indent=2) + '\n')
    return results


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--recipe', type=Path, required=True)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    collect(json.loads(args.recipe.read_text()), args.source, args.output, Path.home())
