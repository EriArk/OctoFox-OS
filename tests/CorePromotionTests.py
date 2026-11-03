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

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'packaging/software'))
import core_promotion as m
import fullbundle
import runtime_payload


def sha(data):
    return hashlib.sha256(data).hexdigest()


class CorePromotionTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(); self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        inputs = self.root / 'base-inputs'; (inputs/'cores').mkdir(parents=True); (inputs/'info').mkdir()
        for name, data in [('cores/changed_libretro.so', b'old core'), ('cores/keep_libretro.so', b'keep core'), ('info/keep_libretro.info', b'keep info')]:
            (inputs/name).write_bytes(data)
        self.old = runtime_payload.build(inputs, ['cores','info'], self.root/'base', 'retroarch-cores')
        self.base = self.root/'base/component.tar.gz'
        self.binding = {'schema':1,'component':'retroarch-cores','archive':self.old['archive'],
                        'recipeReference':{},'cores':[dict(r, source=None, identity=None, localMaterials=[])
                                                     for r in self.old['files'] if r['path'].startswith('cores/')]}
        before = next(r for r in self.old['files'] if r['path']=='cores/changed_libretro.so')
        self.spec = {'core':'changed','sourceId':'changed-source','repository':'https://github.com/example/core.git',
                     'commit':'a'*40,'previousBinary':{k:before[k] for k in ('bytes','sha256')}}
        self.new = b'new core'
        self.build = {'core':'changed','status':'built','bytes':len(self.new),'sha256':sha(self.new),'commit':'a'*40}
        self.native = {'cores':[{'file':'changed_libretro.so','exitCode':0,'bytes':len(self.new),'sha256':sha(self.new)}]}
        self.make_candidate()

    def make_candidate(self, extra=None):
        files = {'cores/changed_libretro.so': self.new,
                 'candidates.json': json.dumps({'cores':[self.spec]}).encode(),
                 'selection.json': b'{"changed":"attempt01"}',
                 'build-records/attempt01.json':json.dumps({'cores':[self.build]}).encode()}
        if extra: files.update(extra)
        inventory={'files':[{'path':n,'bytes':len(b),'sha256':sha(b)} for n,b in files.items()]}
        self.candidate=self.root/'candidate.tar'
        with tarfile.open(self.candidate,'w:') as t:
            for n,b in {'candidate.json':json.dumps(inventory).encode(),**files}.items():
                i=tarfile.TarInfo(n);i.size=len(b);t.addfile(i,io.BytesIO(b))
        self.pinned={'bytes':self.candidate.stat().st_size,'sha256':runtime_payload.digest(self.candidate)}

    def promote(self):
        return m.component(self.base,self.old,self.binding,self.candidate,self.pinned,self.native,self.root/'promotion')

    def test_only_selected_core_changes_and_all_other_bytes_are_preserved(self):
        result,binding=self.promote()
        rows={r['path']:r for r in result['files']}
        for row in self.old['files']:
            if row['path']!='cores/changed_libretro.so':self.assertEqual(rows[row['path']],row)
        self.assertEqual(rows['cores/changed_libretro.so']['sha256'],sha(self.new))
        selected=next(r for r in binding['cores'] if r['path']=='cores/changed_libretro.so')
        self.assertEqual(selected['source']['commit'],'a'*40)
        self.assertEqual(selected['identity']['record'],m.BUILD_RECORD)
        self.assertFalse(result['installed']);self.assertFalse(result['redistributionReviewed'])
        with self.assertRaisesRegex(ValueError,'Existing'):self.promote()

    def test_wrong_previous_binary_is_not_overwritten(self):
        self.spec['previousBinary']['sha256']='0'*64;self.make_candidate()
        with self.assertRaisesRegex(ValueError,'retained core'):self.promote()
        self.assertFalse((self.root/'promotion').exists())

    def test_native_check_must_match_the_exact_replacement(self):
        self.native['cores'][0]['sha256']='0'*64
        with self.assertRaisesRegex(ValueError,'native check'):self.promote()
        self.assertFalse((self.root/'promotion').exists())

    def test_changed_archive_rejected_before_output(self):
        with self.candidate.open('ab') as f:f.write(b'changed')
        with self.assertRaisesRegex(ValueError,'pinned input'):self.promote()
        self.assertFalse((self.root/'promotion').exists())

    def test_unselected_core_cannot_sneak_into_component(self):
        self.make_candidate({'cores/unselected_libretro.so':b'extra'})
        with self.assertRaisesRegex(ValueError,'selection differs'):self.promote()

    def test_patch_list_must_agree_with_actual_build(self):
        self.spec['patches']=[{'file':'patches/fix.patch','sha256':'a'*64}];self.make_candidate()
        with self.assertRaisesRegex(ValueError,'build differs'):self.promote()

    def test_media_retains_unrelated_runtime_and_embeds_sources(self):
        self.promote()
        keep=self.root/'keep';keep.write_bytes(b'other emulator remains exact')
        files={'runtimes/retroarch-cores/component.json':self.root/'base/component.json',
               'runtimes/retroarch-cores/component.tar.gz':self.base,'runtimes/other/component.tar.gz':keep}
        plan={'schema':1,'files':[{'path':n,'source':str(p),'sha256':runtime_payload.digest(p)} for n,p in files.items()]}
        old=fullbundle.build(plan,self.root/'media-old');base=self.root/'media-old/TrainerOS-Full-CANDIDATE.tar'
        output=self.root/'media-new.tar';d=self.root/'promotion'
        result=m.media(base,{'bytes':base.stat().st_size,'sha256':old['sha256']},d/'component',self.candidate,self.pinned,d/'core-source-bindings.json',d/'promoted-builds.json',output)
        with tarfile.open(output) as t:
            self.assertEqual(t.extractfile('runtimes/other/component.tar.gz').read(),keep.read_bytes())
            self.assertEqual(t.extractfile('sources/core-rebuild-candidate.tar').read(),self.candidate.read_bytes())
        self.assertFalse(result['installed']);self.assertFalse(result['redistributionReviewed'])
        (d/'component/component.tar.gz').write_bytes(b'changed after promotion')
        with self.assertRaisesRegex(ValueError, 'Archive differs'):
            m.media(base,{'bytes':base.stat().st_size,'sha256':old['sha256']},d/'component',self.candidate,self.pinned,d/'core-source-bindings.json',d/'promoted-builds.json',self.root/'tampered-media.tar')
        self.assertFalse((self.root/'tampered-media.tar').exists())


if __name__=='__main__': unittest.main()
