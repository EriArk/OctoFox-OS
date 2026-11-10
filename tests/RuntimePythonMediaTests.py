# SPDX-License-Identifier: GPL-3.0-or-later
import io
import json
from pathlib import Path
import sys
import tarfile
import tempfile
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'packaging/software'))
import fullbundle
import runtime_payload
import runtime_python_media as media


class RuntimePythonMediaTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(); self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.plan = {'schema': 1, 'host': 'reviewed ARM host', 'previousSha256': 'a'*64,
                     'pythonSha256': 'b'*64, 'pythonVersion': 'Python 3.14.10'}
        rows = []
        def add(path, file):
            rows.append({'path': path, 'source': str(file), 'sha256': fullbundle.payload.digest(file)})
        locks = self.root/'interpreters.json'
        locks.write_text(json.dumps({n: {'pythonSha256': 'a'*64, 'pythonVersion': 'Python 3.14.8',
                                        'requirements': ['same-package==1']} for n in media.runtime_set.ENVIRONMENTS}))
        add('python/interpreters.json', locks)
        for name in media.NATIVE:
            folder = self.root/name; folder.mkdir()
            (folder/'code').write_bytes(b'unchanged emulator and protocol'); (folder/'code').chmod(0o755)
            (folder/'manifest.json').write_text(json.dumps({'interpreterSha256': 'a'*64,
                  'protocol': 1, 'settings': 'same-settings', 'files': {'code': fullbundle.payload.digest(folder/'code')}}))
            out = self.root/(name+'-payload'); runtime_payload.build(folder, ['code','manifest.json'], out, name)
            for file in out.iterdir(): add('runtimes/'+name+'/'+file.name, file)
        wheel = self.root/'wheel'; wheel.write_bytes(b'exact unchanged offline wheel')
        add('python/wheels/fixture.whl', wheel)
        fullbundle.build({'schema': 1, 'files': rows}, self.root/'original')
        self.archive = self.root/'original/TrainerOS-Full-CANDIDATE.tar'
        self.expected = {'bytes': self.archive.stat().st_size, 'sha256': fullbundle.payload.digest(self.archive)}

    def test_rebinds_all_exact_interpreters_preserving_protocols_and_wheels(self):
        output = self.root/'new.tar'; media.replace(self.archive, self.expected, self.plan, output)
        with tarfile.open(output) as tar:
            locks = json.load(tar.extractfile('python/interpreters.json'))
            self.assertEqual(set(locks), media.runtime_set.ENVIRONMENTS)
            self.assertTrue(all(v['pythonSha256']=='b'*64 and v['requirements']==['same-package==1'] for v in locks.values()))
            self.assertEqual(tar.extractfile('python/wheels/fixture.whl').read(), b'exact unchanged offline wheel')
            for name in media.NATIVE:
                prefix = 'runtimes/'+name+'/'
                record = json.load(tar.extractfile(prefix+'component.json'))
                raw = tar.extractfile(prefix+'component.tar.gz').read()
                self.assertEqual(media.identity(raw), record['archive'])
                with tarfile.open(fileobj=io.BytesIO(raw)) as nested:
                    manifest = json.load(nested.extractfile('manifest.json'))
                    self.assertEqual(manifest['interpreterSha256'], 'b'*64)
                    self.assertEqual(manifest['protocol'], 1); self.assertEqual(manifest['settings'], 'same-settings')
                    self.assertEqual(nested.extractfile('code').read(), b'unchanged emulator and protocol')
                    self.assertEqual(nested.getmember('code').mode & 0o777, 0o755)
                    for row in record['files']:
                        self.assertEqual(media.identity(nested.extractfile(row['path']).read()), {k:row[k] for k in ('bytes','sha256')})
        self.assertEqual(fullbundle.payload.digest(self.archive), self.expected['sha256'])
        with self.assertRaises(ValueError): media.replace(self.archive, self.expected, self.plan, output)

    def test_rejects_unreviewed_previous_and_moving_target(self):
        for field,value in [('previousSha256','c'*64), ('pythonSha256','latest'), ('pythonVersion','latest')]:
            plan = dict(self.plan, **{field:value}); output = self.root/(field+'.tar')
            with self.assertRaises(ValueError): media.replace(self.archive, self.expected, plan, output)
            self.assertFalse(output.exists())

    def test_rejects_changed_input_before_creating_output(self):
        with self.archive.open('ab') as file: file.write(b'changed')
        output = self.root/'changed.tar'
        with self.assertRaises(ValueError): media.replace(self.archive, self.expected, self.plan, output)
        self.assertFalse(output.exists())


if __name__ == '__main__': unittest.main()
