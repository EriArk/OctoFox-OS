# SPDX-License-Identifier: GPL-3.0-or-later
"""Failure injection for offline runtime ownership and multi-backend recovery."""
import copy
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import tarfile
import io
from types import SimpleNamespace
import unittest
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'packaging/software'))
import installation as install
import releases as sw
import runtime_set
import runtime_manager as manager
from runtime_transaction import Files
from runtime_flatpak import Flatpaks


class FlatpakFixture:
    def __init__(self): self.refs={}; self.calls=[]; self.bundles={}; self.failure=None
    def __call__(self,args,**kwargs):
        self.calls.append(args)
        if self.failure and self.failure in args: raise RuntimeError('interrupted Flatpak')
        if 'info' in args:
            value=self.refs.get(args[-1],''); return SimpleNamespace(returncode=0 if value else 1,stdout=value,stderr='not installed')
        if 'install' in args:
            ref,commit=self.bundles[args[-1]]; self.refs[ref]=commit
        if 'uninstall' in args: self.refs.pop(args[-1],None)
        if 'build-bundle' in args: raise AssertionError('fixture backups must be supplied')
        return SimpleNamespace(returncode=0,stdout='',stderr='')


class RuntimeInstallationTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.base=Path(self.temp.name); self.home=self.base/'home'; self.home.mkdir()
        self.root=self.base/'installation';self.root.mkdir()
        self.files=Files(self.root/'runtimes/files',[self.home])
        self.src=self.base/'source';self.src.write_bytes(b'new executable')
        self.dst=self.home/'Applications/game';self.dst.parent.mkdir()
        self.fake=FlatpakFixture()
        self.fp=Flatpaks(self.root/'runtimes/flatpak',self.home/'.local/share',self.fake)

    def desired(self): return {str(self.dst):self.files.import_file(self.src,0o755)}
    def crash(self,*args): raise RuntimeError('injected crash')

    def test_changed_existing_code_needs_migration_and_uninstall_restores_it(self):
        self.dst.write_bytes(b'original')
        save=self.home/'save.sav';save.write_bytes(b'personal progress')
        with self.assertRaisesRegex(ValueError,'migration'): self.files.plan(self.desired(),'one')
        self.files.begin(self.files.plan(self.desired(),'one',migrate=True));self.files.apply()
        self.assertEqual(self.dst.read_bytes(),b'new executable')
        self.files.begin(self.files.plan({},'remove'));self.files.apply()
        self.assertEqual(self.dst.read_bytes(),b'original');self.assertEqual(save.read_bytes(),b'personal progress')

    def test_resume_and_undo_after_atomic_file_write(self):
        for reverse in (False,True):
            self.files.begin(self.files.plan(self.desired(),str(reverse)))
            with self.assertRaisesRegex(RuntimeError,'crash'):self.files.apply(checkpoint=self.crash)
            self.assertTrue(self.files.pending());self.files.apply(reverse=reverse)
            self.assertEqual(self.dst.exists(),not reverse)
            if not reverse:
                self.files.begin(self.files.plan({},'clean'));self.files.apply()

    def test_recovery_never_clobbers_concurrent_user_change(self):
        self.files.begin(self.files.plan(self.desired(),'one'))
        with self.assertRaises(RuntimeError):self.files.apply(checkpoint=self.crash)
        self.dst.write_bytes(b'user changed this')
        with self.assertRaisesRegex(ValueError,'personal changes'):self.files.apply(reverse=True)
        self.assertEqual(self.dst.read_bytes(),b'user changed this')

    def test_symlink_parent_and_escape_are_rejected(self):
        with self.assertRaises(ValueError):self.files.path(str(self.base/'escape'))
        if os.name!='nt':
            link=self.home/'redirect';link.symlink_to(self.base,target_is_directory=True)
            with self.assertRaisesRegex(ValueError,'Linked'):self.files.path(str(link/'escape'))

    def test_recovery_detects_damaged_backup(self):
        self.dst.write_bytes(b'original');plan=self.files.plan(self.desired(),'one',migrate=True)
        self.files.begin(plan);self.files.apply(finish=False)
        (self.files.blobs/plan['operations'][0]['before']['sha256']).write_bytes(b'damaged')
        with self.assertRaisesRegex(ValueError,'damaged'):self.files.apply(reverse=True)

    def flatplan(self):
        stage=self.base/'stage';folder=stage/'media/flatpak';folder.mkdir(parents=True,exist_ok=True)
        path=folder/'app.flatpak';path.write_bytes(b'bundle')
        ref='org.test.Game/aarch64/stable';commit='a'*64
        self.fake.bundles[str(path)]=(ref,commit)
        rows=[{'ref':ref,'kind':'app','commit':commit,'file':path.name,'sha256':sw.sha256(path)}]
        return self.fp.plan(stage,rows),ref

    def test_flatpak_install_remove_retains_app_data_and_never_forces_dependencies(self):
        appdata=self.home/'.var/app/org.test.Game/save';appdata.parent.mkdir(parents=True);appdata.write_bytes(b'save')
        plan,ref=self.flatplan();self.fp.begin(plan);self.fp.apply()
        self.assertEqual(self.fake.refs[ref],'a'*64)
        self.fp.begin(self.fp.restore_plan());self.fp.apply()
        self.assertNotIn(ref,self.fake.refs);self.assertEqual(appdata.read_bytes(),b'save')
        self.assertFalse(any('--delete-data' in c or '--force-remove' in c for c in self.fake.calls))

    def test_flatpak_external_update_blocks_recovery(self):
        plan,ref=self.flatplan();self.fp.begin(plan);self.fake.refs[ref]='b'*64
        with self.assertRaisesRegex(ValueError,'preserving'):self.fp.apply()
        self.assertEqual(self.fake.refs[ref],'b'*64)

    def test_flatpak_remove_can_be_undone_after_interruption(self):
        plan,ref=self.flatplan();self.fp.begin(plan);self.fp.apply()
        self.fp.begin(self.fp.restore_plan());self.fp.apply(finish=False)
        self.assertNotIn(ref,self.fake.refs);self.fp.apply(reverse=True)
        self.assertEqual(self.fake.refs[ref],'a'*64)

    def job(self):
        flat,ref=self.flatplan()
        return {'schema':1,'identity':'job','home':str(self.home),'data':str(self.home/'.local/share'),
                'migrate':False,'direction':'apply','remove':True,'files':self.files.plan(self.desired(),'job'),
                'flatpak':flat,'aliases':{},'before':{'active':'','previous':'','software':''},
                'after':{'active':'','previous':'','software':''},'beforeSoftware':install.receipt(self.root),
                'prepared':'','softwareReceipt':None,'systemStarted':False,'systemPlan':'fixture','systemToken':'a'*64}

    def test_outer_journal_recovers_after_each_backend_commit(self):
        for phase in ('files','flatpak','system','software','files-committed','flatpak-committed','receipt'):
            with self.subTest(phase=phase):
                job=self.job(); manager.begin(self.root,job,self.fake)
                def checkpoint(current):
                    if current==phase:self.crash()
                with self.assertRaises(RuntimeError):manager.apply(self.root,runner=self.fake,system_action=lambda *args:None,checkpoint=checkpoint)
                self.assertIsNotNone(manager.pending(self.root))
                manager.apply(self.root,reverse=True,runner=self.fake,system_action=lambda *args:None)
                self.assertFalse(self.dst.exists());self.assertFalse(self.fake.refs)
                self.assertIsNone(manager.pending(self.root))

    def test_full_transaction_can_resume_after_inner_commit(self):
        job=self.job();manager.begin(self.root,job,self.fake)
        def checkpoint(phase):
            if phase=='files-committed':self.crash()
        with self.assertRaises(RuntimeError):manager.apply(self.root,runner=self.fake,system_action=lambda *a:None,checkpoint=checkpoint)
        manager.apply(self.root,runner=self.fake,system_action=lambda *a:None)
        self.assertEqual(self.dst.read_bytes(),b'new executable');self.assertIsNone(manager.pending(self.root))

    def test_privileged_helper_rejects_another_pending_transaction(self):
        if os.name=='nt':self.skipTest('Linux pwd')
        import runtime_system
        fs=self.base/'rootfs';ledger=fs/'var/lib/traineros/runtime-1234'
        files=Files(ledger,[fs/'var/opt/traineros/integrations'])
        files.begin(files.plan({},'b'*64))
        with patch.object(runtime_system.pwd,'getpwnam',return_value=SimpleNamespace(pw_uid=1234)):
            with self.assertRaisesRegex(ValueError,'Another privileged'):
                runtime_system.operation('commit','fixture','a'*64,filesystem=fs)

    def test_privileged_helper_commit_then_rollback_restores_original(self):
        if os.name=='nt':self.skipTest('Linux pwd')
        import runtime_system
        fs=self.base/'rootfs';target=fs/'var/opt/traineros/integrations/traineros-game-capture'
        target.parent.mkdir(parents=True);target.write_bytes(b'original helper')
        plan=self.base/'system.json';sw.atomic(plan,{'files':[{'path':'traineros-game-capture','source':str(self.src),'sha256':sw.sha256(self.src),'mode':0o755}]})
        token=sw.sha256(plan)
        with patch.object(runtime_system.pwd,'getpwnam',return_value=SimpleNamespace(pw_uid=1234)):
            runtime_system.operation('apply','fixture',token,plan,True,fs)
            runtime_system.operation('commit','fixture',token,filesystem=fs)
            runtime_system.operation('rollback','fixture',token,filesystem=fs)
        self.assertEqual(target.read_bytes(),b'original helper')

    def test_privileged_undo_after_cancelled_authorization_is_safe(self):
        if os.name=='nt':self.skipTest('Linux pwd')
        import runtime_system
        with patch.object(runtime_system.pwd,'getpwnam',return_value=SimpleNamespace(pw_uid=1234)):
            runtime_system.operation('rollback','fixture','a'*64,filesystem=self.base/'rootfs')

    def test_privileged_runtime_owner_cannot_be_replaced_by_another_user(self):
        if os.name=='nt':self.skipTest('Linux pwd')
        import runtime_system
        fs=self.base/'rootfs';plan=self.base/'system.json';sw.atomic(plan,{'files':[]});token=sw.sha256(plan)
        with patch.object(runtime_system.pwd,'getpwnam',return_value=SimpleNamespace(pw_uid=1234)):
            runtime_system.operation('apply','fixture',token,plan,filesystem=fs)
            runtime_system.operation('commit','fixture',token,filesystem=fs)
        with patch.object(runtime_system.pwd,'getpwnam',return_value=SimpleNamespace(pw_uid=5678)):
            with self.assertRaisesRegex(ValueError,'another desktop user'):
                runtime_system.operation('apply','other',token,plan,filesystem=fs)

    def test_setup_and_launcher_refuse_maintenance_during_full_recovery(self):
        job=self.job();manager.begin(self.root,job,self.fake)
        with self.assertRaisesRegex(ValueError,'Recover'):install.clean_cache(self.root)
        with self.assertRaisesRegex(ValueError,'Recover'):install.request(self.root,'rollback')
        if sys.platform=='linux':
            launched=subprocess.run([sys.executable,str(Path(__file__).resolve().parents[1]/'packaging/software/launcher.py'),
                                     '--root',str(self.root)],capture_output=True,text=True,timeout=10)
            self.assertNotEqual(launched.returncode,0);self.assertIn('interrupted',launched.stderr)

    def signed_media(self):
        key=self.base/'private.pem';public=self.root/'trusted-key.pem'
        subprocess.run(['openssl','genpkey','-algorithm','ED25519','-out',str(key)],check=True,capture_output=True)
        subprocess.run(['openssl','pkey','-in',str(key),'-pubout','-out',str(public)],check=True,capture_output=True)
        archive=self.base/'media.tar';content=b'fixture code'
        with tarfile.open(archive,'w:') as tar:
            row=tarfile.TarInfo('code.bin');row.size=len(content);tar.addfile(row,io.BytesIO(content))
        index=self.base/'index.json';sw.atomic(index,{'files':[{'path':'code.bin','bytes':len(content),'sha256':hashlib.sha256(content).hexdigest()}]})
        manifest=self.base/'runtime.json';runtime_set.publish_manifest(index,archive,key,manifest,1,'a'*40)
        return manifest,archive

    def test_runtime_signature_and_archive_identity_precede_extraction(self):
        manifest,archive=self.signed_media();envelope=sw.decode(manifest.read_bytes())
        envelope['signed']['sequence']=2;sw.atomic(manifest,envelope)
        with self.assertRaises((ValueError,subprocess.CalledProcessError)):
            runtime_set.prepare(self.root,manifest,archive)
        self.assertFalse((self.root/'runtimes/versions').exists())

    def test_incomplete_media_preparation_retries_and_changed_ready_media_is_rejected(self):
        manifest,archive=self.signed_media()
        with patch.object(runtime_set,'extract',side_effect=RuntimeError('power loss')):
            with self.assertRaises(RuntimeError):runtime_set.prepare(self.root,manifest,archive)
        stage=runtime_set.prepare(self.root,manifest,archive)
        self.assertEqual((stage/'media/code.bin').read_bytes(),b'fixture code')
        (stage/'media/code.bin').write_bytes(b'changed')
        with self.assertRaisesRegex(ValueError,'changed'):runtime_set.prepare(self.root,manifest,archive)

    def test_unsigned_archive_entries_and_path_traversal_are_rejected(self):
        archive=self.base/'bad.tar'
        with tarfile.open(archive,'w:') as tar:
            row=tarfile.TarInfo('../outside');row.size=1;tar.addfile(row,io.BytesIO(b'x'))
        with self.assertRaises(ValueError):runtime_set.extract(archive,self.base/'extract',[])
        with self.assertRaises(ValueError):runtime_set.checked_path(self.base,'../outside')


if __name__=='__main__':unittest.main()
