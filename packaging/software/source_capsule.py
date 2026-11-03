# SPDX-License-Identifier: GPL-3.0-or-later
"""Collect pinned Git source, including gitlinks, without checkout or execution.

This supplies upstream source, not a claim that every distributed binary has
complete Corresponding Source. Build recipes, patches and external dependencies
must be matched separately. No upstream hook, build or submodule command is run.
"""
import argparse
import gzip
import hashlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import re
import subprocess
import tarfile
import tempfile
import urllib.parse
import urllib.request

HOSTS = {'github.com', 'gitlab.com', 'gitlab.freedesktop.org'}


def revision(value):
    if not isinstance(value, str) or not re.fullmatch('[0-9a-f]{40}', value):
        raise ValueError('A full pinned Git commit is required')
    return value


def repository(value, parent=None):
    if parent and value.startswith(('./', '../')):
        value = urllib.parse.urljoin(parent.rstrip('/') + '/', value)
    u = urllib.parse.urlsplit(value)
    if (u.scheme != 'https' or u.hostname not in HOSTS or u.username or u.password
            or u.port or u.query or u.fragment or not re.fullmatch(r'/[A-Za-z0-9_.\-/]+', u.path)
            or any(p in ('.', '..') for p in u.path.split('/'))):
        raise ValueError('Unsupported source repository URL')
    return value


def relative(value):
    p = PurePosixPath(value)
    if not value or p.is_absolute() or '\\' in value or any(x in ('', '.', '..', '.git') for x in value.split('/')):
        raise ValueError('Unsafe source path')
    return p.as_posix()


def git(repo, *args):
    env = {**os.environ, 'GIT_TERMINAL_PROMPT': '0', 'GIT_CONFIG_NOSYSTEM': '1',
           'GIT_CONFIG_GLOBAL': os.devnull, 'GIT_LFS_SKIP_SMUDGE': '1'}
    return subprocess.run(['git', '-c', 'core.hooksPath=' + os.devnull,
                           '-c', 'protocol.allow=never', '-c', 'protocol.https.allow=always',
                           '-C', str(repo), *args], env=env, check=True,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=900).stdout


def fetch(cache, url, commit):
    repository(url); revision(commit)
    name = hashlib.sha256(url.encode()).hexdigest()[:24]
    target = cache / name
    if not target.exists():
        target.mkdir()
        git(target, 'init', '--bare', '--template=')
    if target.is_symlink(): raise ValueError('Symlink source cache')
    try:
        got = git(target, 'rev-parse', '--verify', commit + '^{commit}').decode().strip()
    except subprocess.CalledProcessError:
        git(target, 'fetch', '--depth=1', '--no-tags', url, commit)
        got = git(target, 'rev-parse', '--verify', commit + '^{commit}').decode().strip()
    if got != commit: raise ValueError('Source commit mismatch')
    # Archive every tracked file, including files upstream marks export-ignore.
    # This local override is never included in the source archive.
    (target / 'info').mkdir(exist_ok=True)
    (target / 'info/attributes').write_text('* -export-ignore -export-subst\n')
    return target


def modules(repo, commit):
    entries = git(repo, 'ls-tree', '-rz', commit).split(b'\0')
    links = {}
    for entry in entries:
        if not entry: continue
        head, name = entry.split(b'\t', 1)
        mode, kind, obj = head.decode().split()
        if mode == '160000': links[relative(name.decode())] = revision(obj)
    if not links: return {}
    data = git(repo, 'show', commit + ':.gitmodules')
    with tempfile.NamedTemporaryFile(delete=False) as f:
        f.write(data); config = Path(f.name)
    try:
        fields = git(repo, 'config', '--null', '--file', str(config), '--get-regexp', r'^submodule\..*\.(path|url)$')
    finally: config.unlink()
    groups = {}
    for item in fields.split(b'\0'):
        if not item: continue
        key, value = item.decode().split('\n', 1)
        section, field = key.rsplit('.', 1)
        if field in groups.setdefault(section, {}): raise ValueError('Duplicate submodule field')
        groups[section][field] = value
    mapped = {}
    for row in groups.values():
        path = relative(row['path'])
        if path in mapped: raise ValueError('Duplicate submodule path')
        mapped[path] = row['url']
    if not set(links) <= set(mapped): raise ValueError('Unmapped gitlink')
    return {path: (mapped[path], sha) for path, sha in links.items()}


def lfs_object(remote, sha, path, size):
    u = urllib.parse.urlsplit(repository(remote))
    if u.hostname != 'github.com': raise ValueError('LFS download needs a reviewed provider')
    repo_path = u.path.removesuffix('.git')
    url = 'https://media.githubusercontent.com/media' + repo_path + '/' + revision(sha) + '/' + urllib.parse.quote(relative(path), safe='/')
    with urllib.request.urlopen(url, timeout=90) as response:
        data = response.read(size + 1)
    return data


def collect(spec, output, cache, fetcher=fetch, lfs_fetcher=lfs_object):
    name = spec['id']
    if not re.fullmatch('[a-z0-9][a-z0-9_-]{0,79}', name): raise ValueError('Invalid source ID')
    url, commit = repository(spec['repository']), revision(spec['commit'])
    output.mkdir(parents=True, exist_ok=True); cache.mkdir(parents=True, exist_ok=True)
    target = output / (name + '-' + commit + '.tar.gz')
    record = output / (name + '.json')
    if target.exists() or target.is_symlink() or record.exists() or record.is_symlink():
        raise ValueError('Use a new output or retain the verified existing capsule')
    trees, seen, notices, lfs, external_links = [], set(), [], [], []
    total = 0
    def append(tar, remote, sha, prefix, ancestry):
        nonlocal total
        if len(ancestry) > 12 or len(trees) >= 300 or (remote, sha) in ancestry:
            raise ValueError('Recursive or oversized source dependency graph')
        repo = fetcher(cache, remote, sha)
        actual = git(repo, 'rev-parse', sha + '^{commit}').decode().strip()
        if actual != sha: raise ValueError('Fetched source revision mismatch')
        tree = git(repo, 'rev-parse', sha + '^{tree}').decode().strip()
        trees.append({'path': prefix or '.', 'repository': remote, 'commit': sha, 'tree': tree})
        # A temporary tar avoids holding large upstream archives in memory.
        with tempfile.TemporaryFile() as raw:
            env = {**os.environ, 'GIT_CONFIG_NOSYSTEM': '1', 'GIT_CONFIG_GLOBAL': os.devnull}
            subprocess.run(['git', '-C', str(repo), 'archive', '--format=tar', sha],
                           env=env, stdout=raw, stderr=subprocess.PIPE, check=True, timeout=300)
            raw.seek(0)
            with tarfile.open(fileobj=raw, mode='r:') as source:
                for item in source:
                    if item.isdir(): continue
                    path = relative(prefix + item.name)
                    if path in seen or len(seen) >= 500000: raise ValueError('Duplicate or excessive source entries')
                    if not (item.isfile() or item.issym()): raise ValueError('Unexpected source entry type')
                    if item.size > 256 * 1024**2: raise ValueError('Oversized source file')
                    total += item.size
                    if total > 4 * 1024**3: raise ValueError('Oversized source capsule')
                    if item.issym():
                        # Preserve source links as tar metadata; never dereference
                        # them. EDK2, for example, contains a macOS SDK include
                        # link. Record external targets for extraction review.
                        resolved = PurePosixPath(path).parent
                        external = item.linkname.startswith('/') or '\\' in item.linkname
                        depth = len(resolved.parts)
                        for part in item.linkname.split('/'):
                            depth += -1 if part == '..' else (0 if part in ('', '.') else 1)
                            if depth < 0: external = True
                        if external: external_links.append({'path': path, 'target': item.linkname})
                    stream = source.extractfile(item) if item.isfile() else None
                    if stream and item.size < 1024:
                        data = stream.read(); stream = io.BytesIO(data)
                        if data.splitlines()[:1] == [b'version https://git-lfs.github.com/spec/v1']:
                            pointer = re.fullmatch(rb'version https://git-lfs.github.com/spec/v1\r?\noid sha256:([0-9a-f]{64})\r?\nsize ([0-9]+)\r?\n?', data)
                            if not pointer: raise ValueError('Unresolved Git LFS pointer: ' + path)
                            oid, size = pointer[1].decode(), int(pointer[2])
                            if size > 512 * 1024**2 or total - item.size + size > 4 * 1024**3:
                                raise ValueError('Oversized Git LFS source')
                            blob = lfs_fetcher(remote, sha, item.name, size)
                            if len(blob) != size or hashlib.sha256(blob).hexdigest() != oid:
                                raise ValueError('Git LFS source hash/size mismatch: ' + path)
                            total += size - item.size; item.size = size; stream = io.BytesIO(blob)
                            lfs.append({'path': path, 'sha256': oid, 'bytes': size})
                    if any(x in PurePosixPath(path).name.lower() for x in ('license', 'licence', 'copying', 'notice', 'copyright')):
                        notices.append(path)
                    item.name = name + '/' + path; item.uid = item.gid = 0
                    item.uname = item.gname = ''; item.mtime = 0; item.pax_headers = {}
                    tar.addfile(item, stream); seen.add(path)
        for path, (child, child_sha) in sorted(modules(repo, sha).items()):
            append(tar, repository(child, remote), child_sha, prefix + path + '/', ancestry + [(remote, sha)])
    temporary = target.with_suffix('.partial')
    if temporary.exists() or temporary.is_symlink(): raise ValueError('Existing partial source capsule retained')
    try:
        with temporary.open('xb') as raw, gzip.GzipFile(fileobj=raw, mode='wb', filename='', mtime=0, compresslevel=6) as gz:
            with tarfile.open(fileobj=gz, mode='w|') as tar: append(tar, url, commit, '', [])
        os.replace(temporary, target)
    except BaseException:
        if temporary.exists(): temporary.unlink()
        raise
    with target.open('rb') as stream: checksum = hashlib.file_digest(stream, 'sha256').hexdigest()
    result = {'schema': 1, 'id': name, 'file': target.name, 'bytes': target.stat().st_size,
              'sha256': checksum,
              'repository': url, 'commit': commit, 'trees': trees, 'files': len(seen),
              'noticeFiles': sorted(notices), 'lfsObjects': lfs, 'externalLinks': external_links,
              'upstreamSourceCollected': True,
              'completeCorrespondingSourceReviewed': False}
    record.write_text(json.dumps(result, indent=2) + '\n')
    return result


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('plan', type=Path); p.add_argument('--output', type=Path, required=True)
    p.add_argument('--cache', type=Path, required=True)
    args = p.parse_args()
    for spec in json.loads(args.plan.read_text())['sources']:
        result = collect(spec, args.output, args.cache)
        print(json.dumps({k: result[k] for k in ('id', 'files', 'bytes', 'sha256')}), flush=True)
