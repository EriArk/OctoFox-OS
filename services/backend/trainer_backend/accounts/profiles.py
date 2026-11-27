# SPDX-License-Identifier: GPL-3.0-or-later
"""Public presentation, never authentication or inventory authority."""
import re
import unicodedata
from uuid import UUID
from psycopg.types.json import Jsonb
from .provider import AuthError


def display_name(user):
    for key in ('global_name', 'username'):
        value = user.get(key)
        if isinstance(value, str):
            value = unicodedata.normalize('NFC', value)
            value = ''.join(c for c in value if not unicodedata.category(c).startswith('C'))
            value = ' '.join(value.split())[:64].strip()
            if value:
                return value
    return 'Player'


# Inventory-backed appearance slots use the existing workshop SKU and UUID.
SHIP_SLOTS = {'top': 'top', 'bottom': 'bottom', 'shoes': 'boots', 'headwear': 'hat'}


def owned_parts(conn, player, recipe):
    parts = ((recipe or {}).get('appearance') or {}).get('equipment', {})
    for slot in sorted(parts):
        entry = parts[slot]
        item = conn.execute("""SELECT payload FROM trainer_backend.loot_items
            WHERE id=%s AND player_id=%s AND adapter_id='octofox.workshop' AND kind='garment'
            AND state='stored' FOR UPDATE""", (UUID(entry['id']), player)).fetchone()
        if not item or item['payload']['sku'] != recipe['appearance'][slot]:
            raise AuthError('garment_not_owned', 409)
        if item['payload'].get('colors', {}) != entry['colors']:
            raise AuthError('garment_finish_changed', 409)


def avatar_recipe(value):
    # Current free SDK pack only. No URLs, paths, meshes or item ownership claims.
    if value is None:
        return None
    valid = isinstance(value, dict) and set(value) == {'schema', 'packRevision', 'appearance'}
    valid = valid and type(value['schema']) is int and value['schema'] == 1
    valid = valid and isinstance(value['packRevision'], str) and re.fullmatch('[a-f0-9]{64}', value['packRevision'])
    a = value.get('appearance') if valid else None
    colors = {'skinColor', 'hairColor', 'eyeColor', 'shirtColor', 'shortsColor'}
    wardrobe = {'top': ('tank', 'polo-short-sleeve', 'polo-sleeveless', 'everyday-tee', 'sundress', 'racing-suit', 'rose-racing-suit'),
                'bottom': ('base-shorts', 'golf-shorts', 'pleated-skirt', 'denim-breeches', 'denim-breeches-womens'),
                'socks': ('none', 'ankle-socks', 'crew-socks'),
                'shoes': ('sandals', 'golf-shoes-classic', 'golf-shoes-sport', 'canvas-shoes', 'racing-boots', 'rose-racing-boots'),
                'headwear': ('none', 'golf-cap', 'golf-visor', 'racing-helmet', 'rose-racing-helmet')}
    valid = valid and isinstance(a, dict) and type(a.get('schema')) is int and a['schema'] in (1, 2, 3, 4)
    if valid and a['schema'] >= 3:
        colors |= {'socksColor', 'shoesColor', 'headwearColor'}
    required = colors | {'schema', 'pack', 'hair', 'eyes'}
    if valid and a['schema'] >= 2:
        required |= wardrobe.keys()
    if valid and a['schema'] == 4:
        from ..economy.workshop import RECIPES, COLORS, CHANNELS
        required.add('equipment')
        equipment = a.get('equipment')
        valid = isinstance(equipment, dict) and 1 <= len(equipment) <= 4 and set(equipment) <= SHIP_SLOTS.keys()
        if valid:
            for slot, item in equipment.items():
                valid = (isinstance(item, dict) and set(item) == {'id', 'colors'}
                         and isinstance(item['id'], str) and re.fullmatch(r'[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}', item['id'])
                         and isinstance(item['colors'], dict) and set(item['colors']) <= set(CHANNELS)
                         and all(isinstance(v, str) and v in COLORS for v in item['colors'].values())
                         and a.get(slot) in tuple(f'{style}.{SHIP_SLOTS[slot]}' for style in RECIPES))
                if not valid:
                    break
                wardrobe[slot] += (a[slot],)
    valid = valid and set(a) == required and a['pack'] == 'trainer-avatar-1'
    valid = valid and (a['schema'] == 1 or all(isinstance(a[k], str) and a[k] in values for k, values in wardrobe.items()))
    eyes = ('round', 'almond') + tuple(f'{style}-{variant}'
        for style in ('rogue', 'innocent', 'sly', 'calm', 'sleepy', 'determined')
        for variant in ('base', 'feminine'))
    valid = valid and a['hair'] in ('swept', 'ponytail', 'crop', 'bob') and a['eyes'] in eyes
    valid = valid and all(isinstance(a[k], str) and re.fullmatch('#[a-fA-F0-9]{6}', a[k]) for k in colors)
    if not valid:
        raise AuthError('invalid_avatar_recipe', 422)
    return value


def public_profiles(conn, players):
    ids = sorted({UUID(str(p)) for p in players})
    if not ids:
        return {}
    rows = conn.execute('''SELECT f.player_id,f.display_name,f.avatar,f.revision
        FROM trainer_backend.public_profiles f JOIN trainer_backend.principals p ON p.id=f.player_id
        WHERE f.player_id=ANY(%s) AND p.state='active' ''', (ids,)).fetchall()
    profiles = {str(r['player_id']): r for r in rows}
    return {str(p): profiles.get(str(p), {'player_id': p, 'display_name': 'Player', 'avatar': None, 'revision': 0}) for p in ids}


def ensure_profile(conn, player):
    conn.execute('''INSERT INTO trainer_backend.public_profiles(player_id,display_name,needs_name,needs_avatar)
        VALUES(%s,%s,true,true) ON CONFLICT(player_id) DO NOTHING''',(player,'Fox-'+str(player).replace('-','')[:12]))


def nickname(value):
    if not isinstance(value,str) or any(unicodedata.category(c).startswith('C') or c in '\r\n\u2028\u2029' for c in value):
        raise AuthError('invalid_nickname',422)
    value = ' '.join(unicodedata.normalize('NFC',value).split())
    if not 1 <= len(value) <= 24:
        raise AuthError('invalid_nickname',422)
    return value


def update_name(conn, player, name):
    conn.execute('''INSERT INTO trainer_backend.public_profiles(player_id,display_name) VALUES(%s,%s)
        ON CONFLICT(player_id) DO UPDATE SET display_name=EXCLUDED.display_name,
        revision=public_profiles.revision+1,updated_at=clock_timestamp()
        WHERE public_profiles.display_name IS DISTINCT FROM EXCLUDED.display_name''', (player, name))


def update_avatar(conn, player, avatar):
    owned_parts(conn, player, avatar)
    conn.execute('''INSERT INTO trainer_backend.public_profiles(player_id,display_name,avatar) VALUES(%s,'Player',%s)
        ON CONFLICT(player_id) DO UPDATE SET avatar=EXCLUDED.avatar,needs_avatar=false,
        revision=public_profiles.revision+1,updated_at=clock_timestamp()
        WHERE public_profiles.avatar IS DISTINCT FROM EXCLUDED.avatar OR public_profiles.needs_avatar''', (player, Jsonb(avatar) if avatar is not None else None))
