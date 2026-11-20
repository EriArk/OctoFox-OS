"""Round fabric shading on the three rigid ship outfits, preserving their cut."""
from pathlib import Path

import numpy as np

from build_golf_clothes import normals
from build_pack import GLB

OUTFITS = Path(__file__).resolve().parents[2]/'experiences/ship-home/assets/outfits'


def finish(path):
    model = GLB(path)
    raw = bytearray(path.read_bytes())
    binary_start = len(raw)-len(model.b)
    for mesh in model.g['meshes']:
        for p in mesh['primitives']:
            material = model.g['materials'][p['material']]['name']
            if material in {'silver','brass','gem','sole'}:
                continue
            attrs = p['attributes']
            v = model.acc(attrs['POSITION'])
            faces = model.acc(p['indices']).reshape(-1,3)
            # Derive the split normals from geometry each run. Average only
            # overlapping corners of the same material below a 35 degree crease.
            original = normals(v,faces)
            result = original.copy()
            _,group = np.unique(v.round(6),axis=0,return_inverse=True)
            for ids in np.split(np.argsort(group,kind='stable'),np.cumsum(np.bincount(group))[:-1]):
                if len(ids)>1:
                    group_normals = original[ids]
                    aligned = group_normals@group_normals.T > np.cos(np.deg2rad(35))
                    result[ids] = aligned@group_normals
            lengths = np.linalg.norm(result,axis=1)
            if not (lengths>0).all():
                # A collapsed triangle at a pole has no geometric normal.
                # Retain the author's normal only for that corner.
                empty = lengths==0
                result[empty] = model.acc(attrs['NORMAL'])[empty]
                lengths[empty] = np.linalg.norm(result[empty],axis=1)
            result /= np.maximum(lengths[:,None],1e-12)
            a = model.g['accessors'][attrs['NORMAL']]
            view = model.g['bufferViews'][a['bufferView']]
            assert 'byteStride' not in view and 'sparse' not in a
            start = binary_start+view.get('byteOffset',0)+a.get('byteOffset',0)
            raw[start:start+result.nbytes] = result.astype('<f4').tobytes()
    path.write_bytes(raw)


if __name__=='__main__':
    for name in ('traveller','mage','merchant'):
        finish(OUTFITS/(name+'.glb'))
