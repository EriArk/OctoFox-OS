# SPDX-License-Identifier: GPL-3.0-or-later
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import struct
import tarfile
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('core_rebuild', Path(__file__).resolve().parents[1] / 'packaging/emulators/core-rebuild/build.py')
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)

class CoreRebuildTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(); self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name); (self.root / 'sources').mkdir()
        self.row = {'core':'example','sourceId':'rebuild-example','repository':'https://github.com/example/core.git',
                    'commit':'a'*40,'directory':'.','buildSystem':'make','makefile':'Makefile',
                    'arguments':[],'artifact':'example_libretro.so','previousBinary':{'sha256':'b'*64,'bytes':99}}
        archive = self.root / 'sources/source.tar.gz'
        with tarfile.open(archive,'w:gz') as t:
            entry=tarfile.TarInfo('rebuild-example/Makefile');entry.size=4;t.addfile(entry,io.BytesIO(b'test'))
        self.meta={'id':self.row['sourceId'],'repository':self.row['repository'],'commit':self.row['commit'],
                   'file':archive.name,'bytes':archive.stat().st_size,'sha256':m.digest(archive)}
        self.save_meta()
    def save_meta(self):
        (self.root/'sources/rebuild-example.json').write_text(json.dumps(self.meta))
    def produce(self, command, **kwargs):
        root=Path(command[command.index('-C')+1]);header=bytearray(64)
        header[:6]=b'\x7fELF\x02\x01';struct.pack_into('<H',header,18,self.machine)
        (root/self.row['artifact']).write_bytes(header)
    def test_tampered_source_stops_before_build(self):
        self.meta['sha256']='0'*64;self.save_meta()
        with patch.object(m.subprocess,'run') as run:
            with self.assertRaisesRegex(ValueError,'differs'):m.build(self.row,self.root,'test')
            run.assert_not_called()
    def test_wrong_source_revision_and_artifact_escape_are_rejected(self):
        self.row['commit']='c'*40
        with self.assertRaisesRegex(ValueError,'differs'):m.build(self.row,self.root,'test')
        self.row['artifact']='../example_libretro.so'
        with self.assertRaisesRegex(ValueError,'Invalid candidate'):m.build(self.row,self.root,'test')
    def test_host_binary_cannot_be_delivered_as_arm64(self):
        self.machine=62
        with patch.object(m.subprocess,'run',side_effect=self.produce):result=m.build(self.row,self.root,'test')
        self.assertEqual(result['status'],'failed');self.assertIn('ARM64',result['error'])
        self.assertFalse((self.root/'artifacts/test/example_libretro.so').exists())
    def test_candidate_keeps_original_identity_and_cannot_overwrite_attempt(self):
        self.machine=183
        with patch.object(m.subprocess,'run',side_effect=self.produce), patch.object(m.subprocess,'check_output',return_value='dynamic table'):
            result=m.build(self.row,self.root,'test')
        self.assertEqual(result['status'],'built');self.assertFalse(result['installed']);self.assertFalse(result['runtimeAccepted'])
        self.assertEqual(result['previousBinary'],self.row['previousBinary'])
        with self.assertRaises(FileExistsError):m.build(self.row,self.root,'test')


pack_spec = importlib.util.spec_from_file_location('core_rebuild_package', Path(__file__).resolve().parents[1] / 'packaging/emulators/core-rebuild/package.py')
pack = importlib.util.module_from_spec(pack_spec); pack_spec.loader.exec_module(pack)

class CoreRebuildPackageTests(unittest.TestCase):
    produce = CoreRebuildTests.produce
    save_meta = CoreRebuildTests.save_meta
    def setUp(self):
        CoreRebuildTests.setUp(self); self.machine=183
        with patch.object(m.subprocess,'run',side_effect=self.produce), patch.object(m.subprocess,'check_output',return_value='dynamic table'):
            self.result=m.build(self.row,self.root,'original')
        (self.root/'original.json').write_text(json.dumps({'cores':[self.result]}))
        (self.root/'candidates.json').write_text(json.dumps({'schema':1,'stage':'candidate-only','cores':[self.row]}))
        (self.root/'toolchains.json').write_text('{}')
        (self.root/'selection.json').write_text(json.dumps({'example':'original'}))
        (self.root/'toolchain-packages.tsv').write_text('fixture\t1\n')
        (self.root/'recipes').mkdir();(self.root/'recipes/README').write_text('fixture')
        self.probes=self.root/'probes.json'
        self.probes.write_text(json.dumps({'cores':[{'file':self.row['artifact'],'status':'abi-loaded','bytes':self.result['bytes'],'sha256':self.result['sha256']}]}))
    def test_bundle_readback_preserves_candidate_boundary_and_prior_archive(self):
        output=self.root/'candidate.tar';result=pack.package(self.root,output,['original'],self.probes)
        self.assertTrue(result['allEntriesReadBack']);self.assertFalse(result['installed']);self.assertFalse(result['redistributionReviewed'])
        with self.assertRaisesRegex(ValueError,'retained'):pack.package(self.root,output,['original'],self.probes)
    def test_tampered_built_core_cannot_be_packaged(self):
        (self.root/'artifacts/original'/self.row['artifact']).write_bytes(b'tampered')
        with self.assertRaisesRegex(ValueError,'differs'):pack.package(self.root,self.root/'candidate.tar',['original'],self.probes)
    def test_missing_probe_or_ambiguous_build_cannot_be_packaged(self):
        with self.assertRaisesRegex(ValueError,'Ambiguous'):pack.package(self.root,self.root/'candidate.tar',['original','original'],self.probes)
        self.probes.write_text(json.dumps({'cores':[]}))
        with self.assertRaisesRegex(ValueError,'incomplete'):pack.package(self.root,self.root/'candidate.tar',['original'],self.probes)

if __name__=='__main__':unittest.main()

