"""Read-only provenance check for the three reviewed candidate AppImages."""
from pathlib import Path
import argparse, hashlib, json, re, subprocess, tarfile, urllib.request

def sha(data): return hashlib.sha256(data).hexdigest()
def run(root):
    previous=json.loads((root/'appimage-source-metadata.json').read_text())
    identities={r['id']:r for r in previous}
    sources=[('Cemu','cemu-project/Cemu','cee557d46d63e3407dc3bbda6480c0c674e8bb80','shared/bin/cemu','LICENSE.txt','MPL-2.0'),
             ('ARMSX2','ARMSX2/ARMSX2','90126bdfea7a3ffb1fd288b2f7f0ae0b033af2d6','usr/bin/armsx2-qt','COPYING.GPLv3','GPL-3.0-or-later'),
             ('DuckStation','stenzek/duckstation','dd4a0eb779296a525f8b10b6d9a45911ad6d088f','usr/bin/duckstation-qt','LICENSE','CC-BY-NC-ND-4.0')]
    results=[]
    for name,repo,commit,path,license_path,license_name in sources:
        row=identities[name]; image=root/'appimage-inspection'/(name+'.AppImage')
        with image.open('rb') as f: assert hashlib.file_digest(f,'sha256').hexdigest()==row['sha256']
        if name=='Cemu':
            with tarfile.open(root/'appimage-inspection/Cemu.dwarfs.tar') as tar:
                member=tar.getmember(path); assert member.isfile() and member.size<200*1024**2
                binary=tar.extractfile(member).read()
            marker=b'Cemu '+commit[:7].encode()+b'\0'
            assert set(re.findall(rb'Cemu ([0-9a-f]{7})\x00',binary))=={commit[:7].encode()}
        else:
            binary=subprocess.check_output(['unsquashfs','-cat','-o',str(row['squashfsOffset']),str(image),path])
            marker=commit.encode()+b'\0'
        assert binary.startswith(b'\x7fELF') and marker in binary
        url=f'https://api.github.com/repos/{repo}/commits/{commit}'
        with urllib.request.urlopen(url,timeout=60) as f: upstream=json.load(f)
        assert upstream['sha']==commit
        result={'id':name,'appImageSha256':row['sha256'],'elfPath':path,'elfBytes':len(binary),'elfSha256':sha(binary),
                'versionMarker':marker[:-1].decode(),'markerOffset':binary.index(marker),'repository':'https://github.com/'+repo+'.git',
                'commit':commit,'upstreamCommitUrl':upstream['html_url'],'upstreamProjectLicense':license_name,
                'embeddedIdentityResolved':True,'exactBuildRecipeAndDependenciesReviewed':False,'redistributionReviewed':False}
        # ARMSX2's packaged license is retained in its source capsule; inspect
        # the source tree separately rather than guessing a license filename.
        if name!='ARMSX2':
            url=f'https://raw.githubusercontent.com/{repo}/{commit}/{license_path}'
            with urllib.request.urlopen(url,timeout=60) as f: license_data=f.read(1024**2)
            assert (b'Mozilla Public License Version 2.0' if name=='Cemu' else b'Attribution-NonCommercial-NoDerivatives 4.0 International') in license_data
            result['license']={'url':url,'sha256':sha(license_data)}
        if name=='DuckStation':
            url=f'https://raw.githubusercontent.com/{repo}/{commit}/README.md'
            with urllib.request.urlopen(url,timeout=60) as f: readme=f.read(2*1024**2)
            assert b'pre-configured settings and packages are considered modifications' in readme
            result['distributionGuidance']={'url':url,'sha256':sha(readme),'unmodifiedReleaseSharingConditional':True,'preconfiguredPackagesConsideredModificationsByAuthor':True,'trainerosFullBundleDecision':'pending-owner-choice-or-separate-permission'}
        results.append(result)
    output={'schema':1,'method':'Verified AppImage SHA-256; read ELF without execution; resolve embedded identity against pinned upstream commit. Cemu PAX export is the retained verified-tool inspection artifact.',
            'components':results,'installedRuntimeChanged':False,'completeRuntimeCorrespondingSource':False,'redistributionReviewed':False}
    (root/'appimage-provenance.json').write_text(json.dumps(output,indent=2)+'\n')
    print(json.dumps(output,indent=2))
if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('staging',type=Path);run(parser.parse_args().staging)
