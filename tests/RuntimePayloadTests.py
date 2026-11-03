"""Collection guards: no personal files, changed binaries or redirected input."""
import hashlib
import json
from pathlib import Path
import sys
import tarfile
import tempfile
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'packaging/software'))
import runtime_payload as payload
import fullbundle
from collect_runtimes import collect, portable


class RuntimePayloadTests(unittest.TestCase):
    def test_only_explicit_code_and_portable_manifest(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); source = root / 'installed/game'; source.mkdir(parents=True)
            (source / 'core.so').write_bytes(b'known binary')
            (source / 'save.srm').write_bytes(b'personal progress')
            (source / 'bios.bin').write_bytes(b'personal firmware')
            (source / 'manifest.json').write_text(json.dumps({'runtime': (root / 'Applications/runtime').as_posix(), 'settings': 'owned-v1'}))
            recipe = {'revision': 'test', 'components': [{'id': 'game', 'include': ['core.so'],
                'expected': {'core.so': payload.digest(source / 'core.so')}, 'requiredUserFiles': ['bios.bin']}]}
            collect(recipe, root / 'installed', root / 'out', root)
            with tarfile.open(root / 'out/game/component.tar.gz') as archive:
                self.assertEqual(set(archive.getnames()), {'core.so', 'manifest.json'})
                manifest = json.load(archive.extractfile('manifest.json'))
                self.assertEqual(manifest['runtime'], '${HOME}/Applications/runtime')
                self.assertEqual(manifest['settings'], 'owned-v1')
            self.assertEqual((source / 'save.srm').read_bytes(), b'personal progress')

    def test_changed_or_missing_required_file_fails_before_output(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); (root / 'core').write_bytes(b'changed')
            for expected in ({'core': '0' * 64}, {'missing': '0' * 64}):
                with self.assertRaises(ValueError): payload.build(root, ['core'], root / 'out', 'test', expected)
                self.assertFalse((root / 'out').exists())

    def test_link_outside_component_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); source = root / 'source'; source.mkdir()
            (root / 'secret').write_bytes(b'not distributable')
            try: (source / 'code').symlink_to(root / 'secret')
            except OSError: self.skipTest('Symlink privilege unavailable')
            with self.assertRaises(ValueError): payload.build(source, ['code'], root / 'out', 'test')
            self.assertFalse((root / 'out').exists())

    def test_invalid_paths(self):
        for name in ('../save', '/root', 'a//b', './a', 'C:/a', 'a\\b', '', None):
            with self.subTest(name=name), self.assertRaises(ValueError): payload.relative(name)

    def test_no_other_home_and_no_silent_output_replacement(self):
        with self.assertRaises(ValueError): portable({'root': '/var/home/another/data'}, Path('/home/test'))
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); (root / 'file').write_bytes(b'code')
            payload.build(root, ['file'], root / 'out', 'test')
            with self.assertRaises(ValueError): payload.build(root, ['file'], root / 'out', 'test')

    def test_complete_media_and_corrupted_artifact(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); source = root / 'package'; source.write_bytes(b'unique artifact content')
            plan = {'schema': 1, 'files': [{'path': 'components/package.tar.gz', 'source': str(source), 'sha256': payload.digest(source)}]}
            result = fullbundle.build(plan, root / 'media')
            self.assertEqual(result['files'], 1)
            archive = root / 'media' / result['archive']
            self.assertFalse(fullbundle.verify(archive)['redistributionReviewed'])
            raw = archive.read_bytes().replace(b'unique artifact content', b'broken artifact content')
            archive.write_bytes(raw)
            with self.assertRaises(ValueError): fullbundle.verify(archive)

    def test_media_rejects_duplicate_and_changed_inputs(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); source = root / 'package'; source.write_bytes(b'package')
            row = {'path': 'package', 'source': str(source), 'sha256': payload.digest(source)}
            with self.assertRaises(ValueError): fullbundle.inventory({'schema': 1, 'files': [row, row]})
            source.write_bytes(b'new unreviewed version')
            with self.assertRaises(ValueError): fullbundle.inventory({'schema': 1, 'files': [row]})

    def test_release_parts_preserve_bytes_and_detect_damage(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); source = root / 'media.tar'; raw = b'0123456789abc'; source.write_bytes(raw)
            record = fullbundle.split(source, root / 'parts', part_bytes=5)
            self.assertEqual([row['bytes'] for row in record['parts']], [5, 5, 3])
            self.assertEqual(b''.join((root / 'parts' / row['path']).read_bytes() for row in record['parts']), raw)
            self.assertEqual(record['sha256'], hashlib.sha256(raw).hexdigest())
            part = root / 'parts' / record['parts'][1]['path']; part.write_bytes(b'wrong')
            with self.assertRaisesRegex(ValueError, 'checksum mismatch'): fullbundle.verify_parts(root / 'parts/parts.json')


if __name__ == '__main__': unittest.main()
