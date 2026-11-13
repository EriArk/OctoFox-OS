# SPDX-License-Identifier: GPL-3.0-or-later
import copy
import hashlib
import json
from pathlib import Path
import sys
import tempfile
from types import SimpleNamespace
import unittest
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'packaging/software'))
import runtime_flathub as upstream


class RuntimeFlathubTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.stage=Path(self.temp.name);key=self.stage/'media/flatpak/flathub.gpg';key.parent.mkdir(parents=True);key.write_bytes(b'pinned key')
        self.row={'ref':'org.flycast.Flycast/aarch64/stable','kind':'app','commit':'a'*64,'file':'flycast.flatpak',
                  'delivery':{'kind':'flathub-commit','keySha256':hashlib.sha256(b'pinned key').hexdigest()}}
        self.calls=[];self.bad_commit=False;self.fail_pull=False

    def run_command(self,args,**kwargs):
        self.calls.append((args,kwargs));out='';status=0
        if 'show-url' in args:out=upstream.URL
        if 'config' in args and 'get' in args:out='true'
        if 'rev-parse' in args:out=('b' if self.bad_commit else 'a')*64
        if 'pull' in args and self.fail_pull:status=1
        if 'build-bundle' in args:Path(args[-3]).write_bytes(b'exact pinned commit bundle')
        return SimpleNamespace(returncode=status,stdout=out,stderr='network unavailable' if status else '')

    def test_pin_and_signatures_used_in_separate_cache_then_reused(self):
        result=upstream.prepare(self.stage,self.row,runner=self.run_command)
        pull=next(args for args,_ in self.calls if 'pull' in args)
        self.assertEqual(pull[-1],'app/'+self.row['ref']+'@'+'a'*64)
        self.assertIn('--http-header=User-Agent=OctoFox-OS-Setup/1',pull)
        self.assertFalse(any('install' in args or 'update' in args for args,_ in self.calls))
        for _,kwargs in self.calls:
            self.assertTrue(Path(kwargs['env']['HOME']).is_relative_to(self.stage))
            self.assertTrue(Path(kwargs['env']['FLATPAK_USER_DIR']).is_relative_to(self.stage))
        add=next(args for args,_ in self.calls if 'add' in args)
        self.assertIn('--set=gpg-verify=true',add);self.assertIn('--set=gpg-verify-summary=true',add)
        descriptor=json.loads(Path(result['preparedFile']).read_text())
        self.assertEqual(descriptor['commit'],self.row['commit'])
        self.assertEqual(descriptor['format'],'ostree')
        self.assertFalse(any('build-bundle' in args for args,_ in self.calls))
        self.assertEqual(upstream.prepare(self.stage,self.row,runner=lambda *a,**k:self.fail('unexpected command')),result)

    def test_wrong_commit_cannot_reach_export_or_activation(self):
        self.bad_commit=True
        with self.assertRaisesRegex(ValueError,'version differs'):upstream.prepare(self.stage,self.row,runner=self.run_command)
        self.assertFalse(any('build-bundle' in args for args,_ in self.calls))

    def test_network_failure_does_not_create_ready_package(self):
        self.fail_pull=True
        with self.assertRaisesRegex(ValueError,'network unavailable'):upstream.prepare(self.stage,self.row,runner=self.run_command)
        self.assertFalse(list((self.stage/'downloads/flathub').glob('*.json')))
        self.assertFalse(list((self.stage/'downloads/flathub').glob('*.flatpak')))

    def test_tampered_cache_is_not_trusted(self):
        result=upstream.prepare(self.stage,self.row,runner=self.run_command)
        Path(result['preparedFile']).write_bytes(b'changed')
        with self.assertRaisesRegex(ValueError,'changed'):upstream.prepare(self.stage,self.row,runner=self.run_command)

    def test_modified_ppsspp_and_unreviewed_refs_cannot_use_flathub(self):
        for ref in ['org.ppsspp.PPSSPP/aarch64/traineros-relay','org.flycast.Flycast/x86_64/stable','../outside']:
            row=copy.deepcopy(self.row);row['ref']=ref
            with self.subTest(ref=ref),self.assertRaises(ValueError):upstream.validate(row)

if __name__=='__main__':unittest.main()
