from pathlib import Path
import hashlib
import io
import json
import sys
import tarfile
import tempfile
import unittest
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'packaging/software'))
import source_materials as m


class SourceMaterialsTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(); self.root = Path(self.tmp.name)
        self.media = self.root / 'media'; self.sources = self.root / 'sources'; self.extra = self.root / 'extra'
        self.wheels = self.media / 'python/wheels'
        for p in (self.sources, self.extra, self.wheels): p.mkdir(parents=True)
        wheel = self.wheels / 'sample.whl'
        with zipfile.ZipFile(wheel, 'w') as z:
            z.writestr('sample.dist-info/METADATA', 'Name: sample\nVersion: 1\n')
            z.writestr('sample.dist-info/licenses/LICENSE', 'Original licence\n')
            z.writestr('sample/module.py', 'raise RuntimeError("must not execute")')
        source = self.sources / 'sample.tar.gz'; source.write_bytes(b'exact sdist archive')
        self.index = self.root / 'index.json'
        self.row = {'sourceFile': source.name, 'sourceStatus': 'downloaded-verified', 'wheelMatchesPyPI': True,
                    'wheelSha256': m.digest(wheel), 'sourceBytes': source.stat().st_size, 'sourceSha256': m.digest(source)}
        self.index.write_text(json.dumps({'sources': [self.row]}))
        (self.extra / 'LICENSE.txt').write_text('Supplemental terms')
        self.out = self.root / 'materials.tar.gz'
    def tearDown(self): self.tmp.cleanup()
    def build(self): return m.build(self.media, self.sources, self.index, self.extra, self.out)

    def test_sources_and_notices_without_module_execution(self):
        result = self.build()
        with tarfile.open(self.out) as t:
            names = t.getnames(); record = json.load(t.extractfile('materials.json'))
            self.assertIn('python/sources/sample.tar.gz', names)
            self.assertIn('python/notices/sample.whl/sample.dist-info/licenses/LICENSE', names)
            self.assertFalse(any(p.endswith('module.py') for p in names))
            for row in record['files']:
                self.assertEqual(hashlib.sha256(t.extractfile(row['path']).read()).hexdigest(), row['sha256'])
        self.assertFalse(result['redistributionReviewed'])
    def test_changed_source_refused(self):
        (self.sources / self.row['sourceFile']).write_bytes(b'tampered')
        with self.assertRaisesRegex(ValueError, 'source changed'): self.build()
        self.assertFalse(self.out.exists())
    def test_missing_distributed_wheel_refused(self):
        self.row['wheelSha256'] = 'a' * 64
        self.index.write_text(json.dumps({'sources': [self.row]}))
        with self.assertRaisesRegex(ValueError, 'distributed wheels'): self.build()
    def test_bad_native_archive_does_not_leave_partial_output(self):
        native = self.media / 'runtimes/sample'; native.mkdir(parents=True)
        (native / 'component.json').write_text(json.dumps({'id': 'sample', 'archive': {'sha256': 'a' * 64}}))
        (native / 'component.tar.gz').write_bytes(b'bad')
        with self.assertRaisesRegex(ValueError, 'component changed'): self.build()
        self.assertFalse(self.out.exists()); self.assertFalse(self.out.with_suffix('.partial').exists())
    def test_repeat_does_not_overwrite(self):
        self.build(); checksum = m.digest(self.out)
        with self.assertRaisesRegex(ValueError, 'already exists'): self.build()
        self.assertEqual(checksum, m.digest(self.out))

    def test_prior_partial_is_retained(self):
        partial = self.out.with_suffix('.partial'); partial.write_bytes(b'prior attempt')
        with self.assertRaisesRegex(ValueError, 'Existing partial'): self.build()
        self.assertEqual(partial.read_bytes(), b'prior attempt')


if __name__ == '__main__': unittest.main()
