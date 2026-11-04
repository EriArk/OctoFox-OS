# SPDX-License-Identifier: GPL-3.0-or-later
import copy
import hashlib
import io
import json
from pathlib import Path
import sys
import tarfile
import tempfile
import unittest
from unittest.mock import patch
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'packaging/software'))
import fullbundle
import runtime_payload
import runtime_set
import runtime_upstream
import upstream_media
import offline_setup


class Response(io.BytesIO):
    def __init__(self, data, status=200, headers=None):
        super().__init__(data); self.status = status
        self.headers = headers or {'Content-Length': str(len(data))}
    def geturl(self): return 'https://release-assets.githubusercontent.com/official/pinned-image'


class RuntimeUpstreamTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(); self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name); self.body = b'official unchanged binary'
        self.sha = hashlib.sha256(self.body).hexdigest()
        self.delivery = {'kind': 'github-release-asset', 'repository': 'stenzek/duckstation', 'assetId': 673935636}
        self.record = {'schema': 1, 'id': 'DuckStation', 'delivery': self.delivery,
            'files': [{'path': 'DuckStation.AppImage', 'bytes': len(self.body), 'sha256': self.sha, 'mode': 0o755}]}
        self.stage = self.root/'stage'; self.stage.mkdir()
        self.plan = {'schema': 1, 'components': [{'id': 'DuckStation', 'delivery': self.delivery,
                     'sha256': self.sha, 'bytes': len(self.body)}]}

    def media(self):
        source=self.root/'input';source.mkdir();(source/'DuckStation.AppImage').write_bytes(self.body)
        (source/'DuckStation.AppImage').chmod(0o755)
        packed=self.root/'component';runtime_payload.build(source,['DuckStation.AppImage'],packed,'DuckStation')
        # Retained candidates had downloaded AppImages recorded as non-executable.
        record=json.loads((packed/'component.json').read_text());record['files'][0]['mode']=0o644
        (packed/'component.json').write_text(json.dumps(record))
        extra=self.root/'core.so';extra.write_bytes(b'multiplayer core unchanged')
        files=[{'path':'runtimes/DuckStation/'+name,'source':str(packed/name),'sha256':runtime_payload.digest(packed/name)} for name in ['component.json','component.tar.gz']]
        files.append({'path':'runtimes/other/core.so','source':str(extra),'sha256':runtime_payload.digest(extra)})
        fullbundle.build({'schema':1,'files':files},self.root/'offline')
        return self.root/'offline/TrainerOS-Full-CANDIDATE.tar'

    def test_hybrid_has_no_upstream_binary_and_preserves_netplay_inputs(self):
        original=self.media();before=runtime_payload.digest(original);output=self.root/'hybrid.tar'
        result=upstream_media.build(original,self.plan,output)
        self.assertEqual(result['upstreamDownloads'],['DuckStation'])
        with tarfile.open(output) as tar:
            self.assertNotIn('runtimes/DuckStation/component.tar.gz',tar.getnames())
            self.assertEqual(tar.extractfile('runtimes/other/core.so').read(),b'multiplayer core unchanged')
            record=json.load(tar.extractfile('runtimes/DuckStation/component.json'))
            self.assertNotIn('archive',record);self.assertEqual(record['delivery'],self.delivery)
            self.assertEqual(record['files'][0]['mode'],0o755)
            runtime_upstream.validate(record)
        self.assertEqual(runtime_payload.digest(original),before)
        with self.assertRaises(ValueError):upstream_media.build(original,self.plan,output)

    def test_conversion_rejects_different_version_before_output(self):
        original=self.media();self.plan['components'][0]['sha256']='0'*64
        with self.assertRaises(ValueError):upstream_media.build(original,self.plan,self.root/'hybrid.tar')
        self.assertFalse((self.root/'hybrid.tar').exists())

    def test_explicit_replacement_requires_exact_previous_image(self):
        original=self.media();spec=self.plan['components'][0]
        spec['replaces']={'sha256':self.sha,'bytes':len(self.body)}
        spec['sha256']=hashlib.sha256(b'next reviewed image').hexdigest();spec['bytes']=len(b'next reviewed image')
        output=self.root/'next.tar';upstream_media.build(original,self.plan,output)
        with tarfile.open(output) as tar:
            record=json.load(tar.extractfile('runtimes/DuckStation/component.json'))
            self.assertEqual(record['files'][0]['sha256'],spec['sha256'])
        spec['replaces']['sha256']='f'*64
        with self.assertRaises(ValueError):upstream_media.build(original,self.plan,self.root/'bad-next.tar')

    def test_flathub_conversion_preserves_modified_ppsspp_bundle(self):
        inputs=self.root/'flatpak-inputs';inputs.mkdir();files=[];refs=[]
        for name,ref in [('flycast','org.flycast.Flycast/aarch64/stable'),('ppsspp','org.ppsspp.PPSSPP/aarch64/traineros-relay')]:
            p=inputs/(name+'.flatpak');p.write_bytes(name.encode())
            refs.append({'kind':'app','ref':ref,'commit':'a'*64,'file':p.name,'bytes':p.stat().st_size,'sha256':runtime_payload.digest(p)})
            files.append({'path':'flatpak/'+p.name,'source':str(p),'sha256':runtime_payload.digest(p)})
        lock=inputs/'flatpak-lock.json';lock.write_text(json.dumps({'refs':refs}))
        files.append({'path':'flatpak/'+lock.name,'source':str(lock),'sha256':runtime_payload.digest(lock)})
        original=fullbundle.build({'schema':1,'files':files},self.root/'flatpak-media')
        key=self.root/'flathub.gpg';key.write_bytes(b'official key')
        plan={'schema':1,'flatpak':{'refs':[refs[0]['ref']],'keyFile':str(key),'keySha256':runtime_payload.digest(key)}}
        output=self.root/'flatpak-hybrid.tar'
        upstream_media.build(self.root/'flatpak-media/TrainerOS-Full-CANDIDATE.tar',plan,output)
        with tarfile.open(output) as tar:
            self.assertNotIn('flatpak/flycast.flatpak',tar.getnames())
            self.assertEqual(tar.extractfile('flatpak/ppsspp.flatpak').read(),b'ppsspp')
            changed=json.load(tar.extractfile('flatpak/flatpak-lock.json'))['refs']
            self.assertEqual(changed[1],refs[1]);self.assertEqual(changed[0]['commit'],refs[0]['commit'])
            self.assertEqual(tar.extractfile('flatpak/flathub.gpg').read(),b'official key')

    def test_downloaded_appimage_gets_executable_metadata(self):
        folder=self.root/'download';folder.mkdir();image=folder/'DuckStation.AppImage'
        image.write_bytes(self.body);image.chmod(0o644)
        result=runtime_payload.build(folder,[image.name],self.root/'new-component','DuckStation')
        self.assertEqual(result['files'][0]['mode'],0o755)
        self.assertEqual(result['files'][0]['sha256'],self.sha)

    def test_only_reviewed_source_and_exact_appimage_allowed(self):
        variants=[]
        for key,value in [('repository','attacker/duckstation'),('assetId','latest'),('assetId',True),('assetId',0),('kind','script')]:
            record=copy.deepcopy(self.record);record['delivery'][key]=value;variants.append(record)
        for key,value in [('path','../DuckStation.AppImage'),('bytes',0),('sha256','bad'),('mode',0o644)]:
            record=copy.deepcopy(self.record);record['files'][0][key]=value;variants.append(record)
        record=copy.deepcopy(self.record);record['archive']={};variants.append(record)
        record=copy.deepcopy(self.record);record['id']='ppsspp';variants.append(record)
        for record in variants:
            with self.subTest(record=record),self.assertRaises(ValueError):runtime_upstream.validate(record)

    def test_official_asset_id_and_binary_accept_header(self):
        requests=[]
        def fetch(request,**kwargs):requests.append(request);return Response(self.body)
        result=runtime_upstream.prepare(self.stage,self.record,opener=fetch)
        self.assertEqual(result.read_bytes(),self.body)
        self.assertEqual(requests[0].full_url,'https://api.github.com/repos/stenzek/duckstation/releases/assets/673935636')
        self.assertEqual(requests[0].get_header('Accept'),'application/octet-stream')

    def test_eden_requires_official_versioned_aarch64_url(self):
        record=copy.deepcopy(self.record);record['id']='eden';record['files'][0]['path']='eden.AppImage'
        url='https://stable.eden-emu.dev/v0.2.1/Eden-Linux-v0.2.1-aarch64-clang-pgo.AppImage'
        record['delivery']={'kind':'eden-release-file','url':url};runtime_upstream.validate(record)
        for wrong in [url.replace('https:','http:'),url.replace('stable.eden-emu.dev','example.org'),url+'?other=1',url.replace('v0.2.1','latest')]:
            record['delivery']['url']=wrong
            with self.subTest(url=wrong),self.assertRaises(ValueError):runtime_upstream.validate(record)

    def test_interruption_resumes_verified_download_without_activation(self):
        with self.assertRaisesRegex(ValueError,'interrupted'):
            runtime_upstream.prepare(self.stage,self.record,opener=lambda *a,**k:Response(self.body[:5],headers={'Content-Length':str(len(self.body))}))
        part=self.stage/'downloads'/(self.sha+'.part');self.assertEqual(part.read_bytes(),self.body[:5])
        self.assertFalse((self.stage/'components').exists())
        def resume(request,**kwargs):
            self.assertEqual(request.get_header('Range'),'bytes=5-')
            return Response(self.body[5:],206,{'Content-Length':str(len(self.body)-5),'Content-Range':f'bytes 5-{len(self.body)-1}/{len(self.body)}'})
        self.assertEqual(runtime_upstream.prepare(self.stage,self.record,opener=resume).read_bytes(),self.body)

    def test_changed_official_download_fails_hash_not_silently_updates(self):
        with self.assertRaisesRegex(ValueError,'hash'):
            runtime_upstream.prepare(self.stage,self.record,opener=lambda *a,**k:Response(b'x'*len(self.body)))
        self.assertFalse((self.stage/'downloads'/(self.sha+'.part')).exists())
        self.assertFalse((self.stage/'components').exists())

    def test_component_reuses_checked_download_and_detects_tamper(self):
        media=self.stage/'media/runtimes/DuckStation';media.mkdir(parents=True)
        (media/'component.json').write_text(json.dumps(self.record))
        real=runtime_upstream.prepare
        with patch.object(runtime_upstream,'prepare',side_effect=lambda stage,record,progress:real(stage,record,progress,lambda *a,**k:Response(self.body))) as fetch:
            record,target=runtime_set.component(self.stage,'DuckStation')
            self.assertEqual((target/'DuckStation.AppImage').read_bytes(),self.body)
            runtime_set.component(self.stage,'DuckStation');self.assertEqual(fetch.call_count,1)
            (target/'DuckStation.AppImage').write_bytes(b'x'*len(self.body))
            with self.assertRaises(ValueError):runtime_set.component(self.stage,'DuckStation')
            self.assertEqual(fetch.call_count,1)

    def test_bundled_binary_cannot_hide_behind_upstream_descriptor(self):
        media=self.stage/'media/runtimes/DuckStation';media.mkdir(parents=True)
        (media/'component.json').write_text(json.dumps(self.record));(media/'component.tar.gz').write_bytes(b'not upstream')
        with self.assertRaisesRegex(ValueError,'must not be bundled'):runtime_set.component(self.stage,'DuckStation')

    def test_network_failure_keeps_old_installation(self):
        old=self.root/'runtime-home/Applications/DuckStation.AppImage';old.parent.mkdir(parents=True);old.write_bytes(b'previous')
        media=self.stage/'media/runtimes/DuckStation';media.mkdir(parents=True);(media/'component.json').write_text(json.dumps(self.record))
        with patch.object(runtime_upstream,'prepare',side_effect=OSError('network unavailable')):
            with self.assertRaises(OSError):runtime_set.component(self.stage,'DuckStation')
        self.assertEqual(old.read_bytes(),b'previous');self.assertFalse((self.stage/'components/DuckStation').exists())

    def test_presigned_setup_rejects_mismatched_inputs_before_creating_output(self):
        archive=self.media();software=self.root/'software';software.mkdir()
        app=software/'traineros.tar.gz';app.write_bytes(b'application')
        release={'source':'a'*40,'archive':{'size':app.stat().st_size,'sha256':runtime_payload.digest(app)}}
        source=self.root/'source.tar.gz'
        with tarfile.open(source,'w:gz',pax_headers={'comment':release['source']}) as tar:
            tar.addfile(tarfile.TarInfo('source.py'),io.BytesIO(b''))
        with tarfile.open(archive) as tar:files=json.load(tar.extractfile('fullbundle.json'))['files']
        signed={'sequence':12,'softwareSource':release['source'],'files':files,
                'archive':{'bytes':archive.stat().st_size,'sha256':runtime_payload.digest(archive)}}
        for field,bad in [('sequence',13),('softwareSource','b'*40),('files',[]),('archive',{'bytes':1,'sha256':'0'*64})]:
            changed={**signed,field:bad};output=self.root/('result-'+field)
            with self.subTest(field=field),patch.object(offline_setup.sw,'verified',return_value={'signed':release}),patch.object(runtime_set,'signed',return_value={'signed':changed}):
                with self.assertRaisesRegex(ValueError,'Pre-signed'):
                    offline_setup.build(archive,software,None,self.root/'public.pem',output,12,source,runtime_manifest=self.root/'signed.json')
            self.assertFalse(output.exists())

if __name__=='__main__':unittest.main()
