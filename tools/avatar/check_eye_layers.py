"""Check iris/white ordering through real exported facial morph interpolation."""
import argparse
import json
from pathlib import Path
import numpy as np
from build_pack import GLB
from restore_painted_face import Surface


def check_lid_motion(model, meshes):
    """Cast frontal rays through the exported triangles over one complete blink."""
    def depth_at(prim, weight, rays):
        attrs = prim['attributes']
        v = model.acc(attrs['POSITION'])
        if weight:
            target = prim['targets'][closed]
            v += weight * model.acc(target['POSITION'])
        faces = model.acc(prim['indices']).reshape(-1, 3)
        return Surface(v, model.acc(attrs['NORMAL']), faces).sample(rays, allow_missing=True)[0]

    rim = meshes['rim']
    closed = rim['extras']['targetNames'].index('eyes_closed')
    half = rim['extras']['targetNames'].index('eyes_half')
    lash, *lids = rim['primitives']
    assert len(lids) == 2
    for prim in rim['primitives']:
        motion = model.acc(prim['targets'][closed]['POSITION'])
        assert not motion[:, 0].any(), 'Lateral drift during blink'
        assert np.allclose(model.acc(prim['targets'][half]['POSITION']), .53*motion, atol=1e-7)
    white = meshes['white']['primitives']
    extent = np.concatenate([model.acc(p['attributes']['POSITION']) for p in white])
    xs = np.linspace(extent[:,0].min(), extent[:,0].max(), 105)
    ys = np.linspace(extent[:,1].min()-.002, extent[:,1].max()+.002, 39)
    rays = np.stack(np.meshgrid(xs,ys),axis=-1).reshape(-1,2)
    art = np.maximum.reduce([depth_at(p,0,rays) for p in white+meshes['iris']['primitives']])
    counts = []
    for weight in [0,.25,.5,.75,1]:
        cover = np.maximum.reduce([depth_at(p,weight,rays) for p in [lash,*lids]])
        counts.append(int(np.sum(art>cover)))
    assert counts == sorted(counts,reverse=True), counts
    assert counts[0] > 100 and .30 < counts[2]/counts[0] < .68 and counts[-1] == 0, counts


def check(pack):
    manifest = json.loads((pack/'manifest.json').read_text())
    model = GLB(pack/'template.glb')
    cases = []
    for style, nodes in manifest['eyeNodes'].items():
        meshes = {model.g['nodes'][i]['name'].rsplit('-', 1)[-1]:
                  model.g['meshes'][model.g['nodes'][i]['mesh']] for i in nodes}
        if manifest['revision'] >= 11:
            check_lid_motion(model, meshes)
        white, iris = meshes['white'], meshes['iris']
        names = iris['extras']['targetNames']
        if manifest['revision'] >= 13:
            for control, axis, step in [('gaze_right',0,.004), ('gaze_left',0,-.004),
                                        ('gaze_up',1,.0025), ('gaze_down',1,-.0025)]:
                for prim in iris['primitives']:
                    delta = model.acc(prim['targets'][names.index(control)]['POSITION'])
                    assert np.allclose(delta[:,axis], step, atol=1e-6), (style, control)
                    assert np.allclose(delta[:,1-axis], 0), (style, control)
                    assert np.isfinite(delta).all()
                assert all(control not in mesh['extras']['targetNames']
                           for part,mesh in meshes.items() if part != 'iris')
        # Symbolic reactions replace the eye. Physical lids slide over the fixed iris.
        for mesh in [white, iris]:
            for prim in mesh['primitives']:
                expected = model.acc(prim['targets'][names.index('eyes_hearts')]['POSITION'])
                closed = model.acc(prim['targets'][names.index('eyes_closed')]['POSITION'])
                if manifest['revision'] >= 11:
                    assert not np.any(closed), (style, 'blink distorts eye artwork')
                    assert not np.any(model.acc(prim['targets'][names.index('eyes_half')]['POSITION']))
                else:
                    assert np.array_equal(closed, expected)
                for control in ['eyes_squeezed', 'eyes_hearts', 'eyes_shocked']:
                    assert np.array_equal(expected, model.acc(prim['targets'][names.index(control)]['POSITION']))
        controls = [None, 'eyes_soft', 'eyes_wide']
        if manifest['revision'] < 11:
            controls.extend(['eyes_half', 'eyes_closed'])
        for control in controls:
            for weight in ([0] if control is None else [.125, .25, .5, .75, .875, 1]):
                def pose(prim):
                    p = model.acc(prim['attributes']['POSITION'])
                    if control is not None:
                        p += model.acc(prim['targets'][names.index(control)]['POSITION'])*weight
                    return p
                positions, faces, normals = [], [], []
                count = 0
                for prim in white['primitives']:
                    p = pose(prim)
                    positions.append(p)
                    faces.append(model.acc(prim['indices']).reshape(-1, 3)+count)
                    normals.append(model.acc(prim['attributes']['NORMAL']))
                    count += len(p)
                p, f = np.concatenate(positions), np.concatenate(faces)
                tri = p[f]
                valid = abs(np.cross(tri[:, 1]-tri[:, 0], tri[:, 2]-tri[:, 0])[:, 2]) > 1e-12
                if not valid.any():
                    continue  # Fully collapsed invisible eye has no surface.
                surface = Surface(p, np.concatenate(normals), f[valid])
                minimum = 1.
                for prim in iris['primitives']:
                    p = pose(prim)
                    tri = p[model.acc(prim['indices']).reshape(-1, 3)]
                    samples = np.concatenate([p, tri.mean(1), (tri[:, 0]+tri[:, 1])*.5,
                                              (tri[:, 1]+tri[:, 2])*.5, (tri[:, 2]+tri[:, 0])*.5])
                    depth, _ = surface.sample(samples, allow_missing=True)
                    covered = np.isfinite(depth)
                    if covered.any():
                        minimum = min(minimum, float((samples[covered, 2]-depth[covered]).min()))
                cases.append({'style': style, 'control': control, 'weight': weight, 'clearance': minimum})
    worst = min(cases, key=lambda c: c['clearance'])
    assert worst['clearance'] > .0001, ('Iris intersects white', worst)
    return {'passed': True, 'eyeStyles': len(manifest['eyeNodes']), 'posesAndWeights': len(cases),
            'minimumIrisWhiteClearanceMetres': worst['clearance'], 'worstCase': worst}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('pack', type=Path)
    parser.add_argument('--report', type=Path)
    args = parser.parse_args()
    report = check(args.pack)
    if args.report:
        args.report.write_text(json.dumps(report, indent=2)+'\n', encoding='utf8')
    print(json.dumps(report))
