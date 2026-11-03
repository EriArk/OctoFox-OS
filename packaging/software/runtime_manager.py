# SPDX-License-Identifier: GPL-3.0-or-later
"""Coordinate offline runtime files, user Flatpaks and privileged helpers.

The caller holds both Software locks. A durable outer journal survives every
inner commit, so interruption never permits launching a mixed installation.
"""
import hashlib
import os
from pathlib import Path
import subprocess
import uuid
import installation as install
import releases as sw
import runtime_set as runtime
import runtime_layout
from runtime_transaction import Files
from runtime_flatpak import Flatpaks


def receipt(root):
    return install.read(Path(root)/'runtimes/receipt.json', {'active':'','previous':'','software':''})


def pending(root):
    return install.read(Path(root)/'runtimes/transaction.json')


def system(root, action, job):
    import pwd
    for name, digest in install.read(root/'bootstrap-files.json').items():
        path=root/'bootstrap/packaging'/name
        if path.is_symlink() or sw.sha256(path)!=digest: raise ValueError('Setup bootstrap was modified')
    helper=root/'bootstrap/packaging/software/runtime_system.py'
    args=['pkexec','/usr/bin/python3','-I',str(helper),action,'--user',pwd.getpwuid(os.getuid()).pw_name,
          '--token',job['systemToken'],'--plan',job['systemPlan']]
    if job['migrate']: args.append('--migrate')
    subprocess.run(args,check=True)


def engines(root, job, runner=subprocess.run):
    return (Files(root/'runtimes/files',[Path(job['home']),Path(job['data'])]),
            Flatpaks(root/'runtimes/flatpak',Path(job['data']),runner))


def plan(root, stage=None, prepared=None, *, remove=False, migrate=False, home=None, data=None,
         make_environments=True, runner=subprocess.run, software_receipt=None, progress=lambda *args:None):
    root=Path(root)
    if pending(root): raise ValueError('Recover the interrupted full installation first')
    home,data=runtime_layout.paths(root)
    before=receipt(root); before_software=install.receipt(root)
    if before['active'] and before.get('layout') != runtime_layout.LAYOUT:
        raise ValueError('Old shared-target runtime candidate must be recovered/removed with its original Setup')
    ident=uuid.uuid4().hex; envelope=None
    if remove:
        files=Files(root/'runtimes/files',[home,data]); desired={}; system_rows=[]; aliases={}
        next_receipt={'active':'','previous':'','software':''}
        flatplan=Flatpaks(root/'runtimes/flatpak',data,runner).restore_plan()
    else:
        stage=Path(stage)
        envelope=runtime.signed(stage/'release.json',root/'trusted-key.pem')
        expected=hashlib.sha256(sw.canonical(envelope['signed'])).hexdigest()
        if stage != root/'runtimes/versions'/expected: raise ValueError('Runtime generation outside managed storage')
        runtime.verify_media(stage,envelope)
        if prepared:
            software=sw.verified(Path(prepared)/'release.json',root/'trusted-key.pem')['signed']
        else:
            software=install.version(root,(software_receipt or before_software)['active'])
        if software['source'] != envelope['signed']['softwareSource']: raise ValueError('Software and runtime media are from different builds')
        if before['active'] and expected!=before['previous']:
            old=runtime.signed(root/'runtimes/versions'/before['active']/'release.json',root/'trusted-key.pem')['signed']
            if envelope['signed']['sequence'] <= old['sequence'] and expected!=before['active']:
                raise ValueError('Runtime downgrade or reused sequence requires Recovery')
        files,desired,system_rows,aliases=runtime.deployment(root,stage,home,data,make_environments,progress)
        progress('Preparing Flatpak recovery copies')
        flatplan=Flatpaks(root/'runtimes/flatpak',data,runner).plan(stage,runtime.flatpak_rows(stage),migrate)
        next_receipt={'layout':runtime_layout.LAYOUT,'active':expected,'previous':before['active'] if expected!=before['active'] else before['previous'],
                      'software':''}
    fileplan=files.plan(desired,ident,False)
    if not migrate:
        for row in system_rows:
            path=Path('/var/opt/traineros/integrations')/row['path']
            if path.exists() and (path.is_symlink() or not path.is_file() or sw.sha256(path)!=row['sha256']):
                raise ValueError('Existing system helper needs migration with a recovery copy: '+str(path))
    jobs=install.private(root/'runtimes/jobs')
    systemplan=jobs/(ident+'-system.json')
    sw.atomic(systemplan,{'schema':1,'operation':ident,'files':system_rows})
    return {'schema':1,'identity':ident,'home':str(home),'data':str(data),'migrate':migrate,
            'direction':'apply','remove':remove,'files':fileplan,'flatpak':flatplan,'aliases':aliases,
            'before':before,'after':next_receipt,'beforeSoftware':before_software,
            'prepared':str(prepared) if prepared else '', 'softwareReceipt':software_receipt,
            'systemPlan':str(systemplan),'systemToken':sw.sha256(systemplan),'systemStarted':False}


def begin(root, job, runner=subprocess.run):
    root=Path(root)
    if pending(root): raise ValueError('Full installation recovery is pending')
    runtime.check_aliases(job['aliases'])
    runtime.idle((op['path'] for op in job['files']['operations']), owned_home=job['home'])
    files,flatpaks=engines(root,job,runner)
    # Outer intent precedes even the first inner journal write.
    sw.atomic(root/'runtimes/transaction.json',job)


def reopen(engine_root, plan):
    current=install.read(engine_root/'transaction.json')
    if current and (current['operations']!=plan['operations'] or current.get('beforeOwned')!=plan.get('beforeOwned')):
        raise ValueError('Conflicting runtime recovery journal')
    if not current: sw.atomic(engine_root/'transaction.json',plan)


def apply(root, *, reverse=False, runner=subprocess.run, system_action=system, checkpoint=lambda phase:None):
    root=Path(root); job=pending(root)
    if not job: raise ValueError('No full installation to recover')
    if reverse:
        job['direction']='rollback'; sw.atomic(root/'runtimes/transaction.json',job)
    reverse=job['direction']=='rollback'
    runtime.check_aliases(job['aliases'])
    runtime.idle((op['path'] for op in job['files']['operations']), owned_home=job['home'])
    files,flatpaks=engines(root,job,runner)
    reopen(files.root,job['files']); reopen(flatpaks.root,job['flatpak'])
    files.apply(reverse,finish=False,checkpoint=lambda *args:checkpoint('runtime-files')); checkpoint('files')
    flatpaks.apply(reverse,finish=False,progress=checkpoint); checkpoint('flatpak')
    if not reverse:
        job['systemStarted']=True; sw.atomic(root/'runtimes/transaction.json',job)
        system_action(root,'apply',job); checkpoint('system')
        if job['prepared']: install.install_prepared(root,job['prepared'])
        elif job['softwareReceipt']:
            validate_software_receipt(root,job['softwareReceipt'])
            sw.atomic(root/'receipt.json',job['softwareReceipt'])
        checkpoint('software')
        system_action(root,'commit',job)
    else:
        if job['systemStarted']: system_action(root,'rollback',job)
        validate_software_receipt(root,job['beforeSoftware'])
        sw.atomic(root/'receipt.json',job['beforeSoftware'])
    files.finish(); checkpoint('files-committed')
    flatpaks.finish(); checkpoint('flatpak-committed')
    after=job['before'] if reverse else job['after']
    if not reverse and not job['remove']:
        after['software']=install.receipt(root)['active']
        sw.atomic(root/'runtimes/versions'/after['active']/'software-receipt.json',install.receipt(root))
    sw.atomic(root/'runtimes/receipt.json',after)
    checkpoint('receipt')
    sw.atomic(root/'runtimes/last-operation.json',{'identity':job['identity'],'direction':job['direction']})
    (root/'runtimes/transaction.json').unlink()
    return {'status':'restored' if reverse else ('runtimes-removed' if job['remove'] else 'installed')}


def validate_software_receipt(root, value):
    if value['active']:
        release=install.version(root,value['active'])
        install.host.compatible(release,install.host.schemas(install.configuration(root)['dataDirectory']))


def rollback_plan(root, **kwargs):
    old=receipt(root)['previous']
    if not old: raise ValueError('No previous full runtime generation')
    stage=Path(root)/'runtimes/versions'/old
    value=install.read(stage/'software-receipt.json')
    if not value: raise ValueError('Previous Software pairing is unavailable')
    validate_software_receipt(root,value)
    return plan(root,stage,software_receipt=value,**kwargs)


def audit(root, runner=subprocess.run):
    root=Path(root); problems=[]
    if pending(root): problems.append('Full installation needs recovery')
    home,data=runtime_layout.paths(root)
    files=Files(root/'runtimes/files',[home])
    for path,state in files.owned().items():
        try:
            if files.snapshot(path)!=state: problems.append('Changed runtime code: '+path)
        except (OSError,ValueError) as error: problems.append(str(error))
    flatpaks=Flatpaks(root/'runtimes/flatpak',data,runner=runner)
    for ref,state in install.read(flatpaks.root/'owned.json',{}).items():
        if flatpaks.commit(ref)!=state['commit']: problems.append('Changed Flatpak: '+ref)
    active=receipt(root)['active']
    if active:
        stage=root/'runtimes/versions'/active
        try:
            runtime.signed(stage/'release.json',root/'trusted-key.pem')
            for name in runtime.ENVIRONMENTS:
                if install.read(stage/'venvs'/(name+'.json'))['files']!=runtime.environment_files(stage/'venvs'/name):
                    problems.append('Changed Python environment: '+name)
        except (OSError,ValueError,KeyError,TypeError) as error: problems.append(str(error))
    return {'status':'needs-attention' if problems else 'ready','problems':problems,
            'scope':'user-runtime-files-and-flatpak-identities; privileged helpers checked during activation'}
