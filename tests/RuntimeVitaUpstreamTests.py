# SPDX-License-Identifier: GPL-3.0-or-later
import hashlib
import json
from pathlib import Path
import sys
import tarfile
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'packaging/software'))
import fullbundle
import runtime_payload
import runtime_set
import runtime_vita_upstream as vita
import upstream_media


class VitaUpstreamTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(); self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name); self.input = self.root / 'input'
        (self.input / 'runtime/usr/bin').mkdir(parents=True)
        (self.input / 'runtime/usr/bin/Vita3K').write_bytes(b'original vita')
        (self.input / 'runtime/AppRun.wrapped').write_bytes(b'our owned-process fix')
        (self.input / 'session.py').write_bytes(b'our transport')
        self.packed = self.root / 'packed'
        self.record = runtime_payload.build(self.input, ['runtime', 'session.py'], self.packed, 'vita3k-netplay')

    def convert(self):
        files = [{'path': 'runtimes/vita3k-netplay/' + name, 'source': str(self.packed / name),
                  'sha256': runtime_payload.digest(self.packed / name)} for name in ['component.json', 'component.tar.gz']]
        fullbundle.build({'schema': 1, 'files': files}, self.root / 'media')
        output = self.root / 'hybrid.tar'
        upstream_media.build(self.root / 'media/OctoFox-OS-Full-CANDIDATE.tar', {'schema': 1, 'vita': vita.SPEC}, output)
        with tarfile.open(output) as t:
            inventory = json.load(t.extractfile('fullbundle.json'))
        stage = self.root / 'stage'; stage.mkdir()
        runtime_set.extract(output, stage / 'media', inventory['files'])
        return stage

    def test_roundtrip_preserves_exact_runtime_and_local_wrapper(self):
        stage = self.convert()
        record = json.loads((stage / 'media/runtimes/vita3k-netplay/component.json').read_text())
        self.assertEqual(record['files'], self.record['files'])
        with tarfile.open(stage / 'media/runtimes/vita3k-netplay/component.tar.gz') as t:
            self.assertNotIn('runtime/usr/bin/Vita3K', t.getnames())
            self.assertEqual(t.extractfile('runtime/AppRun.wrapped').read(), b'our owned-process fix')
        def download(stage, record, target, progress):
            (target / 'runtime/usr/bin').mkdir(parents=True)
            (target / 'runtime/usr/bin/Vita3K').write_bytes(b'original vita')
        with patch.object(vita, 'prepare', side_effect=download) as prepare:
            _, target = runtime_set.component(stage, 'vita3k-netplay')
            runtime_set.component(stage, 'vita3k-netplay')
            prepare.assert_called_once()
        self.assertEqual((target / 'runtime/AppRun.wrapped').read_bytes(), b'our owned-process fix')

    def test_changed_extracted_binary_never_becomes_component(self):
        stage = self.convert()
        def download(stage, record, target, progress):
            (target / 'runtime/usr/bin').mkdir(parents=True)
            (target / 'runtime/usr/bin/Vita3K').write_bytes(b'changed binary')
        with patch.object(vita, 'prepare', side_effect=download), self.assertRaises(ValueError):
            runtime_set.component(stage, 'vita3k-netplay')
        # No activation/installation follows a failed final inventory check.
        self.assertFalse((stage / 'receipt.json').exists())
        self.assertFalse((stage / 'components/vita3k-netplay').exists())

    def test_extractor_cannot_supply_symlink_outside_private_directory(self):
        stage = self.root / 'stage'; stage.mkdir(); target = self.root / 'target'; target.mkdir()
        record = dict(self.record, upstreamRuntime=vita.SPEC)
        def extract(args, **kwargs):
            root = Path(args[args.index('-d') + 1]); (root / 'usr/bin').mkdir(parents=True)
            try: (root / 'usr/bin/Vita3K').symlink_to(self.input / 'runtime/usr/bin/Vita3K')
            except OSError: self.skipTest('Symlinks unavailable')
            return SimpleNamespace(returncode=0, stderr='')
        with patch.object(vita.sw, 'download'), self.assertRaisesRegex(ValueError, 'differs'):
            vita.prepare(stage, record, target, runner=extract)
        self.assertFalse(list(target.iterdir()))

    def test_unreviewed_original_is_rejected(self):
        record = dict(self.record, upstreamRuntime=dict(vita.SPEC, assetId=1))
        with self.assertRaises(ValueError): vita.rows(record)


if __name__ == '__main__': unittest.main()
