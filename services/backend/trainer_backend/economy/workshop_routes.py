# SPDX-License-Identifier: GPL-3.0-or-later
from typing import Annotated, Literal
from uuid import UUID, uuid5
from psycopg.types.json import Jsonb
from fastapi import APIRouter, Request
from pydantic import Field
from ..accounts.provider import AuthError
from ..accounts.routes import StrictBody, bearer, wire
from ..commands import Conflict, Outcome, Principal, run_command
from ..play.service import BoundDatabase
from .routes import service
from . import prizes, workshop

router = APIRouter()
Id = Annotated[str, Field(pattern=r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]


class Operation(StrictBody):
    operation_id: Id
    revision: str = Field(pattern=r'^(0|[1-9][0-9]{0,18})$')


class Collect(Operation):
    job: Id


class Print(Operation):
    hours: int | None = Field(default=None, ge=1, le=24)
    style: Literal['traveller', 'mage', 'merchant']
    part: Literal['top', 'bottom', 'boots', 'hat']


Plant = Literal['sunbell', 'tideflower', 'starbloom']


class CasePrint(Operation):
    casing: Literal['empty']
    hours: int


class BotanicalPrint(Operation):
    extra_case: bool = False
    plant: Plant
    hours: int


Ore = Literal['bauxite', 'magnetite']


class OrePrint(Operation):
    extra_case: bool = False
    ore: Ore
    hours: int


class FieldBatch(StrictBody):
    day: int = Field(ge=0, le=4000000)
    player_id: Id


class Harvest(FieldBatch):
    plant: Plant


class OreBatch(FieldBatch):
    ore: Ore


class Activate(Operation):
    color: str = Field(max_length=32)


class Paint(Activate):
    item: Id
    channel: Literal['primary', 'secondary', 'trim', 'accent']


def revision(conn, player):
    row = conn.execute('SELECT revision FROM trainer_backend.loot_revisions WHERE player_id=%s', (player,)).fetchone()
    return str(row['revision']) if row else '0'


@router.get('/v1/me/workshop')
def overview(request: Request):
    api = service(request)
    with api.db.transaction() as conn:
        conn.execute('SET TRANSACTION ISOLATION LEVEL REPEATABLE READ')
        player = api.accounts.authenticate(conn, bearer(request)).player_id
        return wire({**workshop.snapshot(conn, player), 'revision': revision(conn, player)})


@router.get('/v1/me/workshop/garments')
def garments(request: Request, after: UUID | None = None):
    api = service(request)
    with api.db.transaction() as conn:
        player = api.accounts.authenticate(conn, bearer(request)).player_id
        rows = conn.execute('SELECT id,payload ' + workshop.STOCK +
                            " AND kind='garment' AND (%s::uuid IS NULL OR id>%s) ORDER BY id LIMIT 25",
                            (player, after, after)).fetchall()
        return wire({'player_id': player, 'items': [{'id': r['id'], **r['payload']} for r in rows[:24]],
                     'next': str(rows[23]['id']) if len(rows) > 24 else None})


def mutate(request, name, body, apply):
    api = service(request)
    with api.db.transaction() as conn:
        player = api.account(conn, bearer(request)).player_id
        workshop.lock_account(conn, player)

        if getattr(body, 'player_id', str(player)) != str(player):
            raise AuthError('identity_changed', 409)
        payload = body.model_dump(mode='json', exclude={'operation_id'}, exclude_none=True)
        if payload.get('extra_case') is False:
            del payload['extra_case']  # Preserve receipt hashes for pre-refinery clients.

        def execute(c, _receipt):
            if revision(c, player) != body.revision:
                raise AuthError('inventory_changed', 409)
            return Outcome('completed', apply(c, player))

        try:
            receipt = run_command(BoundDatabase(conn), Principal(player, 'player'), 'inventory.' + name,
                                  body.operation_id, payload, execute)
        except Conflict:
            raise AuthError('operation_payload_conflict', 409) from None
        key = 'job_id' if name == 'print' and body.hours is not None else 'item_id'
        return wire({'player_id': player, key: receipt['resource_id'], 'revision': revision(conn, player)})


@router.post('/v1/me/workshop/print')
def print_part(request: Request, body: Print | BotanicalPrint | OrePrint | CasePrint):
    if isinstance(body, CasePrint):
        return mutate(request, 'print', body, lambda c,p: workshop.print_case(c,p,body.hours))
    if isinstance(body, OrePrint):
        return mutate(request, 'print', body, lambda c, p: workshop.extract(c, p, body.ore, body.hours, body.extra_case))
    if isinstance(body, BotanicalPrint):
        return mutate(request, 'print', body, lambda c, p: workshop.extract(c, p, body.plant, body.hours, body.extra_case))
    return mutate(request, 'print', body, lambda c, p: workshop.print_piece(c, p, body.style, body.part, body.hours))


@router.post('/v1/me/workshop/collect')
def collect(request: Request, body: Collect | Harvest | OreBatch):
    if isinstance(body, FieldBatch):
        origin, sku = ('mining', body.ore) if isinstance(body, OreBatch) else ('botany', body.plant)
        api = service(request)
        with api.db.transaction() as conn:
            player = api.account(conn, bearer(request)).player_id
            if str(player) != body.player_id:
                raise AuthError('identity_changed', 409)
            workshop.lock_account(conn, player)
            key = uuid5(UUID(str(player)), f'octofox.{origin}.{sku}.{body.day}')
            receipt = run_command(BoundDatabase(conn), Principal(player, 'player'), 'inventory.harvest',
                                  str(key), body.model_dump(), lambda c, _: Outcome(
                                      'completed', workshop.harvest(c, player, sku, body.day)))
            return wire({'player_id': player, 'item_id': receipt['resource_id']})
    return mutate(request, 'collect', body, lambda c, p: workshop.collect(c, p, body.job))


class SuppliesOrder(Operation):
    player_id: Id
    offer: str = Field(max_length=32)
    price: int = Field(gt=0)


class FitModule(Operation):
    player_id: Id
    module: Literal['economiser', 'capacitor']


@router.post('/v1/me/workshop/buy')
def buy(request: Request, body: SuppliesOrder):
    return mutate(request, 'buy', body, lambda c, p: workshop.purchase(c, p, body.offer, body.price))


@router.post('/v1/me/workshop/install')
def install(request: Request, body: FitModule):
    return mutate(request, 'install', body, lambda c, p: workshop.install_module(c, p, body.module))


@router.post('/v1/me/workshop/activate')
def unlock(request: Request, body: Activate):
    return mutate(request, 'activate', body, lambda c, p: workshop.activate(c, p, body.color))


@router.post('/v1/me/workshop/paint')
def paint(request: Request, body: Paint):
    return mutate(request, 'paint', body, lambda c, p: workshop.paint(c, p, body.item, body.channel, body.color))


class ShoreFish(StrictBody):
    id: Id
    species: Literal['glassfin', 'loach', 'ribbon']
    site: Literal[1, 3]


FISH = {
    'glassfin': ('Glassfin', 9, 19, ('#9adcca', '#83badb')),
    'loach': ('Copper loach', 18, 34, ('#c99366', '#d5b57b')),
    'ribbon': ('Ribbon ray', 32, 56, ('#a293d9', '#e39dad')),
}


@router.post('/v1/me/workshop/fish')
def land_fish(request: Request, body: ShoreFish):
    identity = UUID(body.id)
    if identity.version != 4 or (body.species, body.site) in [('loach', 3), ('ribbon', 1)]:
        raise AuthError('invalid_catch', 422)
    api = service(request)
    with api.db.transaction() as conn:
        player = api.account(conn, bearer(request)).player_id
        workshop.lock_account(conn, player)
        payload = {'angler': str(player), 'species': body.species, 'site': body.site}

        def issue(c, _receipt):
            # Offline catches are client-reported. Bound admission per original angler,
            # including fish already sold; only the fixed catalogue crosses this boundary.
            count = c.execute("""SELECT count(*) n FROM trainer_backend.loot_items
                WHERE adapter_id='octofox.fishing' AND payload->>'angler'=%s
                AND received_at>clock_timestamp()-interval '24 hours'""", (str(player),)).fetchone()['n']
            if count >= 24:
                raise AuthError('daily_landing_limit', 429)
            title, low, high, colors = FISH[body.species]
            length = low + int(identity.hex[:4], 16) % (high-low+1)
            shore = {1: 'Echo Orchard', 3: 'Table Isle'}[body.site]
            card = {'title': title, 'game': 'OctoFox Ship', 'subtitle': f'{length} cm',
                    'swatch': colors[identity.bytes[2] % 2], 'icon': 'inventory',
                    'facts': [{'label': 'Caught at', 'value': shore}, {'label': 'Length', 'value': f'{length} cm'}]}
            stored = c.execute('SELECT trainer_backend.store_shore_fish(%s,%s,%s,%s) AS ok',
                               (body.id, player, Jsonb(payload), Jsonb(card))).fetchone()
            if not stored['ok']:
                raise AuthError('catch_identity_conflict', 409)
            return Outcome('completed', identity)

        try:
            receipt = run_command(BoundDatabase(conn), Principal(player, 'player'), 'inventory.landfish',
                                  str(body.id), payload, issue)
        except Conflict:
            raise AuthError('catch_identity_conflict', 409) from None
        return wire({'player_id': player, 'item_id': receipt['resource_id']})


class FishDisplay(StrictBody):
    id: Id
    display: bool


@router.post('/v1/me/workshop/fishdisplay')
def arrange_fish(request: Request, body: FishDisplay):
    api = service(request)
    with api.db.transaction() as conn:
        player = api.account(conn, bearer(request)).player_id
        workshop.lock_account(conn, player)
        row = conn.execute("""SELECT id FROM trainer_backend.loot_items WHERE id=%s AND player_id=%s
            AND adapter_id='octofox.fishing' AND state='stored' FOR UPDATE""", (body.id, player)).fetchone()
        if not row:
            raise AuthError('fish_unavailable', 409)
        if body.display:
            current = conn.execute('SELECT item_id FROM trainer_backend.fish_display WHERE player_id=%s', (player,)).fetchall()
            if len(current) >= 8 and not any(str(r['item_id']) == body.id for r in current):
                raise AuthError('aquarium_full', 409)
            conn.execute('INSERT INTO trainer_backend.fish_display VALUES(%s,%s) ON CONFLICT DO NOTHING', (body.id, player))
        else:
            conn.execute('DELETE FROM trainer_backend.fish_display WHERE player_id=%s AND item_id=%s', (player, body.id))
        return wire({'player_id': player})


@router.get('/v1/me/workshop/fishstock')
def fishstock(request: Request, after: UUID | None = None):
    api = service(request)
    with api.db.transaction() as conn:
        conn.execute('SET TRANSACTION ISOLATION LEVEL REPEATABLE READ')
        player = api.accounts.authenticate(conn, bearer(request)).player_id
        owned = """ FROM trainer_backend.loot_items i LEFT JOIN trainer_backend.fish_display d
                    ON d.item_id=i.id WHERE i.adapter_id='octofox.fishing' AND i.state='stored' AND i.player_id=%s"""
        fields = "SELECT i.id, i.payload->>'species' species, (i.payload->>'site')::int site"
        tank = conn.execute(fields + owned + ' AND d.item_id IS NOT NULL ORDER BY i.id', (player,)).fetchall()
        bag = conn.execute(fields + owned + ' AND d.item_id IS NULL AND (%s::uuid IS NULL OR i.id>%s) ORDER BY i.id LIMIT 25',
                           (player, after, after)).fetchall()
        return wire({'player_id': player, 'tank': tank, 'items': bag[:24],
                     'next': str(bag[23]['id']) if len(bag) > 24 else None})


class PlayPulse(StrictBody):
    session: Id


@router.post('/v1/me/workshop/play')
def play(request: Request, body: PlayPulse):
    api = service(request)
    with api.db.transaction() as conn:
        player = api.account(conn, bearer(request)).player_id
        workshop.lock_account(conn, player)
        # Only server time counts. Switching games or missing two heartbeats restarts the interval.
        row = conn.execute("""INSERT INTO trainer_backend.workshop_play(player_id,session_id) VALUES(%s,%s)
            ON CONFLICT(player_id) DO UPDATE SET session_id=excluded.session_id,last_seen=clock_timestamp(),
            started_at=CASE WHEN workshop_play.session_id=excluded.session_id
              AND workshop_play.last_seen>=clock_timestamp()-interval '150 seconds' THEN workshop_play.started_at
              ELSE clock_timestamp() END RETURNING started_at<=clock_timestamp()-interval '5 minutes' eligible,
              (clock_timestamp() AT TIME ZONE 'UTC')::date AS play_day, clock_timestamp() earned""", (player, body.session)).fetchone()
        event = 'play:' + row['play_day'].isoformat()
        if row['eligible'] and workshop.reward(conn, player, event):
            prizes.grant(conn, player, event, 'workshop', 'Daily play supplies', row['earned'])
        return wire({'player_id': player})
