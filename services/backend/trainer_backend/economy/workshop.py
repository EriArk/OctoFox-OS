# SPDX-License-Identifier: GPL-3.0-or-later
"""Ship fabrication and permanent colour unlocks, backed by profile loot instances."""
from uuid import UUID, uuid4

from psycopg.types.json import Jsonb
from ..accounts.provider import AuthError

PARTS = ('top', 'bottom', 'boots', 'hat')
RECIPES = {
    'traveller': [('Trail cloak', {'Cotton': 6, 'Aluminium': 1}), ('Trail trousers', {'Cotton': 4}),
                  ('Ranger boots', {'Plastic': 3, 'Steel': 1}), ('Feather cap', {'Cotton': 2, 'Aluminium': 1})],
    'mage': [('Starweave coat', {'Cotton': 7, 'Aluminium': 2}), ('Indigo leggings', {'Cotton': 4}),
             ('Rune boots', {'Plastic': 3, 'Aluminium': 1}), ('Astral hat', {'Cotton': 3, 'Plastic': 1})],
    'merchant': [('Apron & vest', {'Cotton': 5, 'Steel': 1}), ('Market breeches', {'Cotton': 4}),
                 ('Guild shoes', {'Plastic': 3, 'Steel': 1}), ('Market beret', {'Cotton': 2})],
}
COLORS = {
    'sea-glass': ('Sea glass', '#479b91', 'satin'),
    'rose-gold': ('Rose gold', '#c78d75', 'metallic'),
    'aurora': ('Aurora violet', '#7966c2', 'iridescent'),
    'oxide': ('Oxidised copper', '#50867c', 'metallic'),
    'saffron': ('Saffron', '#dfae43', 'matte'),
    'moonstone': ('Moonstone', '#accbda', 'pearlescent'),
}
CHANNELS = ('primary', 'secondary', 'trim', 'accent')


def item_title(kind, sku):
    if kind == 'material':
        return sku + ' cartridge'
    if kind == 'pigment':
        return COLORS[sku][0] + ' pigment cartridge'
    if kind == 'blueprint':
        return sku.title() + ' set blueprint'
    style, part = sku.split('.')
    return RECIPES[style][PARTS.index(part)][0]


def write(conn, player, kind, payload, item=None):
    sku = payload['sku']
    facts = [{'label': 'Trade', 'value': 'Bazaar item'}]
    if payload.get('source'):
        facts.append({'label': 'Earned from', 'value': payload['source']})
    if kind == 'blueprint':
        facts.append({'label': 'Use', 'value': 'Reusable · 4 printable parts'})
    if kind == 'material':
        facts.append({'label': 'Units', 'value': str(payload['units'])})
    if kind == 'pigment':
        facts.append({'label': 'Finish', 'value': COLORS[sku][2].title()})
        facts.append({'label': 'Use', 'value': 'Unlock permanently in the fitting station'})
    for channel, color in payload.get('colors', {}).items():
        facts.append({'label': channel.title(), 'value': COLORS[color][0] + ' · ' + COLORS[color][2].title()})
    card = {'title': item_title(kind, sku), 'game': 'OctoFox Ship', 'subtitle': kind.title(),
            'facts': facts, 'icon': 'map' if kind == 'blueprint' else 'inventory'}
    if kind == 'pigment':
        card.update(swatch=COLORS[sku][1], subtitle=COLORS[sku][2].title())
    elif kind == 'material':
        card['subtitle'] = '×' + str(payload['units'])
    identity = item or uuid4()
    conn.execute('SELECT trainer_backend.write_workshop_item(%s,%s,%s,%s,%s,%s,%s)',
                 (identity, player, kind, Jsonb(payload), Jsonb(card), payload.get('units', 1) > 0, item is None))
    return identity


def lock_account(conn, player):
    conn.execute('INSERT INTO trainer_backend.progression_accounts(player_id) VALUES(%s) ON CONFLICT DO NOTHING', (player,))
    conn.execute('SELECT player_id FROM trainer_backend.progression_accounts WHERE player_id=%s FOR UPDATE', (player,))


def reward(conn, player, event):
    lock_account(conn, player)
    row = conn.execute('''INSERT INTO trainer_backend.workshop_rewards(player_id,event,ordinal)
        SELECT %s,%s,coalesce(max(ordinal),0)+1 FROM trainer_backend.workshop_rewards WHERE player_id=%s
        ON CONFLICT(player_id,event) DO NOTHING RETURNING ordinal''', (player, event, player)).fetchone()
    if not row:
        return False
    source = {'play': 'Daily play', 'level': 'Player level', 'ra.achievement': 'Achievement',
              'ra.completion': 'Game completion', 'game': 'Game award'}.get(event.partition(':')[0], 'Game reward')
    n = row['ordinal'] - 1
    if n % 3 == 0:
        write(conn, player, 'blueprint', {'sku': tuple(RECIPES)[(n // 3) % len(RECIPES)], 'source': source})
    for material, units in [('Cotton', 6), (('Aluminium', 'Steel', 'Plastic')[n % 3], (1, 2, 4)[n % 3])]:
        write(conn, player, 'material', {'sku': material, 'units': units, 'source': source})
    write(conn, player, 'pigment', {'sku': tuple(COLORS)[n % len(COLORS)], 'source': source})
    return True


STOCK = """FROM trainer_backend.loot_items WHERE player_id=%s AND adapter_id='octofox.workshop' AND state='stored'"""


def snapshot(conn, player):
    # Group in SQL: a large inventory still yields one small row per catalogue entry.
    counts = conn.execute("SELECT kind,payload->>'sku' sku,sum(coalesce((payload->>'units')::int,1)) units "
                          + STOCK + ' GROUP BY 1,2 ORDER BY 1,2', (player,)).fetchall()
    palette = conn.execute('SELECT color FROM trainer_backend.workshop_palette WHERE player_id=%s ORDER BY color', (player,)).fetchall()
    return {'player_id': player, 'stock': [{**r, 'units': int(r['units'])} for r in counts],
            'palette': [r['color'] for r in palette],
            'colors': {key: {'name': name, 'hex': rgb, 'finish': finish} for key, (name, rgb, finish) in COLORS.items()},
            'recipes': {style: {part: costs for part, (_, costs) in zip(PARTS, pieces)} for style, pieces in RECIPES.items()}}


def stored(conn, player, kind, sku):
    return conn.execute('SELECT id,payload ' + STOCK +
                        " AND kind=%s AND payload->>'sku'=%s ORDER BY sequence LIMIT 1 FOR UPDATE",
                        (player, kind, sku)).fetchone()


def print_piece(conn, player, style, part):
    if style not in RECIPES or part not in PARTS:
        raise AuthError('unknown_part', 422)
    if not stored(conn, player, 'blueprint', style):
        raise AuthError('blueprint_required', 409)
    for material, needed in RECIPES[style][PARTS.index(part)][1].items():
        while needed:
            lot = stored(conn, player, 'material', material)
            if not lot:
                raise AuthError('insufficient_cartridges', 409)
            data = lot['payload']
            used = min(needed, data['units'])
            data['units'] -= used
            needed -= used
            write(conn, player, 'material', data, lot['id'])
    return write(conn, player, 'garment', {'sku': style + '.' + part, 'colors': {}})


def activate(conn, player, color):
    if color not in COLORS:
        raise AuthError('unknown_color', 422)
    added = conn.execute('INSERT INTO trainer_backend.workshop_palette VALUES(%s,%s) ON CONFLICT DO NOTHING RETURNING color',
                         (player, color)).fetchone()
    if not added:
        raise AuthError('color_already_unlocked', 409)
    lot = stored(conn, player, 'pigment', color)
    if not lot:
        raise AuthError('pigment_required', 409)
    write(conn, player, 'pigment', {'sku': color, 'units': 0}, lot['id'])
    return lot['id']


def paint(conn, player, item: UUID, channel, color):
    if channel not in CHANNELS or (color != 'original' and color not in COLORS):
        raise AuthError('unknown_color_channel', 422)
    row = conn.execute('SELECT payload ' + STOCK + " AND id=%s AND kind='garment' FOR UPDATE", (player, item)).fetchone()
    if not row:
        raise AuthError('garment_unavailable', 409)
    if color != 'original' and not conn.execute('SELECT 1 FROM trainer_backend.workshop_palette WHERE player_id=%s AND color=%s',
                                                (player, color)).fetchone():
        raise AuthError('color_locked', 409)
    data = row['payload']
    if color == 'original':
        data['colors'].pop(channel, None)
    else:
        data['colors'][channel] = color
    write(conn, player, 'garment', data, item)
    return item
