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
# Hours per part in PARTS order, frozen into the job at start.
PRINT_HOURS = {'traveller': (6, 2, 4, 2), 'mage': (24, 4, 8, 6), 'merchant': (8, 2, 4, 1)}
COLORS = {
    'sea-glass': ('Sea glass', '#479b91', 'satin'),
    'rose-gold': ('Rose gold', '#c78d75', 'metallic'),
    'aurora': ('Aurora violet', '#7966c2', 'iridescent'),
    'oxide': ('Oxidised copper', '#50867c', 'metallic'),
    'saffron': ('Saffron', '#dfae43', 'matte'),
    'moonstone': ('Moonstone', '#accbda', 'pearlescent'),
}
# Raw field samples identify their island and UTC bloom, even when gathered offline.
BOTANICALS = {'sunbell': 'saffron', 'tideflower': 'sea-glass', 'starbloom': 'aurora'}
EXTRACTION_HOURS = 1
ORES = {'bauxite': 'Aluminium', 'magnetite': 'Steel'}
REFINING_HOURS = 2
CHANNELS = ('primary', 'secondary', 'trim', 'accent')


# Prices are in Sparks. Offers always issue inventory items, including upgrade kits.
SUPPLIES = {
    'case-plan': ('blueprint', 'empty', 30), 'traveller-plan': ('blueprint', 'traveller', 100),
    'merchant-plan': ('blueprint', 'merchant', 100), 'case': ('material', 'Empty', 12),
    'trousers': ('garment', 'traveller.bottom', 45), 'cap': ('garment', 'merchant.hat', 35),
    'cruise-kit': ('upgrade', 'economiser', 250), 'boost-kit': ('upgrade', 'capacitor', 300),
}
UPGRADES = {'economiser': 'Cruise economiser', 'capacitor': 'Boost capacitor'}


def item_title(kind, sku):
    if kind == 'upgrade':
        return UPGRADES[sku]
    if kind == 'blueprint' and sku == 'empty':
        return 'Empty cartridge blueprint'
    if kind == 'ore':
        return sku.capitalize() + ' ore'
    if kind == 'botanical':
        return sku.capitalize() + ' sample'
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
        facts.append({'label': 'Use', 'value': 'Reusable · cartridge shell' if sku == 'empty' else 'Reusable · 4 printable parts'})
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
    orders = conn.execute("""SELECT DISTINCT ON (sku) sku,id,
            greatest(0,ceil(extract(epoch FROM ready_at - statement_timestamp())))::int remaining_seconds,
            count(*) OVER (PARTITION BY sku) quantity
        FROM trainer_backend.workshop_prints WHERE player_id=%s AND item_id IS NULL
        ORDER BY sku,ready_at,id""", (player,)).fetchall()
    wallet = conn.execute('SELECT balance FROM trainer_backend.progression_accounts WHERE player_id=%s', (player,)).fetchone()
    fitted = conn.execute("""SELECT payload->>'sku' sku FROM trainer_backend.loot_items WHERE player_id=%s
        AND adapter_id='octofox.workshop' AND kind='upgrade' AND state='consumed' AND payload->>'installed'='true'""", (player,)).fetchall()
    return {'supplies': {key: {'kind': kind, 'sku': sku, 'price': price, 'title': item_title(kind, sku)}
                         for key, (kind, sku, price) in SUPPLIES.items()},
            'sparks': wallet['balance'] if wallet else 0, 'installed': sorted(row['sku'] for row in fitted),
            'case_hours': 1, 'refining_hours': REFINING_HOURS, 'extraction_hours': EXTRACTION_HOURS, 'print_hours': {style: dict(zip(PARTS, hours)) for style, hours in PRINT_HOURS.items()},
            'prints': {r['sku']: {k: r[k] for k in ('id', 'remaining_seconds', 'quantity')} for r in orders},
            'player_id': player, 'stock': [{**r, 'units': int(r['units'])} for r in counts],
            'palette': [r['color'] for r in palette],
            'colors': {key: {'name': name, 'hex': rgb, 'finish': finish} for key, (name, rgb, finish) in COLORS.items()},
            'recipes': {style: {part: costs for part, (_, costs) in zip(PARTS, pieces)} for style, pieces in RECIPES.items()}}


def stored(conn, player, kind, sku):
    return conn.execute('SELECT id,payload ' + STOCK +
                        " AND kind=%s AND payload->>'sku'=%s ORDER BY sequence LIMIT 1 FOR UPDATE",
                        (player, kind, sku)).fetchone()


def purchase(conn, player, offer, price):
    if offer not in SUPPLIES or SUPPLIES[offer][2] != price:
        raise AuthError('offer_changed', 409)
    kind, sku, _ = SUPPLIES[offer]
    paid = conn.execute("""UPDATE trainer_backend.progression_accounts SET balance=balance-%s,revision=revision+1
        WHERE player_id=%s AND balance>=%s RETURNING balance""", (price, player, price)).fetchone()
    if not paid:
        raise AuthError('insufficient_sparks', 409)
    data = {'sku': sku, 'source': 'Ship supplies'}
    if kind == 'material':
        data['units'] = 1
    if kind == 'garment':
        data['colors'] = {}
    item = write(conn, player, kind, data)
    conn.execute("""INSERT INTO trainer_backend.reward_ledger
        (id,player_id,source,event_id,title,xp,sparks,base_sparks,policy,earned_at,supply_item)
        VALUES(%s,%s,'shop.purchase',%s,%s,0,%s,0,'ship-supplies-v1',statement_timestamp(),%s)""",
                 (uuid4(), player, str(item), item_title(kind, sku), -price, item))
    return item


def install_module(conn, player, sku):
    if conn.execute("""SELECT 1 FROM trainer_backend.loot_items WHERE player_id=%s AND adapter_id='octofox.workshop'
            AND kind='upgrade' AND state='consumed' AND payload->>'sku'=%s AND payload->>'installed'='true'""",
                    (player, sku)).fetchone():
        raise AuthError('already_installed', 409)
    kit = stored(conn, player, 'upgrade', sku)
    if not kit:
        raise AuthError('upgrade_required', 409)
    return write(conn, player, 'upgrade', {**kit['payload'], 'units': 0, 'installed': True}, kit['id'])


def consume_material(conn, player, material, needed):
    while needed:
        lot = stored(conn, player, 'material', material)
        if not lot:
            raise AuthError('insufficient_cartridges', 409)
        data = lot['payload']
        used = min(needed, data['units'])
        data['units'] -= used
        needed -= used
        write(conn, player, 'material', data, lot['id'])


def print_case(conn, player, hours):
    if hours != 1 or not stored(conn, player, 'blueprint', 'empty'):
        raise AuthError('cartridge_blueprint_required', 409)
    consume_material(conn, player, 'Plastic', 1)
    job = uuid4()
    conn.execute("""INSERT INTO trainer_backend.workshop_prints(id,player_id,sku,ready_at)
        VALUES(%s,%s,'material.Empty',statement_timestamp()+interval '1 hour')""", (job, player))
    return job


def print_piece(conn, player, style, part, expected_hours):
    if style not in RECIPES or part not in PARTS:
        raise AuthError('unknown_part', 422)
    hours = PRINT_HOURS[style][PARTS.index(part)]
    if expected_hours != hours:
        raise AuthError('review_print_duration', 409)
    if not stored(conn, player, 'blueprint', style):
        raise AuthError('blueprint_required', 409)
    for material, needed in RECIPES[style][PARTS.index(part)][1].items():
        consume_material(conn, player, material, needed)
    job = uuid4()
    conn.execute("""INSERT INTO trainer_backend.workshop_prints(id,player_id,sku,ready_at)
        VALUES(%s,%s,%s,statement_timestamp()+make_interval(hours => %s))""", (job, player, style + '.' + part, hours))
    return job


def harvest(conn, player, sample, day):
    dates = conn.execute("""SELECT floor(extract(epoch FROM created_at)/86400)::int first_day,
        floor(extract(epoch FROM statement_timestamp())/86400)::int today
        FROM trainer_backend.principals WHERE id=%s""", (player,)).fetchone()
    if not dates['first_day'] <= day <= dates['today']:
        raise AuthError('invalid_harvest_day', 422)
    kind, source = ('ore', 'Island outcrop') if sample in ORES else ('botanical', 'Island harvest')
    return write(conn, player, kind, {'sku': sample, 'source': source, 'day': day})


def extract(conn, player, sample_sku, hours, extra_case=False):
    if sample_sku in ORES:
        kind, duration, output = 'ore', REFINING_HOURS, 'material.' + ORES[sample_sku]
    else:
        kind, duration, output = 'botanical', EXTRACTION_HOURS, 'pigment.' + BOTANICALS[sample_sku]
    if hours != duration:
        raise AuthError('review_extraction_duration', 409)
    sample = stored(conn, player, kind, sample_sku)
    if not sample:
        raise AuthError('field_sample_required', 409)
    running = conn.execute("""SELECT 1 FROM trainer_backend.workshop_prints WHERE player_id=%s
        AND sku=%s AND item_id IS NULL AND ready_at>statement_timestamp() LIMIT 1""", (player, output)).fetchone()
    if running and not extra_case:
        raise AuthError('extra_cartridge_required', 409)
    if running:
        consume_material(conn, player, 'Empty', 1)
    write(conn, player, kind, {**sample['payload'], 'units': 0}, sample['id'])
    job = uuid4()
    conn.execute("""INSERT INTO trainer_backend.workshop_prints(id,player_id,sku,ready_at)
        VALUES(%s,%s,%s,statement_timestamp()+make_interval(hours => %s))""",
                 (job, player, output, hours))
    return job


def collect(conn, player, job):
    row = conn.execute("""SELECT sku,item_id,ready_at<=clock_timestamp() ready FROM trainer_backend.workshop_prints
        WHERE player_id=%s AND id=%s FOR UPDATE""", (player, job)).fetchone()
    if not row:
        raise AuthError('print_not_found', 404)
    if row['item_id']:
        return row['item_id']
    if not row['ready']:
        raise AuthError('print_in_progress', 409)
    if row['sku'].startswith('material.'):
        item = write(conn, player, 'material', {'sku': row['sku'].split('.')[1], 'units': 1, 'source': 'Ship fabricator' if row['sku'] == 'material.Empty' else 'Island refinery'})
    elif row['sku'].startswith('pigment.'):
        item = write(conn, player, 'pigment', {'sku': row['sku'].split('.')[1], 'source': 'Island harvest'})
    else:
        item = write(conn, player, 'garment', {'sku': row['sku'], 'colors': {}})
    conn.execute('UPDATE trainer_backend.workshop_prints SET item_id=%s WHERE id=%s', (item, job))
    return item


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
