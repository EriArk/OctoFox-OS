# SPDX-License-Identifier: GPL-3.0-or-later
"""Release transport and source separation, with disposable archives only."""
import copy
import hashlib
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import tempfile
import unittest
from unittest.mock import patch

SOURCE = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SOURCE / 'packaging/software'))
import release_parts as parts
import source_archive as sources


def quiet(*args): pass


def tar(path, entries, revision=None):
    with tarfile.open(path, 'w:gz', format=tarfile.PAX_FORMAT,
                      pax_headers={'comment': revision} if revision else {}) as archive:
        for name, value in entries.items():
            entry = tarfile.TarInfo(name)
            if isinstance(value, tuple):
                entry.type = tarfile.SYMTYPE; entry.linkname = value[0]
                archive.addfile(entry)
            else:
                entry.size = len(value); entry.mode = 0o755 if name.endswith('.py') else 0o644
                archive.addfile(entry, io.BytesIO(value))


class ReleaseDeliveryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.original = self.root / 'Setup.tar'
        tar(self.original, {'TrainerOS-Setup/packaging/software/installer.py': b'print("fixture")\n',
                            'TrainerOS-Setup/Install TrainerOS.sh': b'#!/bin/sh\n',
                            'TrainerOS-Setup/README.txt': b'fixture'})
        self.cache = self.root / 'parts'
        self.plan = parts.split(self.original, self.cache, 'fixture/repo', 'candidate', 41)
        self.manifest = self.cache / 'parts.json'; self.pin = parts.sw.sha256(self.manifest)

    def join(self, **kwargs):
        return parts.assemble(self.manifest, self.pin, self.cache, progress=quiet, **kwargs)

    def test_roundtrip_retry_and_existing_output_preservation(self):
        joined = self.join()
        self.assertEqual(joined.read_bytes(), self.original.read_bytes())
        self.assertEqual(self.join(), joined)
        joined.write_bytes(b'user file')
        with self.assertRaisesRegex(ValueError, 'retained'): self.join()
        self.assertEqual(joined.read_bytes(), b'user file')

    def test_manifest_pin_order_size_and_whole_hash(self):
        self.manifest.write_bytes(self.manifest.read_bytes() + b' ')
        with self.assertRaisesRegex(ValueError, 'trusted'): self.join()
        for change in ('order', 'size', 'hash'):
            plan = copy.deepcopy(self.plan)
            if change == 'order': plan['parts'].reverse()
            elif change == 'size': plan['archive']['size'] += 1
            else: plan['archive']['sha256'] = '0' * 64
            parts.sw.atomic(self.manifest, plan); self.pin = parts.sw.sha256(self.manifest)
            with self.assertRaises(ValueError): self.join()
        self.assertFalse((self.cache / self.original.name).exists())
        self.assertFalse(list(self.cache.glob('.assembling-*')))

    def test_missing_and_corrupt_part_never_produce_output(self):
        path = self.cache / self.plan['parts'][0]['name']; data = path.read_bytes()
        path.unlink()
        with self.assertRaisesRegex(ValueError, 'Missing'): self.join()
        path.write_bytes(bytes([data[0] ^ 1]) + data[1:])
        with self.assertRaisesRegex(ValueError, 'damaged'): self.join()
        self.assertFalse((self.cache / self.original.name).exists())

    def test_resume_uses_pinned_github_url_and_range(self):
        row = self.plan['parts'][0]; path = self.cache / row['name']; original = path.read_bytes()
        path.write_bytes(original[:7]); calls = []
        class Response(io.BytesIO):
            status = 206
            headers = {'Content-Range': f'bytes 7-{len(original)-1}/{len(original)}', 'Content-Length': str(len(original)-7)}
            def geturl(self): return calls[0][0]
        def opener(request, timeout):
            calls.append((request.full_url, request.headers.get('Range')))
            return Response(original[7:])
        self.assertEqual(self.join(download=True, opener=opener).read_bytes(), self.original.read_bytes())
        self.assertEqual(calls, [('https://github.com/fixture/repo/releases/download/candidate/' + row['name'], 'bytes=7-')])

    def test_assembly_cancel_keeps_parts_and_retry_works(self):
        def cancel(*args): raise RuntimeError('cancelled')
        with self.assertRaisesRegex(RuntimeError, 'cancelled'):
            parts.assemble(self.manifest, self.pin, self.cache, progress=cancel)
        self.assertFalse(list(self.cache.glob('.assembling-*')))
        self.assertTrue(all((self.cache / row['name']).is_file() for row in self.plan['parts']))
        self.join()

    def test_extract_retry_checks_bytes_and_does_not_overwrite_changes(self):
        target = parts.unpack_setup(self.original, self.root / 'Setup', quiet)
        self.assertEqual(parts.unpack_setup(self.original, target, quiet), target)
        file = target / 'README.txt'; file.write_bytes(b'changed')
        with self.assertRaisesRegex(ValueError, 'changed'): parts.unpack_setup(self.original, target, quiet)
        self.assertEqual(file.read_bytes(), b'changed')

    def test_new_name_and_legacy_archives_share_safe_extraction(self):
        for root in ('OctoFox-OS-Setup', 'TrainerOS-Setup'):
            with self.subTest(root=root):
                tar(self.original, {root + '/packaging/software/installer.py': b'fixture',
                                    root + '/Install OctoFox OS.sh': b'#!/bin/sh\n'})
                target = self.root / root
                parts.unpack_setup(self.original, target, quiet)
                self.assertEqual((target / 'packaging/software/installer.py').read_bytes(), b'fixture')
                self.assertEqual(parts.unpack_setup(self.original, target, quiet), target)

    def test_mixed_brand_roots_are_rejected_without_extraction(self):
        tar(self.original, {'OctoFox-OS-Setup/packaging/software/installer.py': b'fixture',
                            'TrainerOS-Setup/README.txt': b'unrelated'})
        target = self.root / 'mixed'
        with self.assertRaisesRegex(ValueError, 'Unsafe'):
            parts.unpack_setup(self.original, target, quiet)
        self.assertFalse(target.exists())

    def test_extraction_cancel_and_unsafe_paths(self):
        target = self.root / 'Setup'
        def cancel(*args): raise RuntimeError('cancelled')
        with self.assertRaisesRegex(RuntimeError, 'cancelled'): parts.unpack_setup(self.original, target, cancel)
        self.assertFalse(target.exists()); self.assertFalse(list(self.root.glob('.setup-download-*')))
        for name, value in [('TrainerOS-Setup/../../escaped', b'bad'), ('TrainerOS-Setup/link', ('/tmp/escape',))]:
            tar(self.original, {'TrainerOS-Setup/packaging/software/installer.py': b'fixture', name: value})
            with self.assertRaises(ValueError): parts.unpack_setup(self.original, target, quiet)
        self.assertFalse(target.exists())

    def test_kit_contains_dependencies_pin_and_portable_metadata(self):
        kit = self.root / 'Download.tar.gz'; parts.kit(self.cache, kit)
        with tarfile.open(kit) as archive:
            names = archive.getnames()
            for name in ('software/release_parts.py', 'software/releases.py', 'software/installer.py', 'crates/catalogue.py'):
                self.assertIn('OctoFox-OS-Download/packaging/' + name, names)
            launch = archive.extractfile('OctoFox-OS-Download/Download OctoFox OS.sh').read()
            self.assertIn(self.pin.encode(), launch)
            self.assertTrue(all(m.uid == 0 and m.gid == 0 and not m.uname and not m.gname for m in archive))
        if os.name != 'nt':
            result = subprocess.run(['sh', '-n'], input=launch, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)

    def test_source_archive_filters_geometry_preserves_source_and_revision(self):
        source = self.root / 'source.tar.gz'; output = self.root / 'filtered.tar.gz'
        entries = {'LICENSE': b'licence', 'LICENSING.md': b'separate art terms', 'CMakeLists.txt': b'build',
                   'src/main.cpp': b'code', 'assets/avatar/packs/hair/template.glb': b'separate geometry',
                   'assets/avatar/README.md': b'notices', 'assets/avatar/render.png': b'preview'}
        tar(source, entries, 'a' * 40); before = source.read_bytes()
        with self.assertRaisesRegex(ValueError, 'geometry'): sources.check(source, 'a' * 40)
        record = sources.build(source, output)
        self.assertEqual(record['omittedGeometryFiles'], 1); self.assertEqual(source.read_bytes(), before)
        with tarfile.open(output) as archive:
            self.assertEqual(archive.pax_headers['comment'], 'a' * 40)
            for name, data in entries.items():
                if sources.excluded(name): self.assertNotIn(name, archive.getnames())
                else: self.assertEqual(archive.extractfile(name).read(), data)
            manifest = json.load(archive.extractfile(sources.RECORD))
            self.assertFalse(manifest['runtimeArtRedistributionReviewed'])
            self.assertEqual(manifest['omitted'][0]['sha256'], hashlib.sha256(b'separate geometry').hexdigest())
        with self.assertRaisesRegex(ValueError, 'revision'): sources.check(output, 'b' * 40)
        with self.assertRaises(ValueError): sources.build(source, output)

    def test_source_archive_rejects_external_links_and_bad_paths(self):
        for name, value in [('LICENSE', ('../../outside',)), ('../escape', b'bad')]:
            source = self.root / 'bad-source.tar.gz'
            tar(source, {'LICENSE': b'x', 'LICENSING.md': b'x', 'CMakeLists.txt': b'x', name: value}, 'a' * 40)
            with self.assertRaises(ValueError): sources.build(source, self.root / 'out.tar.gz')
            self.assertFalse((self.root / 'out.tar.gz').exists())


if __name__ == '__main__': unittest.main()
