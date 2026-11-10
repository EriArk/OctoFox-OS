# SPDX-License-Identifier: GPL-3.0-or-later
"""Real signed OSTree/Flatpak transactions. Run in a disposable networkless container."""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'packaging/software'))
import releases as sw
from runtime_flatpak import Flatpaks


@unittest.skipUnless(all(shutil.which(x) for x in ('flatpak','ostree','gpg')), 'Requires Flatpak, OSTree and GPG')
class RuntimeFlatpakRepositoryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name); self.stage = self.base/'stage'
        self.cache = self.stage/'downloads/flathub'; self.cache.mkdir(parents=True)
        self.repo = self.cache/'repo'
        self.key = self.stage/'media/flatpak/flathub.gpg'; self.key.parent.mkdir(parents=True)
        self.gpg = self.base/'gpg'; self.gpg.mkdir(mode=0o700)
        self.env = dict(os.environ, GNUPGHOME=str(self.gpg), LC_ALL='C')
        self.command(['gpg','--batch','--passphrase','','--quick-generate-key','TrainerOS ephemeral test','ed25519','sign','0'])
        self.addCleanup(lambda: subprocess.run(['gpgconf','--kill','gpg-agent'],env=self.env,capture_output=True))
        self.key.write_bytes(subprocess.check_output(['gpg','--export'],env=self.env))
        self.command(['ostree','--repo='+str(self.repo),'init','--mode=archive-z2'])
        self.flat = Flatpaks(self.base/'installation/runtimes/flatpak')

    def command(self, args):
        p = subprocess.run(args,env=self.env,capture_output=True,text=True,timeout=30)
        if p.returncode: raise AssertionError(p.stderr)
        return p.stdout.strip()

    def row(self, version, kind='runtime'):
        name = 'org.traineros.Test' if kind=='runtime' else 'org.traineros.TestApp'
        ref = name+'/x86_64/stable'; full = kind+'/'+ref
        tree = self.base/(name+'-'+version); (tree/'files').mkdir(parents=True)
        metadata = ('[Runtime]\n' if kind=='runtime' else '[Application]\n')+f'name={name}\nruntime=org.traineros.Test/x86_64/stable\nsdk=org.traineros.Test/x86_64/stable\n'
        (tree/'metadata').write_text(metadata)
        (tree/'files/proof').write_text(version)
        commit = self.command(['ostree','--repo='+str(self.repo),'commit','--branch='+full,
            '--tree=dir='+str(tree),'--subject='+version,'--gpg-sign=TrainerOS ephemeral test',
            '--add-metadata-string=xa.ref='+full,'--add-metadata-string=xa.metadata='+metadata])
        descriptor = self.cache/(commit+'.ostree.json')
        sw.atomic(descriptor,{'schema':1,'format':'ostree','repo':str(self.repo),'key':str(self.key),
            'keySha256':sw.sha256(self.key),'ref':ref,'kind':kind,'commit':commit})
        return {'ref':ref,'kind':kind,'commit':commit,'file':'unused.flatpak',
                'preparedFile':str(descriptor),'sha256':sw.sha256(descriptor)}

    def activate(self, rows, finish=True):
        self.flat.begin(self.flat.plan(self.stage, rows)); self.flat.apply(finish=finish)

    def test_install_update_interruption_rollback_and_remove_without_network(self):
        old = [self.row('old'), self.row('old','app')]
        new = [self.row('new'), self.row('new','app')]
        # Remote staging refs already point to new. Explicit old commits must win.
        self.activate(old)
        for row in old: self.assertEqual(self.flat.commit(row['ref']), row['commit'])
        save = Path(self.flat.env['HOME'])/'.var/app/org.traineros.TestApp/save'
        save.parent.mkdir(parents=True); save.write_text('personal save')
        self.activate(new, finish=False)
        for row in new: self.assertEqual(self.flat.commit(row['ref']), row['commit'])
        self.flat.apply(reverse=True)
        for row in old: self.assertEqual(self.flat.commit(row['ref']), row['commit'])
        self.activate(new)
        self.flat.begin(self.flat.restore_plan()); self.flat.apply(finish=False)
        self.assertFalse(self.flat.commit(new[0]['ref']))
        self.flat.apply(reverse=True)
        for row in new: self.assertEqual(self.flat.commit(row['ref']), row['commit'])
        self.flat.begin(self.flat.restore_plan()); self.flat.apply()
        self.assertFalse(self.flat.commit(new[1]['ref']))
        self.assertEqual(save.read_text(),'personal save')
        self.assertFalse(list(self.cache.glob('*.flatpak')))

    def test_unsigned_commit_and_corrupt_objects_cannot_be_deployed(self):
        row = self.row('unsigned'); commit = row['commit']
        (self.repo/'objects'/commit[:2]/(commit[2:]+'.commitmeta')).unlink()
        with self.assertRaisesRegex(ValueError,'repository operation failed'): self.activate([row])
        self.assertFalse(self.flat.commit(row['ref']))
        self.flat.apply(reverse=True)
        previous_objects = set((self.repo/'objects').glob('*/*.filez'))
        row = self.row('corrupt')
        obj = next(iter(set((self.repo/'objects').glob('*/*.filez')) - previous_objects))
        obj.write_bytes(b'corrupt compressed object')
        with self.assertRaises(ValueError): self.activate([row])
        self.assertFalse(self.flat.commit(row['ref']))

    def test_legacy_bundle_recovery_survives_repository_update(self):
        old = self.row('old'); bundle = self.stage/'media/flatpak/old.flatpak'
        self.command(['flatpak','build-bundle','--runtime','--arch=x86_64',str(self.repo),str(bundle),'org.traineros.Test','stable'])
        legacy = dict(old, file=bundle.name, sha256=sw.sha256(bundle)); del legacy['preparedFile']
        self.activate([legacy])
        new = self.row('new'); self.activate([new], finish=False)
        self.flat.apply(reverse=True)
        self.assertEqual(self.flat.commit(old['ref']),old['commit'])
        self.activate([new])
        self.flat.begin(self.flat.restore_plan()); self.flat.apply()
        self.assertFalse(self.flat.commit(old['ref']))


if __name__ == '__main__': unittest.main()
