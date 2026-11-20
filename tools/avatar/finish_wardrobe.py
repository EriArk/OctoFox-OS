"""Finish the SDK garments from immutable golf and starter collection masters.

Run with the pack directory after fit_racing_helmets.py. Positions are metres,
Y up, +Z forward. Small garment details use the underlying triangle's skin
weights and corrective targets so stitches move with their panel.
"""
import argparse
from collections import defaultdict
from pathlib import Path
from tempfile import TemporaryDirectory
import hashlib
import json

import numpy as np
from scipy.sparse import coo_matrix
from scipy.sparse.csgraph import connected_components

from build_pack import GLB, Builder
from build_golf_clothes import normals

ROOT = Path(__file__).resolve().parents[2]
WOMENS = 'denim-breeches-womens'


class Garment:
    def __init__(self, path, fabric):
        self.model = GLB(path)
        self.mesh = self.model.g['meshes'][0]
        self.materials = {m['name']: i for i, m in enumerate(self.model.g['materials'])}
        self.fabric = next(p for p in self.mesh['primitives'] if p['material'] == self.materials[fabric])
        self.vertices = self.model.acc(self.fabric['attributes']['POSITION'])
        self.faces = self.model.acc(self.fabric['indices']).reshape(-1, 3)
        self.builder = Builder.__new__(Builder)
        self.builder.g = self.model.g
        self.builder.b = bytearray(self.model.b)
        self.parts = defaultdict(list)

    def surface(self, xy, back=False, up=False):
        axes, depth = ([0, 2], 1) if up else ([0, 1], 2)
        triangles = self.vertices[self.faces]
        origin = triangles[:, 0, axes]
        u = triangles[:, 1, axes] - origin
        v = triangles[:, 2, axes] - origin
        det = u[:, 0]*v[:, 1] - u[:, 1]*v[:, 0]
        valid = abs(det) > 1e-12
        det = np.where(valid, det, 1)
        points, donors, factors = [], [], []
        for at in xy:
            d = at - origin
            a = (d[:, 0]*v[:, 1] - d[:, 1]*v[:, 0])/det
            b = (u[:, 0]*d[:, 1] - u[:, 1]*d[:, 0])/det
            hit = np.flatnonzero(valid & (a >= -1e-5) & (b >= -1e-5) & (a+b <= 1.00001))
            if not len(hit):
                raise ValueError(f'{self.mesh["name"]}: pattern misses fabric at {at}')
            weights = np.column_stack((1-a[hit]-b[hit], a[hit], b[hit])).clip(0, 1)
            weights /= weights.sum(1)[:, None]
            z = (weights*triangles[hit, :, depth]).sum(1)
            i = z.argmin() if back else z.argmax()
            donors.append(self.faces[hit[i]])
            factors.append(weights[i])
            points.append(weights[i] @ triangles[hit[i]])
        return np.array(points), np.array(donors), np.array(factors)

    def patch(self, xy, faces, color, back, lift):
        xyz, ids, weights = self.surface(np.asarray(xy), back)
        xyz[:, 2] += -lift if back else lift
        faces = np.array(faces)
        # Maintain outward winding for both mirrored and rear panels.
        winding = np.cross(xyz[faces[:,1]]-xyz[faces[:,0]], xyz[faces[:,2]]-xyz[faces[:,0]])[:,2]
        flip = winding > 0 if back else winding < 0
        faces[flip] = faces[flip, ::-1]
        self.parts[color].append((xyz, faces, ids, weights))

    def ribbon(self, path, width, color, back=False, lift=.002):
        line = np.array(path, float)
        # Subdivide long seams so they follow the curved seat and chest.
        line = np.vstack([*(np.linspace(a,b,max(1,int(np.ceil(np.linalg.norm(b-a)/.003))),endpoint=False)
                            for a,b in zip(line,line[1:])), line[-1]])
        t = np.gradient(line,axis=0)
        perp = np.column_stack((-t[:,1],t[:,0])) / np.linalg.norm(t,axis=1)[:,None]
        xy = np.stack((line-perp*width/2,line+perp*width/2),axis=1).reshape(-1,2)
        faces = [[i,i+1,i+2] for i in range(len(xy)-2)]
        self.patch(xy,faces,color,back,lift)

    def button(self, x, y, radius, color, back=False):
        angles = np.arange(16)*np.pi/8
        xy = np.vstack(([x,y], np.column_stack((x+radius*np.cos(angles), y+radius*np.sin(angles)))))
        self.patch(xy, [[0,i+1,(i+1)%16+1] for i in range(16)], color,back,.004)

    def replace(self, accessor, data):
        a = self.model.g['accessors'][accessor]
        view = self.model.g['bufferViews'][a['bufferView']]
        assert 'byteStride' not in view and 'sparse' not in a and view['byteLength']==data.nbytes
        start = view.get('byteOffset',0)+a.get('byteOffset',0)
        self.builder.b[start:start+data.nbytes] = data.tobytes()
        a.update(min=data.min(0).tolist(),max=data.max(0).tolist())

    def finish_helmet(self, shell, stripe):
        # The open shell stops a ring short of the pole. Cap that exact ring
        # with the same head binding, underneath the continuous crown stripe.
        ring = np.flatnonzero(np.isclose(self.vertices[:,1],self.vertices[:,1].max()))
        _,first = np.unique(np.round(self.vertices[ring],6),axis=0,return_index=True)
        ring = ring[first]
        angles = np.arctan2(self.vertices[ring,0],self.vertices[ring,2]-.006)
        ring = ring[np.argsort(angles)]
        xyz = np.vstack(([0,.997,.006],self.vertices[ring]))
        source = np.r_[ring[0],ring]
        faces = np.array([[0,i+1,(i+1)%len(ring)+1] for i in range(len(ring))])
        self.parts[shell].append((xyz,faces,np.tile(source[:,None],(1,3)),np.tile([1,0,0],(len(xyz),1))))

        primitive = next(p for p in self.mesh['primitives'] if p['material']==self.materials[stripe])
        attrs = primitive['attributes']
        pos = self.model.acc(attrs['POSITION'])
        groups = self.components(primitive)
        selected = np.concatenate([ids for ids in groups if len(ids)==14])
        centre = np.array([0,.844,.006])
        direction = pos[selected]-centre
        radius = np.linalg.norm(direction/np.array([.151,.153,.166]),axis=1)
        projected = centre + direction*((1.013/radius)[:,None])
        chin = (projected[:,1]<.779)&(projected[:,2]>0)
        projected[chin,2] = np.maximum(projected[chin,2],.1395)
        pos[selected] = projected
        self.replace(attrs['POSITION'],pos)

    def components(self,primitive):
        faces = self.model.acc(primitive['indices']).reshape(-1,3)
        edges = faces[:,[0,1,1,2]].reshape(-1,2)
        size = self.model.g['accessors'][primitive['attributes']['POSITION']]['count']
        count,labels = connected_components(coo_matrix((np.ones(len(edges)),edges.T),shape=(size,size)),directed=False)
        return [np.flatnonzero(labels==i) for i in range(count)]

    def seat_laces(self):
        lace = next(p for p in self.mesh['primitives'] if p['material']==self.materials['forest'])
        attrs = lace['attributes']
        pos = self.model.acc(attrs['POSITION'])
        faces = self.model.acc(lace['indices']).reshape(-1,3)
        adjusted = []
        found = 0
        for ids in self.components(lace):
            if len(ids)!=24:
                continue
            rings = pos[ids].reshape(3,8,3)
            centre = rings.mean(1)
            xz = centre[:,[0,2]].copy()
            xz[:,1] += np.array([-.003,0,.003])*np.sign(centre[1,0])
            dest,_,_ = self.surface(xz,up=True)
            dest[:,1] += .0012
            pos[ids] = (rings+(dest-centre)[:,None,:]).reshape(-1,3)
            adjusted.extend(ids)
            found += 1
        assert found==8
        self.replace(attrs['POSITION'],pos)
        n = self.model.acc(attrs['NORMAL'])
        n[adjusted] = normals(pos,faces)[adjusted]
        self.replace(attrs['NORMAL'],n)

    def save(self, path):
        attrs = self.fabric['attributes']
        joints = self.model.acc(attrs['JOINTS_0'])
        weights = self.model.acc(attrs['WEIGHTS_0'])
        for color,parts in self.parts.items():
            xyz,faces,ids,bary = zip(*parts)
            faces = np.concatenate([f+start for f,start in zip(faces,np.cumsum([0]+[len(v) for v in xyz[:-1]]))])
            xyz,ids,bary = map(np.concatenate,(xyz,ids,bary))
            influence = np.zeros((len(xyz),len(self.model.g['skins'][0]['joints'])))
            np.add.at(influence,(np.arange(len(xyz))[:,None,None],joints[ids]),weights[ids]*bary[:,:,None])
            j = np.argsort(-influence,axis=1,kind='stable')[:,:4]
            w = np.take_along_axis(influence,j,axis=1)
            w /= w.sum(1)[:,None]
            acc = self.builder.acc
            att = dict(POSITION=acc(xyz.astype('<f4')),NORMAL=acc(normals(xyz,faces).astype('<f4')),
                       JOINTS_0=acc(j.astype(joints.dtype)),WEIGHTS_0=acc(w.astype('<f4')))
            targets = []
            for target in self.fabric.get('targets',[]):
                d = (self.model.acc(target['POSITION'])[ids]*bary[:,:,None]).sum(1)
                targets.append(dict(POSITION=acc(d.astype('<f4'),sparse=True)))
            p = dict(attributes=att,indices=acc(faces.astype('<u4').ravel()),material=self.materials[color])
            if targets:
                p['targets'] = targets
            self.mesh['primitives'].append(p)
        self.builder.save(path)


def detail(item, garment):
    g = garment
    if item in ('denim-breeches',WOMENS):
        if item==WOMENS:
            for side in [-1,1]:
                g.ribbon([(side*.083,.216),(side*.090,.231),(side*.090,.254)],.012,'denim-light')
                g.button(side*.090,.249,.004,'stitch')
                scoop = [(side*x,y) for x,y in [(.027,.457),(.039,.446),(.056,.438),(.077,.436)]]
                g.ribbon(scoop,.006,'denim-light')
                g.button(side*.075,.436,.003,'stitch')
                g.ribbon([(side*.026,.446),(side*.051,.451),(side*.074,.444)],.004,'denim-light',True)
        else:
            for side in [-1,1]:
                edge = [(side*x,y) for x,y in [(.024,.444),(.068,.439),(.066,.412),(.050,.402),(.027,.409),(.024,.444)]]
                g.ribbon(edge,.003,'stitch',True)
                g.ribbon([(side*.026,.435),(side*.048,.430),(side*.067,.434)],.002,'denim-light',True)
    elif item=='everyday-tee':
        g.ribbon([(.032,.598),(.035,.576),(.046,.571),(.056,.578),(.057,.598)],.0027,'forest')
    elif item=='sundress':
        # Ribbon tails fan out from the existing centre bow at the waist.
        for side in [-1,1]:
            g.ribbon([(0,.481),(side*.009,.467),(side*.015,.453)],.006,'dress-light')
        g.button(0,.481,.005,'ivory')
    elif item.startswith('polo-'):
        # Back yoke follows the shoulder blades in each polo's collar colour.
        color = 'forest' if item=='polo-short-sleeve' else 'ivory'
        g.ribbon([(-.061,.621),(-.039,.617),(0,.610),(.039,.617),(.061,.621)],.003,color,True)
    elif item=='golf-shorts':
        for side in [-1,1]:
            g.ribbon([(side*.028,.443),(side*.072,.438)],.004,'ivory',True)
    elif item=='pleated-skirt':
        g.ribbon([(.029,.469),(.049,.469),(.062,.474)],.007,'ivory')
        g.button(.055,.472,.0035,'peach')
    elif item.endswith('racing-helmet'):
        rose = item.startswith('rose-')
        g.finish_helmet('ivory' if rose else 'race','rose' if rose else 'orange')
    elif item.endswith('racing-gloves'):
        for side in [-1,1]:
            g.ribbon([(side*.161,.417),(side*.180,.418),(side*.198,.423)],.007,
                     'rose' if item.startswith('rose-') else 'race')
            g.button(side*.191,.421,.0028,'metal')
    elif item.endswith('racing-boots'):
        for side in [-1,1]:
            g.ribbon([(side*.083,.079),(side*.079,.102),(side*.078,.139)],.012,'dark',True)
            g.ribbon([(side*.078,.126),(side*.078,.138)],.005,'ivory',True,lift=.003)
    elif item.endswith('racing-suit'):
        rose = item.startswith('rose-')
        for side in [-1,1]:
            yoke = [(.006,.603),(.034,.608),(.068,.632)] if rose else [(.006,.624),(.045,.624),(.070,.611)]
            g.ribbon([(side*x,y) for x,y in yoke],.009,'ivory',True)
            g.ribbon([(side*x,y-.010) for x,y in yoke],.003,'plum' if rose else 'orange',True)
    elif item in ('canvas-shoes','golf-shoes-classic','golf-shoes-sport'):
        g.seat_laces()


def build(pack):
    m = json.loads((pack/'manifest.json').read_text())
    assert m['revision']==16
    m['wearables'][WOMENS] = dict(m['wearables']['denim-breeches'],file='wear-'+WOMENS+'.glb')
    fabrics = {'denim-breeches':'denim', WOMENS:'denim','everyday-tee':'ivory','sundress':'dress',
               'polo-short-sleeve':'ivory','polo-sleeveless':'forest','golf-shorts':'forest','pleated-skirt':'forest',
               'racing-suit':'race','rose-racing-suit':'rose','canvas-shoes':'ivory','golf-shoes-classic':'ivory',
               'golf-shoes-sport':'ivory','racing-boots':'race','rose-racing-boots':'rose',
               'racing-gloves':'dark','rose-racing-gloves':'plum','racing-helmet':'race','rose-racing-helmet':'ivory'}
    for item,fabric in fabrics.items():
        if item==WOMENS:
            # Cut the higher hem on the knee itself so it inherits the correct
            # cross-section and skin weights throughout the character's stride.
            from build_starter_racing import Collection
            with TemporaryDirectory() as folder:
                master = Path(folder)/(item+'.glb')
                author = Collection()
                author.denim(item,.207,.015)
                author.export([item],master)
                garment = Garment(master,fabric)
        else:
            master, = (ROOT/'assets/avatar/collections').glob('*/'+item+'.glb')
            garment = Garment(master,fabric)
        detail(item,garment)
        record = m['wearables'][item]
        file = pack/record['file']
        garment.save(file)
        record['sha256'] = m['files'][file.name] = hashlib.sha256(file.read_bytes()).hexdigest()
    encoded = json.dumps(m,indent=2)+'\n'
    assert len(encoded.encode())<=65536
    (pack/'manifest.json').write_text(encoded,encoding='utf8',newline='\n')


if __name__=='__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('pack',type=Path)
    build(parser.parse_args().pack)
