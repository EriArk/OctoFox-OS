# SPDX-License-Identifier: GPL-3.0-or-later
from typing import Annotated, Literal
from uuid import UUID
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


class Print(Operation):
    style: Literal['traveller', 'mage', 'merchant']
    part: Literal['top', 'bottom', 'boots', 'hat']


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

        def execute(c, _receipt):
            if revision(c, player) != body.revision:
                raise AuthError('inventory_changed', 409)
            return Outcome('completed', apply(c, player))

        try:
            receipt = run_command(BoundDatabase(conn), Principal(player, 'player'), 'inventory.' + name,
                                  body.operation_id, body.model_dump(mode='json', exclude={'operation_id'}), execute)
        except Conflict:
            raise AuthError('operation_payload_conflict', 409) from None
        return wire({'player_id': player, 'item_id': receipt['resource_id'], 'revision': revision(conn, player)})


@router.post('/v1/me/workshop/print')
def print_part(request: Request, body: Print):
    return mutate(request, 'print', body, lambda c, p: workshop.print_piece(c, p, body.style, body.part))


@router.post('/v1/me/workshop/activate')
def unlock(request: Request, body: Activate):
    return mutate(request, 'activate', body, lambda c, p: workshop.activate(c, p, body.color))


@router.post('/v1/me/workshop/paint')
def paint(request: Request, body: Paint):
    return mutate(request, 'paint', body, lambda c, p: workshop.paint(c, p, body.item, body.channel, body.color))


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
