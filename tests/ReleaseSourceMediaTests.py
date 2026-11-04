# SPDX-License-Identifier: GPL-3.0-or-later
import io
import json
from pathlib import Path
import sys
import tarfile
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'packaging/software'))
import fullbundle
import offline_setup
import release_source_media as media
import source_archive


class ReleaseSourceMediaTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name); self.revision = 'a' * 40
        self.original = self.root / 'original.tar.gz'
        with tarfile.open(self.original, 'w:gz', pax_headers={'comment': self.revision}) as tar:
            for name, raw in {'LICENSE': b'licence', 'LICENSING.md': b'asset terms',
                              'CMakeLists.txt': b'build', 'source.cpp': b'code',
                              'assets/avatar/pack/template.glb': b'model geometry'}.items():
                entry = tarfile.TarInfo(name); entry.size = len(raw)
                tar.addfile(entry, io.BytesIO(raw))
        self.filtered = self.root / 'filtered.tar.gz'
        source_archive.build(self.original, self.filtered)
        self.core = self.root / 'core.so'; self.core.write_bytes(b'exact installed core')
        fullbundle.build({'schema': 1, 'files': [
            {'path': name, 'source': str(path), 'sha256': fullbundle.payload.digest(path)}
            for name, path in [(media.MEMBER, self.original), ('runtimes/core.so', self.core)]]}, self.root / 'base')
        self.archive = self.root / 'base/TrainerOS-Full-CANDIDATE.tar'
        self.pin = {'bytes': self.archive.stat().st_size, 'sha256': fullbundle.payload.digest(self.archive)}
        self.output = self.root / 'new.tar'

    def replace(self, **kwargs):
        return media.replace(self.archive, kwargs.get('expected', self.pin), kwargs.get('source', self.filtered),
                             kwargs.get('revision', self.revision), self.output)

    def test_replaces_only_nested_source_and_preserves_original(self):
        result = self.replace()
        self.assertEqual(result['changedPaths'], [media.MEMBER])
        self.assertFalse(result['runtimeArtRedistributionReviewed'])
        self.assertEqual(fullbundle.payload.digest(self.archive), self.pin['sha256'])
        with tarfile.open(self.output) as tar:
            self.assertEqual(tar.extractfile('runtimes/core.so').read(), self.core.read_bytes())
            self.assertEqual(tar.extractfile(media.MEMBER).read(), self.filtered.read_bytes())
        self.assertFalse(media.check(self.output, self.revision)['separateAvatarGeometry'])
        with self.assertRaisesRegex(ValueError, 'new'): self.replace()

    def test_wrong_revision_or_loose_source_rejected_before_output(self):
        for args in ({'revision': 'b' * 40}, {'source': self.original}):
            with self.subTest(args=args), self.assertRaises(ValueError): self.replace(**args)
            self.assertFalse(self.output.exists())

    def test_changed_runtime_rejected_before_output(self):
        with self.archive.open('ab') as stream: stream.write(b'changed')
        with self.assertRaisesRegex(ValueError, 'pinned'): self.replace()
        self.assertFalse(self.output.exists())

    def test_missing_or_duplicate_nested_source_rejected(self):
        for count in (0, 2):
            archive = self.root / ('bad-' + str(count) + '.tar')
            with tarfile.open(archive, 'w') as tar:
                for _ in range(count): tar.add(self.filtered, arcname=media.MEMBER)
            with self.assertRaisesRegex(ValueError, 'Missing or ambiguous'):
                media.check(archive, self.revision)

    def test_setup_cannot_hide_old_nested_models_behind_filtered_outer_source(self):
        software = self.root / 'software'; software.mkdir()
        app = software / 'traineros.tar.gz'; app.write_bytes(b'fixture app')
        release = {'source': self.revision, 'archive': {'size': app.stat().st_size,
                                                      'sha256': fullbundle.payload.digest(app)}}
        with patch.object(offline_setup.sw, 'verified', return_value={'signed': release}):
            with self.assertRaisesRegex(ValueError, 'separate avatar geometry'):
                offline_setup.build(self.archive, software, None, self.root / 'public.pem',
                                    self.output, 14, self.filtered)
        self.assertFalse(self.output.exists())


if __name__ == '__main__': unittest.main()
