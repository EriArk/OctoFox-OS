import importlib.util
import json
from pathlib import Path
import subprocess
import tarfile
import tempfile
import unittest

SPEC = importlib.util.spec_from_file_location('source_capsule', Path(__file__).resolve().parents[1] / 'packaging/software/source_capsule.py')
m = importlib.util.module_from_spec(SPEC); SPEC.loader.exec_module(m)


class SourceCapsuleTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(); self.root = Path(self.tmp.name)
        self.repo = self.root / 'repo'; self.repo.mkdir()
        self.g('init', '--template=')
        self.g('config', 'user.name', 'Fixture'); self.g('config', 'user.email', 'fixture@example.invalid')
        self.g('config', 'core.autocrlf', 'false')
        (self.repo / 'LICENSE').write_text('test licence\n')
        (self.repo / 'source.c').write_text('int main(void) {return 0;}\n')
        self.commit()

    def tearDown(self): self.tmp.cleanup()
    def g(self, *args): return subprocess.check_output(['git', '-C', str(self.repo), *args], stderr=subprocess.DEVNULL)
    def commit(self):
        self.g('add', '.'); self.g('commit', '-qm', 'fixture')
        self.sha = self.g('rev-parse', 'HEAD').decode().strip()
    def spec(self): return {'id': 'fixture', 'repository': 'https://github.com/example/fixture.git', 'commit': self.sha}
    def collect(self, fetcher=None):
        return m.collect(self.spec(), self.root / 'out', self.root / 'cache', fetcher or (lambda *_: self.repo))

    def test_exact_source_and_notice_without_execution(self):
        (self.repo / 'build.sh').write_text('exit 19\n'); self.commit()
        record = self.collect()
        with tarfile.open(self.root / 'out' / record['file']) as tar:
            self.assertEqual(tar.extractfile('fixture/source.c').read(), (self.repo / 'source.c').read_bytes())
        self.assertIn('LICENSE', record['noticeFiles'])
        self.assertFalse(record['completeCorrespondingSourceReviewed'])
        self.assertEqual(record['trees'][0]['commit'], self.sha)

    def test_gitlinks_are_collected_at_recorded_commit(self):
        child = self.sha
        (self.repo / '.gitmodules').write_text('[submodule "dependency"]\n path = vendor/dep\n url = ../dependency.git\n')
        self.g('add', '.gitmodules')
        self.g('update-index', '--add', '--cacheinfo', '160000,' + child + ',vendor/dep')
        self.g('commit', '-qm', 'gitlink'); self.sha = self.g('rev-parse', 'HEAD').decode().strip()
        record = self.collect()
        self.assertEqual(record['trees'][1]['commit'], child)
        self.assertEqual(record['trees'][1]['repository'], 'https://github.com/example/dependency.git')
        with tarfile.open(self.root / 'out' / record['file']) as tar:
            self.assertEqual(tar.extractfile('fixture/vendor/dep/source.c').read(), (self.repo / 'source.c').read_bytes())

    def test_missing_gitlink_mapping_fails_without_capsule(self):
        self.g('update-index', '--add', '--cacheinfo', '160000,' + self.sha + ',dep')
        self.g('commit', '-qm', 'gitlink'); self.sha = self.g('rev-parse', 'HEAD').decode().strip()
        with self.assertRaises(subprocess.CalledProcessError): self.collect()
        self.assertEqual(list((self.root / 'out').iterdir()), [])

    def test_lfs_pointer_is_not_counted_as_source(self):
        (self.repo / 'large.bin').write_text('version https://git-lfs.github.com/spec/v1\noid sha256:abc\nsize 1\n'); self.commit()
        with self.assertRaisesRegex(ValueError, 'Unresolved Git LFS'): self.collect()
        self.assertEqual(list((self.root / 'out').iterdir()), [])

    def test_fetched_wrong_commit_fails(self):
        spec = self.spec(); spec['commit'] = 'a' * 40
        with self.assertRaises(subprocess.CalledProcessError):
            m.collect(spec, self.root / 'out', self.root / 'cache', lambda *_: self.repo)

    def test_lfs_object_hash_is_verified_and_materialized(self):
        import hashlib
        blob = b'actual original source bytes'
        (self.repo / 'large.bin').write_bytes(('version https://git-lfs.github.com/spec/v1\noid sha256:' + hashlib.sha256(blob).hexdigest() + '\nsize ' + str(len(blob)) + '\n').encode())
        self.commit()
        with self.assertRaisesRegex(ValueError, 'hash/size mismatch'):
            m.collect(self.spec(), self.root / 'out', self.root / 'cache', lambda *_: self.repo, lambda *_: b'wrong')
        result = m.collect(self.spec(), self.root / 'out', self.root / 'cache', lambda *_: self.repo, lambda *_: blob)
        with tarfile.open(self.root / 'out' / result['file']) as tar:
            self.assertEqual(tar.extractfile('fixture/large.bin').read(), blob)
        self.assertEqual(result['lfsObjects'][0]['sha256'], hashlib.sha256(blob).hexdigest())

    def test_existing_capsule_preserved(self):
        record = self.collect(); before = (self.root / 'out' / record['file']).read_bytes()
        with self.assertRaises(ValueError): self.collect()
        self.assertEqual(before, (self.root / 'out' / record['file']).read_bytes())

    def test_prior_partial_is_retained(self):
        output = self.root / 'out'; output.mkdir()
        partial = output / ('fixture-' + self.sha + '.tar.partial'); partial.write_bytes(b'prior attempt')
        with self.assertRaisesRegex(ValueError, 'Existing partial'): self.collect()
        self.assertEqual(partial.read_bytes(), b'prior attempt')

    def test_external_source_link_preserved_without_reading_target(self):
        target = '/nonexistent/source-sdk/include'
        obj = subprocess.check_output(['git', '-C', str(self.repo), 'hash-object', '-w', '--stdin'], input=target.encode()).decode().strip()
        self.g('update-index', '--add', '--cacheinfo', '120000,' + obj + ',sdk-include')
        self.g('commit', '-qm', 'source link'); self.sha = self.g('rev-parse', 'HEAD').decode().strip()
        result = self.collect()
        self.assertEqual(result['externalLinks'], [{'path': 'sdk-include', 'target': target}])
        with tarfile.open(self.root / 'out' / result['file']) as tar:
            member = tar.getmember('fixture/sdk-include')
            self.assertTrue(member.issym()); self.assertEqual(member.linkname, target)

    def test_export_ignore_and_subst_overridden_in_real_cache(self):
        (self.repo / '.gitattributes').write_text('LICENSE export-ignore\nsource.c export-subst\n')
        (self.repo / 'source.c').write_bytes(b'$Format:%H$\n'); self.commit()
        cache = self.root / 'cache'; cache.mkdir()
        import hashlib
        target = cache / hashlib.sha256(self.spec()['repository'].encode()).hexdigest()[:24]
        subprocess.run(['git', 'clone', '--bare', str(self.repo), str(target)], check=True, capture_output=True)
        record = m.collect(self.spec(), self.root / 'out', cache)
        with tarfile.open(self.root / 'out' / record['file']) as tar:
            self.assertEqual(tar.extractfile('fixture/source.c').read(), b'$Format:%H$\n')
            self.assertIn('fixture/LICENSE', tar.getnames())

    def test_untrusted_urls_paths_and_moving_refs_rejected(self):
        for url in ['file:///tmp/repo', 'ssh://github.com/repo', 'https://user:pass@github.com/a/b',
                    'https://github.com/a/b?token=value', 'https://evil.invalid/a/b', 'https://github.com:22/a/b']:
            with self.subTest(url=url), self.assertRaises(ValueError): m.repository(url)
        for name in ['../a', '/a', 'a/../../b', '.git/config', 'a\\b']:
            with self.subTest(name=name), self.assertRaises(ValueError): m.relative(name)
        for ref in ['main', 'v1.0', 'a' * 39]:
            with self.subTest(ref=ref), self.assertRaises(ValueError): m.revision(ref)


if __name__ == '__main__': unittest.main()
