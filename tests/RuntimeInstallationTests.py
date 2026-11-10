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
import runtime_layout
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


@unittest.skipUnless(sys.platform=='linux','Runtime activation is supported on Linux only')
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

    def test_private_deployment_ignores_existing_emulators_and_environment(self):
        stage=self.base/'private-stage';component=stage/'media/runtimes/Cemu';component.mkdir(parents=True)
        record={'files':[{'path':'Cemu.AppImage','bytes':14,'sha256':sw.sha256(self.src),'mode':0o644}]}
        sw.atomic(component/'component.json',record)
        source=self.base/'image-source';source.mkdir();(source/'Cemu.AppImage').write_bytes(self.src.read_bytes())
        existing=self.home/'Applications/Cemu.AppImage';existing.write_bytes(b'EmuDeck runtime')
        with patch.object(runtime_set,'NATIVE',set()),patch.object(runtime_set,'IMAGES',{'Cemu'}),patch.object(runtime_set,'EXTRAS',set()),patch.object(runtime_set,'component',return_value=(record,source)):
            files,desired,_,aliases=runtime_set.deployment(self.root,stage,self.home,self.home/'data',False)
        target=self.root/'runtime-home/Applications/Cemu.AppImage'
        self.assertEqual(set(desired),{str(target)});self.assertEqual(aliases,{})
        files.begin(files.plan(desired,'private'));files.apply()
        self.assertEqual(target.stat().st_mode & 0o777, 0o755)
        self.assertEqual(target.read_bytes(), self.src.read_bytes())
        files.begin(files.plan({},'remove'));files.apply()
        self.assertEqual(existing.read_bytes(),b'EmuDeck runtime');self.assertFalse(target.exists())

    def test_private_flatpak_environment_overrides_inherited_emudeck_paths(self):
        private,data=runtime_layout.paths(self.root)
        with patch.dict(os.environ,{'HOME':str(self.home),'FLATPAK_USER_DIR':str(self.home/'emudeck-flatpak')}):
            flat=Flatpaks(self.root/'isolated-flatpak',data,self.fake)
            default=Flatpaks(self.root/'runtimes/flatpak',runner=self.fake)
        self.assertEqual(default.data,data)
        self.assertEqual(default.env['FLATPAK_USER_DIR'],str(data/'flatpak'))
        self.assertEqual(flat.env['HOME'],str(private))
        self.assertEqual(flat.env['FLATPAK_USER_DIR'],str(data/'flatpak'))
        self.assertEqual(flat.env['XDG_CONFIG_HOME'],str(private/'.config'))
        self.assertNotEqual(flat.env['HOME'],str(self.home))

    def test_private_home_alias_cannot_redirect_installation_into_user_data(self):
        (self.root/'runtime-home').symlink_to(self.home,target_is_directory=True)
        with self.assertRaisesRegex(ValueError,'Linked private'):runtime_layout.paths(self.root)

    def test_old_shared_runtime_candidate_is_not_silently_adopted(self):
        (self.root/'runtimes').mkdir(exist_ok=True)
        sw.atomic(self.root/'runtimes/receipt.json',{'active':'old','previous':'','software':''})
        with self.assertRaisesRegex(ValueError,'shared-target'):manager.plan(self.root,remove=True)

    def test_runtime_maintenance_blocks_private_children_but_not_other_emulators(self):
        private,_=runtime_layout.paths(self.root)
        other=subprocess.Popen([sys.executable,'-c','import time; time.sleep(30)'],env=dict(os.environ,HOME=str(self.home)))
        owned=None
        try:
            runtime_set.idle(owned_home=private)
            owned=subprocess.Popen([sys.executable,'-c','import time; time.sleep(30)'],env=dict(os.environ,HOME=str(private)))
            with self.assertRaisesRegex(ValueError,'Close TrainerOS'):runtime_set.idle(owned_home=private)
        finally:
            for process in (owned,other):
                if process:process.terminate();process.wait(timeout=5)

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

    def test_import_does_not_trust_a_damaged_existing_blob(self):
        state=self.files.import_file(self.src,0o755)
        (self.files.blobs/state['sha256']).write_bytes(b'damaged')
        with self.assertRaisesRegex(ValueError,'damaged'):self.files.import_file(self.src,0o755)

    def test_code_copies_remain_independent_and_fallback_preserves_bytes(self):
        import errno
        from runtime_transaction import copy_code
        target=self.base/'copy'
        with patch('fcntl.ioctl',side_effect=OSError(errno.EOPNOTSUPP,'unsupported')):
            with self.src.open('rb') as source,target.open('wb') as output:copy_code(source,output)
        self.assertEqual(target.read_bytes(),self.src.read_bytes())
        desired=self.desired();self.files.begin(self.files.plan(desired,'copy'));self.files.apply()
        self.dst.write_bytes(b'user edit')
        self.assertEqual(self.src.read_bytes(),b'new executable')
        self.assertEqual((self.files.blobs/desired[str(self.dst)]['sha256']).read_bytes(),b'new executable')

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

    def test_flatpak_read_error_is_not_treated_as_an_absent_installation(self):
        self.fp.run=lambda *a,**k:SimpleNamespace(returncode=1,stdout='',stderr='Permission denied reading installed repository')
        with self.assertRaisesRegex(ValueError,'Cannot inspect'):self.fp.commit('org.test.Game/aarch64/stable')

    def test_flatpak_remove_can_be_undone_after_interruption(self):
        plan,ref=self.flatplan();self.fp.begin(plan);self.fp.apply()
        self.fp.begin(self.fp.restore_plan());self.fp.apply(finish=False)
        self.assertNotIn(ref,self.fake.refs);self.fp.apply(reverse=True)
        self.assertEqual(self.fake.refs[ref],'a'*64)

    def test_system_helper_consent_does_not_repeat_preparation(self):
        envelope={'signed':{'softwareSource':'a'*40,'sequence':1}}
        identity=hashlib.sha256(sw.canonical(envelope['signed'])).hexdigest()
        stage=self.root/'runtimes/versions'/identity
        helpers=self.base/'system-helpers';helpers.mkdir();(helpers/'helper').write_bytes(b'old')
        def mapped_path(value):
            return helpers if str(value)=='/var/opt/traineros/integrations' else Path(value)
        with patch.object(manager,'Path',side_effect=mapped_path), \
             patch.object(manager.runtime,'signed',return_value=envelope), \
             patch.object(manager.runtime,'verify_media'), \
             patch.object(manager.install,'version',return_value={'source':'a'*40}), \
             patch.object(manager.runtime,'flatpak_rows',return_value=[]), \
             patch.object(manager.runtime,'deployment',return_value=(self.files,{},[{'path':'helper','sha256':'b'*64}],{})) as prepare:
            decisions=[]
            job=manager.plan(self.root,stage,runner=self.fake,
                             confirm_migration=lambda message:decisions.append(message) or True)
            self.assertTrue(job['migrate']);self.assertEqual(len(decisions),1)
            prepare.assert_called_once()
            with self.assertRaisesRegex(ValueError,'needs migration'):
                manager.plan(self.root,stage,runner=self.fake,confirm_migration=lambda message:False)
        self.assertFalse(manager.pending(self.root))
        self.assertEqual((helpers/'helper').read_bytes(),b'old')

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
