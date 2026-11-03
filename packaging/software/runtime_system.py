#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Privileged code-only capture/Remote Play projection; no session/boot changes."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import pwd
import re
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
import installation as install
import releases as sw
from runtime_transaction import Files


def operation(action, user, token, plan_file=None, migrate=False, filesystem=Path('/')):
    control=install.private(filesystem/'var/lib/traineros/runtime-control')
    with sw.cache_lock(control):
        return locked_operation(action,user,token,plan_file,migrate,filesystem)


def locked_operation(action, user, token, plan_file, migrate, filesystem):
    if not re.fullmatch('[0-9a-f]{64}', token): raise ValueError('Invalid runtime transaction token')
    account = pwd.getpwnam(user)
    if not account.pw_uid: raise ValueError('Runtime owner must be a desktop user')
    owner_path=filesystem/'var/lib/traineros/runtime-control/owner.json'
    owner=install.read(owner_path)
    if owner and owner['uid']!=account.pw_uid: raise ValueError('System runtimes belong to another desktop user')
    if not owner and action=='apply': sw.atomic(owner_path,{'uid':account.pw_uid})
    base = filesystem / 'var/opt/traineros/integrations'
    ledger = filesystem / ('var/lib/traineros/runtime-' + str(account.pw_uid))
    files = Files(ledger, [base]); job = ledger / (token + '.json')
    pending = files.pending()
    if pending and pending['identity'] != token:
        raise ValueError('Another privileged runtime operation needs recovery')
    if action == 'apply':
        if not job.exists():
            raw = Path(plan_file).read_bytes()
            if len(raw) > sw.MAX_MANIFEST or hashlib.sha256(raw).hexdigest()!=token: raise ValueError('Runtime system plan changed')
            rows = json.loads(raw)['files']; desired = {}
            for row in rows:
                name = sw.relative(row['path'])
                if name != 'traineros-game-capture' and not name.startswith('remote-play/'):
                    raise ValueError('Unexpected privileged runtime target')
                source = Path(row['source'])
                if source.is_symlink() or not source.is_file() or sw.sha256(source)!=row['sha256'] or row['mode'] not in (0o644,0o755):
                    raise ValueError('Invalid privileged runtime input')
                desired[str(base/name)] = files.import_file(source,row['mode'])
            plan = files.plan(desired, token, migrate=migrate)
            sw.atomic(job,plan)
        plan = install.read(job)
        if not files.pending(): sw.atomic(ledger/'transaction.json',plan)
        files.apply(finish=False)
    elif action in ('commit','rollback'):
        plan = install.read(job)
        # Authentication can be cancelled before this helper ever creates a job.
        if not plan and action=='rollback' and not files.pending(): return
        if not plan: raise ValueError('Unknown privileged runtime transaction')
        if not files.pending(): sw.atomic(ledger/'transaction.json',plan)
        if action=='rollback': files.apply(reverse=True)
        else: files.finish()
    else: raise ValueError('Unknown privileged runtime operation')


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('action',choices=['apply','commit','rollback']);p.add_argument('--user',required=True)
    p.add_argument('--token',required=True);p.add_argument('--plan',type=Path);p.add_argument('--migrate',action='store_true')
    args=p.parse_args()
    if os.geteuid()!=0: p.error('System runtime projection requires the normal administrator authorization')
    operation(args.action,args.user,args.token,args.plan,args.migrate)
