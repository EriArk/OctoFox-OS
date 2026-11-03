#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Build one signed offline Setup candidate; does not publish or clear licenses."""
import argparse
import json
from pathlib import Path
import shutil
import tarfile
import tempfile
import fullbundle
import installer
import releases as sw
import runtime_set


def build(archive, software, key, public, output, sequence, source_archive, source_root=None):
    archive,software,output=Path(archive),Path(software),Path(output)
    source_root=Path(source_root or Path(__file__).resolve().parents[2])
    if output.exists(): raise ValueError('Use a new candidate output directory')
    release=sw.verified(software/'release.json',public)['signed']
    source_archive=Path(source_archive)
    with tarfile.open(source_archive) as tar:
        if tar.pax_headers.get('comment')!=release['source']:
            raise ValueError('Corresponding source archive must identify this exact Software revision')
    app=software/'traineros.tar.gz'
    if app.stat().st_size!=release['archive']['size'] or sw.sha256(app)!=release['archive']['sha256']:
        raise ValueError('Software archive changed')
    fullbundle.verify(archive)
    with tarfile.open(archive,'r:') as tar: index=json.load(tar.extractfile('fullbundle.json'))
    output.mkdir(parents=True)
    with tempfile.TemporaryDirectory(dir=output,prefix='.setup-') as temp:
        temp=Path(temp); tree=temp/'TrainerOS-Setup';tree.mkdir()
        holder=temp/'bootstrap';holder.mkdir();installer.bootstrap(holder,source_root/'packaging')
        shutil.copytree(holder/'bootstrap/packaging',tree/'packaging')
        shutil.copyfile(holder/'bootstrap-files.json',tree/'setup-files.json')
        setup_inventory_sha=sw.sha256(tree/'setup-files.json')
        shutil.copyfile(public,tree/'trusted-key.pem')
        sw.atomic(tree/'bootstrap.json',{'schema':1,'publicKey':'trusted-key.pem','defaultChannel':'preview',
            'feeds':{name:'https://raw.githubusercontent.com/EriArk/TrainerOS/updates/'+name+'.json' for name in ('beta','preview')}})
        media_index=temp/'inventory.json';sw.atomic(media_index,index)
        runtime_set.publish_manifest(media_index,archive,key,tree/'runtime-set.json',sequence,release['source'])
        runtime_set.signed(tree/'runtime-set.json',public)
        shutil.copyfile(source_root/'LICENSE',tree/'LICENSE')
        launch=tree/'Install TrainerOS.sh'
        launch.write_text('#!/bin/sh\nset -eu\nHERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)\nexec /usr/bin/python3 "$HERE/packaging/software/installer.py" --gui\n')
        launch.chmod(0o755)
        (tree/'README.txt').write_text('OFFLINE SETUP CANDIDATE - NOT A PUBLIC RELEASE\n'
            'Extract the entire archive onto storage with enough free space, then open Install TrainerOS.sh in Armada Desktop.\n'
            'Setup installs the signed Software, emulator set and pinned offline dependencies. Run as your desktop user.\n'
            'System helpers/session registration request normal administrator authorization. Boot defaults stay unchanged.\n'
            'Emulators use a private runtime-home alongside EmuDeck and other installations, including separate Flatpak data.\n'
            'Only TrainerOS-owned code is updated or removed. Personal games, firmware, saves and accounts are not included.\n'
            'Use Setup and Recovery after interruption; do not launch an incomplete installation.\n'
            'Requires the compatible Armada Python and system libraries. No network fallback for offline packages.\n'
            'Redistribution/source review and clean privileged device acceptance remain pending.\n')
        def permissions(info):
            info.uid=info.gid=0;info.uname=info.gname='';info.mode=0o755 if info.isdir() or info.name.endswith('.sh') else 0o644
            return info
        target=output/'TrainerOS-Full-Setup-CANDIDATE.tar'
        with tarfile.open(target,'x:') as tar:
            tar.add(tree,arcname=tree.name,filter=permissions)
            tar.add(archive,arcname=tree.name+'/runtimes.tar',filter=permissions)
            for name in ('release.json','traineros.tar.gz'):
                tar.add(software/name,arcname=tree.name+'/offline/'+name,filter=permissions)
            tar.add(source_archive,arcname=tree.name+'/sources/traineros-source.tar.gz',filter=permissions)
        # Export identities for review without disclosing any signing material.
        shutil.copyfile(tree/'runtime-set.json',output/'runtime-set.json')
    record={'schema':1,'file':target.name,'bytes':target.stat().st_size,'sha256':sw.sha256(target),
            'softwareSource':release['source'],'runtimeSequence':sequence,'publicKeySha256':sw.sha256(public),
            'sourceArchiveSha256':sw.sha256(source_archive),
            'setupFilesSha256':setup_inventory_sha,
            'published':False,'redistributionReviewed':False,'cleanDeviceAcceptance':False}
    sw.atomic(output/'candidate.json',record);return record


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    for name in ('archive','software','key','public','output','source-archive'):p.add_argument('--'+name,type=Path,required=True)
    p.add_argument('--sequence',type=int,required=True)
    a=p.parse_args();print(json.dumps(build(a.archive,a.software,a.key,a.public,a.output,a.sequence,a.source_archive)))
