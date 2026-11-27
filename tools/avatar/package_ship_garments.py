"""Bind the authored ship collection pieces to the common avatar pack."""
import hashlib
import json
from pathlib import Path
from PIL import Image

from build_golf_clothes import Author
from build_pack import Builder, GLB

ROOT = Path(__file__).resolve().parents[2]
PACK = ROOT / 'assets/avatar/packs/trainer-avatar-1'
SLOTS = {'Top': 'top', 'Bottom': 'bottom', 'Hat': 'headwear', 'Boots': 'shoes'}


def build_piece(source, node, identity, author, template):
    # Keep the SDK bind matrices byte-exact and the author’s normals and finishes.
    rig = template.g['skins'][0]
    joints = [{'name': template.g['nodes'][i]['name']} for i in rig['joints']]
    model = {'asset': {'version': '2.0'}, 'nodes': joints, 'skins': [], 'scene': 0,
             'scenes': [{'nodes': [len(joints)]}], 'meshes': [], 'materials': source.g['materials']}
    writer = Builder(model)
    model['skins'].append({'inverseBindMatrices': writer.acc(template.acc(rig['inverseBindMatrices']), 'MAT4'),
                           'joints': list(range(len(joints)))})
    primitives = []
    for primitive in source.g['meshes'][node['mesh']]['primitives']:
        attributes = primitive['attributes']
        positions = source.acc(attributes['POSITION'])
        ids, weights, _, _ = author.binding(positions, 'head' if node['name'] == 'Hat' else 'body')
        mapped = {name: writer.acc(source.acc(index), source.g['accessors'][index]['type'])
                  for name, index in attributes.items()}
        mapped.update(JOINTS_0=writer.acc(ids, 'VEC4'), WEIGHTS_0=writer.acc(weights, 'VEC4'))
        primitives.append(dict(primitive, attributes=mapped,
                               indices=writer.acc(source.acc(primitive['indices']), 'SCALAR')))
    model['meshes'].append({'primitives': primitives})
    model['nodes'].append({'name': identity, 'skin': 0, 'mesh': 0})
    file = PACK / ('wear-' + identity + '.glb')
    writer.save(file)
    return {'slot': SLOTS[node['name']], 'file': file.name, 'sha256': hashlib.sha256(file.read_bytes()).hexdigest(),
            'workshop': True}


def wardrobe_icons():
    icons = ROOT / 'assets/avatar/wardrobe-icons'
    ship = ROOT / 'experiences/ship-home'
    with Image.open(ship / 'assets/fabricator/garments.png') as art:
        cell = art.height // 3
        for y, style in enumerate(('traveller', 'mage', 'merchant')):
            for x, slot in enumerate(('top', 'bottom', 'boots', 'hat')):
                bounds = (x*cell, y*cell, (x+1)*cell, (y+1)*cell)
                art.crop(bounds).resize((128,128), Image.Resampling.LANCZOS).save(icons / f'{style}.{slot}.png')
    # The tile index also covers starter clothing drawn by the avatar pack.
    index = (ship / 'scripts/look_parts.gd').read_text().split('const ICONS=',1)[1].splitlines()[0]
    keys = json.loads(index)
    atlas = Image.new('RGBA', (576, (len(keys)+5)//6*96))
    for i, key in enumerate(keys):
        with Image.open(icons / (key+'.png')) as source:
            image = source.convert('RGBA')
        image.thumbnail((92,92), Image.Resampling.LANCZOS)
        atlas.paste(image, (i%6*96+(96-image.width)//2, i//6*96+(96-image.height)//2))
    atlas.save(ship / 'assets/wardrobe-pieces.webp', lossless=True, method=6)


def main():
    author = Author()
    template = GLB(PACK / 'template.glb')
    manifest_file = PACK / 'manifest.json'
    manifest = json.loads(manifest_file.read_text())
    for style in ('traveller', 'mage', 'merchant'):
        src = GLB(ROOT / 'experiences/ship-home/assets/outfits' / (style + '.glb'))
        for node in src.g['nodes']:
            sku = style + '.' + node['name'].lower()
            entry = build_piece(src, node, sku, author, template)
            manifest['wearables'][sku] = entry
            manifest['files'][entry['file']] = entry['sha256']
    manifest_file.write_text(json.dumps(manifest, indent=2) + '\n')
    wardrobe_icons()


if __name__ == '__main__':
    main()
