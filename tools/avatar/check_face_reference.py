"""Exact owner-approved head check for all future avatar pack deliveries."""
import argparse
import hashlib
import json
from pathlib import Path
import numpy as np
from build_pack import GLB
from restore_painted_face import Surface

REFERENCE = Path(__file__).resolve().parents[2]/'assets/avatar/approved/face-2026-10-29'


def check(pack, reference=REFERENCE):
    lock = json.loads((reference/'reference.json').read_text())
    file = reference/lock['referenceFile']
    assert hashlib.sha256(file.read_bytes()).hexdigest() == lock['referenceSha256'], 'Reference changed'
    source = np.load(file)
    assert str(source['source_sha256']) == lock['sourceSha256']
    p = source['POSITION']*lock['headScale']
    p[:, 1] += .05728
    head = source['POSITION'][:, 1] > lock['sourceHeadMinY']
    m = json.loads((pack/'manifest.json').read_text())
    model = GLB(pack/'template.glb')
    assert m['faceSurface']['referenceId'] == lock['id']
    assert model.g['extras']['trainerApprovedFace']['referenceId'] == lock['id']
    fitted = m['revision'] >= 11
    x, y, z = p.T
    socket = (abs(x)>.007) & (abs(x)<.097) & (y>.748) & (y<.833) & (z>.036)
    if m['revision'] >= 15:
        # Keep cheeks, temples, bridge and the back of the head byte-exact.
        lateral = abs(x) - .0525
        socket = (np.hypot(lateral/.037, (y-.7945-.11*lateral)/.0345) < 1) & (z>.036)
    protected = head & ~socket if fitted else head
    # The original head stays the reference. Revision 11 has one bounded,
    # independently pinned relief correction where the painted eye used to sit.
    fitted_hash = {'POSITION':'e8b0cb162a0b3c48a4fa0db25782d20ffd19a51db63540fe5a15cacea61c2161',
                   'NORMAL':'b98fa7915c4967f313b38eaeb4ab4cea3fb50065e84c46b23a6e88976f231670'}
    if m['revision'] >= 14:
        fitted_hash = {'POSITION':'9dddc339037acf3b162ab35a3d18a22590d865a542b409744eaa7df326082e08',
                       'NORMAL':'ec447c230b80d76da48957fe482de08b43cee71a572bb267b6e3df08d1ebdd5c'}
    if m['revision'] >= 15:
        fitted_hash = {'POSITION':'a622bfbc665b3fc79a3020decf9f675692e1d44792d5b31953299b2c8049ac37',
                       'NORMAL':'b0df32a312919f6a578430edaf39561744909cc301470efe94a2cd5b7ef4076c'}
    mesh = model.g['meshes'][m['preparedBodyMesh']]
    for prim in mesh['primitives']:
        for attr, expected in [('POSITION', p), ('NORMAL', source['NORMAL'])]:
            actual = model.acc(prim['attributes'][attr])
            assert np.array_equal(actual[protected], expected[protected]), f'Approved head {attr} changed'
            if fitted:
                assert hashlib.sha256(actual[head].astype('<f4').tobytes()).hexdigest() == fitted_hash[attr]
                if attr == 'POSITION':
                    assert np.array_equal(actual[head,:2], expected[head,:2])
                    assert np.max(abs(actual[head,2]-expected[head,2])) < .012
        for attr in ['TEXCOORD_0', 'JOINTS_0', 'WEIGHTS_0']:
            assert np.array_equal(model.acc(prim['attributes'][attr])[head], source[attr][head]), attr
        for target in prim.get('targets', []):
            for attr in ['POSITION', 'NORMAL']:
                if attr in target:
                    assert not np.any(model.acc(target[attr])[head]), 'Body corrective deforms locked head'
    if m['revision'] >= 15:
        attributes = mesh['primitives'][0]['attributes']
        positions = model.acc(attributes['POSITION'])
        normals = model.acc(attributes['NORMAL'])
        triangles = source['indices'].reshape(-1, 3)
        surface = Surface(positions, normals, triangles)
        centres = np.array([[-.0525, .7945], [.0525, .7945]])
        assert np.allclose(surface.sample(centres)[0], .0908, atol=.00015), 'Eye seat depth'
        # A shading normal must follow the actual triangle, also at grazing angles.
        faces = triangles[socket[triangles].all(axis=1)]
        a, b, c = positions[faces].transpose(1, 0, 2)
        geometric = np.cross(b-a, c-a)
        authored = normals[faces].mean(axis=1)
        area = np.linalg.norm(geometric, axis=1)
        valid = area > 1e-10
        cosine = np.sum(geometric[valid]*authored[valid], axis=1) / (
            area[valid]*np.linalg.norm(authored[valid], axis=1))
        assert np.all(cosine > np.cos(np.radians(6))), 'Socket facet or inconsistent lighting'
    assert int(head.sum()) == lock['headVertices']
    assert hashlib.sha256(p[head].astype('<f4').tobytes()).hexdigest() == lock['headPositionSha256']
    assert hashlib.sha256(source['NORMAL'][head].astype('<f4').tobytes()).hexdigest() == lock['headNormalSha256']
    assert all(m.get('eyeBodyMeshes', {}).get(style, m['preparedBodyMesh']) == m['preparedBodyMesh']
               for style in m['eyeNodes'])
    return {'passed': True, 'reference': lock['id'], 'headVertices': int(head.sum()),
            'protectedVertices': int(protected.sum()), 'protectedPositionsAndNormalsExact': True,
            'fittedSocketsVerified': fitted, 'bodyCorrectivesPreserveHead': True}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('pack', type=Path)
    args = parser.parse_args()
    print(json.dumps(check(args.pack)))
