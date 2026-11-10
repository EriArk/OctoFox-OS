# SPDX-License-Identifier: GPL-3.0-or-later
"""Offline Flatpak bundle/OSTree transactions; never remove application data or force dependencies."""
import os
from pathlib import Path
import subprocess
import installation as install
import releases as sw
import runtime_layout


class Flatpaks:
    def __init__(self, root, data=None, runner=subprocess.run):
        self.root = install.private(root)
        self.data = Path(data) if data is not None else runtime_layout.paths(self.root.parent.parent)[1]
        self.run = runner
        self.env = runtime_layout.environment(self.data.parent.parent, os.environ)
        self.env.update(XDG_DATA_HOME=str(self.data), FLATPAK_USER_DIR=str(self.data/'flatpak'),
                        TMPDIR=str(self.root), LC_ALL='C')

    def command(self, args):
        p = self.run(['flatpak', *args], env=self.env, capture_output=True, text=True, timeout=1800)
        if p.returncode: raise ValueError('Flatpak operation failed: ' + p.stderr[-2000:])
        return p.stdout.strip()

    def install_artifact(self, path, expected, row, desired):
        path = Path(path)
        if path.is_symlink() or any(p.is_symlink() for p in path.parents) or sw.sha256(path) != expected:
            raise ValueError('Flatpak recovery artifact changed')
        if not path.name.endswith('.ostree.json'):
            # Older journals and the modified PPSSPP runtime still use bundles.
            self.command(['--user','install','--reinstall','--noninteractive','--no-deps','--no-related','--bundle',str(path)])
            return
        artifact = install.read(path)
        if (set(artifact) != {'schema','format','repo','key','keySha256','ref','kind','commit'}
                or artifact['schema'] != 1 or artifact['format'] != 'ostree'
                or any(artifact[k] != row[k] for k in ('ref','kind'))
                or artifact['commit'] != desired or not sw.HASH.fullmatch(desired)):
            raise ValueError('Flatpak repository artifact identity changed')
        source, key = Path(artifact['repo']), Path(artifact['key'])
        if (source != path.parent / 'repo' or not source.is_dir()
                or any(p.is_symlink() for p in (source,key,*source.parents,*key.parents))
                or sw.sha256(key) != artifact['keySha256']):
            raise ValueError('Flatpak repository or signing key changed')
        import runtime_flathub
        repository = install.private(self.data / 'flatpak/repo')
        remote = 'traineros-flathub'
        def ostree(args):
            p = self.run(['ostree','--repo='+str(repository),*args], env=self.env,
                         capture_output=True,text=True,timeout=1800)
            if p.returncode: raise ValueError('Flatpak repository operation failed: '+p.stderr[-2000:])
            return p.stdout.strip()
        if not (repository / 'config').exists(): ostree(['init','--mode=bare-user-only'])
        ostree(['remote','add','--if-not-exists','--gpg-import='+str(key),
                '--set=gpg-verify=true','--set=gpg-verify-summary=true',
                '--set=xa.noenumerate=true','--set=xa.nodeps=true',remote,runtime_flathub.URL])
        if ostree(['remote','show-url',remote]) != runtime_flathub.URL:
            raise ValueError('TrainerOS Flatpak remote changed')
        for setting in ('gpg-verify','gpg-verify-summary'):
            if ostree(['config','get','remote "'+remote+'".'+setting]) != 'true':
                raise ValueError('Flatpak signature verification must remain enabled')
        # Verify the exact signed commit and its objects, without network access
        # or following the remote's newest ref. Existing deployments stay live
        # until Flatpak performs its normal atomic deployment.
        ostree(['pull-local','--untrusted','--remote='+remote,'--gpg-verify',str(source),desired])
        ref = row['kind']+'/'+row['ref']
        ostree(['refs','--force','--create='+remote+':'+ref,desired])
        self.command(['--user','install','--no-pull','--reinstall','--noninteractive',
                      '--no-deps','--no-related',remote,ref])

    def commit(self, ref):
        p = self.run(['flatpak', '--user', 'info', '--show-commit', ref], env=self.env, capture_output=True, text=True, timeout=30)
        if p.returncode:
            if 'not installed' in p.stderr: return ''
            raise ValueError('Cannot inspect the existing Flatpak installation: '+p.stderr[-2000:])
        value = p.stdout.strip()
        if not sw.HASH.fullmatch(value): raise ValueError('Invalid installed Flatpak identity')
        return value

    def current(self, app):
        path = self.data / 'flatpak/app' / app / 'current'
        return os.readlink(path) if path.is_symlink() else ''

    def plan(self, stage, rows, migrate=False):
        if install.read(self.root/'transaction.json'): raise ValueError('Recover Flatpak operation first')
        operations = []; baseline = install.read(self.root / 'baseline.json', {})
        previous = {r['ref']:r for r in install.read(self.root/'current.json',[])}
        owned = install.read(self.root / 'owned.json', {})
        for row in sorted(rows, key=lambda x:(x['kind']=='app', x['ref'])):
            source = Path(row.get('preparedFile', stage / 'media/flatpak' / row['file']))
            if 'preparedFile' in row:
                if (source.is_symlink() or source.parent != stage / 'downloads/flathub'
                        or any(p.is_symlink() for p in source.parents)
                        or sw.sha256(source) != row['sha256']):
                    raise ValueError('Upstream Flatpak preparation changed')
            ref = row['ref']; before = self.commit(ref); expected = row['commit']
            if ref in owned and before != owned[ref]['commit']:
                raise ValueError('Flatpak changed outside TrainerOS: ' + ref)
            if before and before != expected and ref not in owned and not migrate:
                raise ValueError('Existing Flatpak version requires migration with a backup: ' + ref)
            record = {'ref': ref, 'kind': row['kind'], 'before': before, 'after': expected,
                      'file': str(source), 'sha256': row['sha256'],
                      'currentBefore': self.current(ref.split('/')[0]) if row['kind']=='app' else '',
                      'currentAfter': '/'.join(ref.split('/')[1:]) if row['kind']=='app' else ''}
            if before:
                old = previous.get(ref)
                if before == expected:
                    backup = Path(record['file'])
                elif old and old['after'] == before:
                    backup = Path(old['file'])
                    if sw.sha256(backup) != old['sha256']: raise ValueError('Previous runtime package is damaged')
                else: backup = self.root / (before + '.flatpak')
                if not backup.exists():
                    name, arch, branch = ref.split('/')
                    self.command(['build-bundle', '--arch='+arch, *(['--runtime'] if row['kind']=='runtime' else []),
                                  str(self.data / 'flatpak/repo'), str(backup), name, branch])
                record.update(backup=str(backup), backupSha256=sw.sha256(backup))
            if ref not in owned: baseline[ref] = record
            operations.append(record)
        return {'operations': operations, 'baseline': baseline, 'beforeOwned': owned,
                'afterOwned': {r['ref']:{'commit':r['after']} for r in operations},
                'beforeCurrent':list(previous.values()), 'direction':'apply'}

    def begin(self, plan):
        if install.read(self.root / 'transaction.json'): raise ValueError('Flatpak recovery is pending')
        for row in plan['operations']:
            if self.commit(row['ref']) != row['before']: raise ValueError('Flatpak changed after preflight')
        sw.atomic(self.root / 'transaction.json', plan)

    def apply(self, reverse=False, finish=True, progress=lambda *args:None):
        plan = install.read(self.root / 'transaction.json')
        if not plan: raise ValueError('No Flatpak transaction')
        if reverse: plan['direction']='rollback'; sw.atomic(self.root / 'transaction.json', plan)
        reverse = plan['direction']=='rollback'
        # Restore/install dependencies first; remove applications before runtimes.
        rows = sorted(plan['operations'], key=lambda r:(not bool(r['before' if reverse else 'after']),
                       r['kind']=='app' if r['before' if reverse else 'after'] else r['kind']=='runtime', r['ref']))
        for row in rows:
            if self.commit(row['ref']) not in (row['before'], row['after']):
                raise ValueError('Flatpak changed during recovery; preserving it: ' + row['ref'])
        for row in rows:
            progress('Flatpak: '+row['ref'])
            desired = row['before'] if reverse else row['after']
            if self.commit(row['ref']) != desired:
                if not desired:
                    self.command(['--user','uninstall','--noninteractive','--no-related',row['ref']])
                else:
                    self.install_artifact(row['backup'] if reverse else row['file'],
                                          row['backupSha256'] if reverse else row['sha256'], row, desired)
            if self.commit(row['ref']) != desired: raise ValueError('Flatpak installation identity mismatch')
            if row['kind']=='app':
                app,arch,branch=row['ref'].split('/')
                current = row['currentBefore'] if reverse else row['currentAfter']
                if current:
                    parts=current.split('/')
                    if len(parts)!=2 or any(x in ('','..','.') for x in parts): raise ValueError('Invalid Flatpak current branch')
                    self.command(['--user','make-current','--arch='+parts[0],app,parts[1]])
        if finish: self.finish()

    def finish(self):
        plan = install.read(self.root / 'transaction.json')
        reverse = plan['direction']=='rollback'
        for row in plan['operations']:
            if self.commit(row['ref']) != row['before' if reverse else 'after']: raise ValueError('Incomplete Flatpak transaction')
        sw.atomic(self.root / 'baseline.json', plan['baseline'])
        sw.atomic(self.root / 'owned.json', plan['beforeOwned'] if reverse else plan['afterOwned'])
        sw.atomic(self.root / 'current.json', plan['beforeCurrent'] if reverse else [r for r in plan['operations'] if r['after']])
        (self.root / 'transaction.json').unlink()

    def restore_plan(self):
        records = install.read(self.root / 'baseline.json', {})
        previous = install.read(self.root/'current.json', [])
        artifacts = {r['ref']:r for r in previous}
        owned = install.read(self.root / 'owned.json', {})
        ops=[]
        for ref, owner in owned.items():
            old = records[ref]; current=self.commit(ref)
            if current!=owner['commit']: raise ValueError('Flatpak changed outside TrainerOS: '+ref)
            artifact=artifacts[ref]
            if sw.sha256(artifact['file'])!=artifact['sha256']: raise ValueError('Runtime recovery artifact changed')
            ops.append({'ref':ref,'kind':old['kind'],'before':current,'after':old['before'],
                        'file':old.get('backup',''),'sha256':old.get('backupSha256',''),
                        'backup':artifact['file'],'backupSha256':artifact['sha256'],
                        'currentBefore':self.current(ref.split('/')[0]) if old['kind']=='app' else '',
                        'currentAfter':old['currentBefore']})
        return {'operations':sorted(ops,key=lambda x:(x['kind']=='app',x['ref'])), 'direction':'apply',
                'baseline':install.read(self.root/'baseline.json',{}),
                'beforeOwned':owned,'afterOwned':{},'beforeCurrent':previous}
