# SPDX-License-Identifier: GPL-3.0-or-later
"""Exact binary/source bindings, no emulator execution or upstream network calls."""
import copy
import hashlib
import io
import json
from pathlib import Path
import struct
import sys
import tarfile
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'packaging/software'))
import core_sources as m


class CoreSourceTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(); self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name); self.caps = self.root / 'caps'; self.caps.mkdir()
        self.checkout = self.root / 'checkout'; self.checkout.mkdir()
        self.archive = self.root / 'component.tar.gz'
        self.header = bytearray(64); self.header[:6] = b'\x7fELF\x02\x01'; struct.pack_into('<H', self.header, 18, 183)
        self.raw = bytes(self.header) + b'1.0 abcdef1-dirty\0'
        spec = {'id': 'example', 'repository': 'https://github.com/fixture/core.git', 'commit': 'abcdef1' + '0' * 33}
        self.plan = {'schema': 1, 'component': 'retroarch-cores', 'archive': {},
                     'recipeReference': {'source': spec, 'file': 'core-rules.sh', 'sha256': hashlib.sha256(b'recipe fixture').hexdigest()},
                     'cores': [{'path': 'cores/example_libretro.so', 'bytes': len(self.raw),
                        'sha256': hashlib.sha256(self.raw).hexdigest(), 'source': spec,
                        'identity': {'kind': 'embedded-marker', 'marker': '1.0 abcdef1-dirty', 'abbreviation': 'abcdef1', 'dirty': True},
                        'localMaterials': ['build.sh']}]}
        (self.checkout / 'build.sh').write_bytes(b'# retained recipe, never execute\n')
        for name in ('LICENSE', 'LICENSING.md'): (self.checkout / name).write_bytes(b'fixture notice')
        archive = self.caps / 'source.tar.gz'
        with tarfile.open(archive, 'w:gz') as tar:
            entry = tarfile.TarInfo('example/core-rules.sh'); entry.size = len(b'recipe fixture')
            tar.addfile(entry, io.BytesIO(b'recipe fixture'))
        self.record = {**spec, 'file': archive.name, 'bytes': archive.stat().st_size, 'sha256': m.sha256(archive)}
        (self.caps / 'example.json').write_text(json.dumps(self.record))
        self.make_archive()

    def make_archive(self, entries=None):
        with tarfile.open(self.archive, 'w:gz') as t:
            for name, data in (entries or {'cores/example_libretro.so': self.raw}).items():
                entry = tarfile.TarInfo(name); entry.size = len(data); t.addfile(entry, io.BytesIO(data))
        self.plan['archive'] = {'bytes': self.archive.stat().st_size, 'sha256': m.sha256(self.archive)}

    def verify(self): return m.verify(self.archive, self.plan, self.caps, self.checkout)

    def test_bundle_verifies_dirty_base_keeps_recipe_and_does_not_certify_build(self):
        plan = self.root / 'plan.json'; plan.write_text(json.dumps(self.plan)); output = self.root / 'sources.tar'
        result = m.bundle(self.archive, plan, self.caps, self.checkout, output)
        self.assertEqual(result['upstreamSourceCollected'], 1); self.assertTrue(result['allEntriesReadBack'])
        self.assertTrue(result['cores'][0]['dirtyMarker']); self.assertFalse(result['redistributionReviewed'])
        self.assertFalse(result['cores'][0]['completeBinaryBuildReviewed'])
        with tarfile.open(output) as t:
            self.assertEqual(t.extractfile('traineros/build.sh').read(), (self.checkout / 'build.sh').read_bytes())
        with self.assertRaisesRegex(ValueError, 'retained'): m.bundle(self.archive, plan, self.caps, self.checkout, output)

    def test_unknown_and_uncollected_are_visible(self):
        self.plan['cores'][0]['source'] = self.plan['cores'][0]['identity'] = None
        report, _ = self.verify(); self.assertEqual(report['identityUnresolved'], 1)
        self.assertEqual(report['upstreamSourceCollected'], 0)
        self.plan['cores'][0]['source'] = {k: self.record[k] for k in ('id', 'repository', 'commit')}
        self.plan['cores'][0]['identity'] = {'kind': 'embedded-marker', 'marker': '1.0 abcdef1-dirty', 'abbreviation': 'abcdef1', 'dirty': True}
        (self.caps / 'example.json').unlink()
        report, _ = self.verify(); self.assertEqual(report['cores'][0]['status'], 'source-not-collected')

    def test_archive_core_and_source_tampering_are_separate_failures(self):
        self.plan['archive']['sha256'] = '0' * 64
        with self.assertRaisesRegex(ValueError, 'archive differs'): self.verify()
        self.plan['archive']['sha256'] = m.sha256(self.archive)
        self.plan['cores'][0]['sha256'] = '0' * 64
        with self.assertRaisesRegex(ValueError, 'pinned bytes'): self.verify()
        self.plan['cores'][0]['sha256'] = hashlib.sha256(self.raw).hexdigest()
        (self.caps / self.record['file']).write_bytes(b'altered')
        with self.assertRaisesRegex(ValueError, 'capsule size'): self.verify()

    def test_wrong_revision_and_absent_marker_are_rejected(self):
        row = self.plan['cores'][0]; row['source']['commit'] = '0' * 40
        with self.assertRaisesRegex(ValueError, 'revision differs'): self.verify()
        row['source']['commit'] = self.record['commit']; row['identity']['marker'] = '2.0 abcdef1-dirty'
        with self.assertRaisesRegex(ValueError, 'absent'): self.verify()
        row['identity']['marker'] = '1.0 abcdef1-dirty'; row['identity']['dirty'] = False
        with self.assertRaisesRegex(ValueError, 'Dirty'): self.verify()

    def test_cannot_hide_extra_core_or_change_architecture(self):
        self.make_archive({'cores/example_libretro.so': self.raw, 'cores/extra_libretro.so': self.raw})
        with self.assertRaisesRegex(ValueError, 'Unlisted'): self.verify()
        raw = bytearray(self.raw); struct.pack_into('<H', raw, 18, 62); self.raw = bytes(raw)
        self.make_archive(); self.plan['cores'][0]['sha256'] = hashlib.sha256(self.raw).hexdigest()
        with self.assertRaisesRegex(ValueError, 'ARM64'): self.verify()

    def test_marker_crossing_chunk_boundary(self):
        with patch.object(m, 'CHUNK', 68):
            report, _ = self.verify(); self.assertEqual(report['upstreamSourceCollected'], 1)

    def test_revision_string_may_follow_a_nonzero_binary_table(self):
        self.raw = self.raw[:63] + b'\x14' + self.raw[64:]
        self.plan['cores'][0]['sha256'] = hashlib.sha256(self.raw).hexdigest(); self.make_archive()
        report, _ = self.verify(); self.assertEqual(report['upstreamSourceCollected'], 1)

    def test_retained_record_must_match_exact_binary(self):
        path = self.checkout / 'build-record.json'
        record = {'cores': [{'name': 'example_libretro.so', 'bytes': len(self.raw), 'sha256': hashlib.sha256(self.raw).hexdigest()}]}
        path.write_text(json.dumps(record))
        self.plan['cores'][0]['identity'] = {'kind': 'retained-build-record', 'record': path.name}
        report, _ = self.verify(); self.assertEqual(report['upstreamSourceCollected'], 1)
        record['cores'][0]['sha256'] = '0' * 64; path.write_text(json.dumps(record))
        with self.assertRaisesRegex(ValueError, 'does not identify'): self.verify()

    def test_capsule_revision_and_material_path_are_verified(self):
        row = {**self.record, 'commit': '0' * 40}; (self.caps / 'example.json').write_text(json.dumps(row))
        with self.assertRaisesRegex(ValueError, 'revision/repository'): self.verify()
        (self.caps / 'example.json').write_text(json.dumps(self.record))
        expected = self.plan['recipeReference']['sha256']; self.plan['recipeReference']['sha256'] = '0' * 64
        with self.assertRaisesRegex(ValueError, 'Recipe reference'): self.verify()
        self.plan['recipeReference']['sha256'] = expected
        self.plan['cores'][0]['localMaterials'] = ['../outside']
        with self.assertRaisesRegex(ValueError, 'Unsafe'): self.verify()


if __name__ == '__main__': unittest.main()
