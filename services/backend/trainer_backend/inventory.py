# SPDX-License-Identifier: GPL-3.0-or-later
"""Private, read-only collectible projection. Opaque adapter payload never leaves it."""
from typing import Literal

from fastapi import APIRouter, Query, Request
from pydantic import Field

from .accounts.provider import AuthError
from .accounts.routes import StrictBody, bearer, service, wire

router = APIRouter()
PAGE_SIZE = 60


class Fact(StrictBody):
    label: str = Field(min_length=1, max_length=32)
    value: str = Field(max_length=128)


class Presentation(StrictBody):
    title: str = Field(min_length=1, max_length=96)
    game: str = Field(min_length=1, max_length=128)
    subtitle: str = Field(default='', max_length=32)
    icon: Literal['inventory', 'star', 'shield', 'shop', 'gamepad', 'map'] = 'inventory'
    level: int | None = Field(default=None, ge=0, le=999999)
    facts: list[Fact] = Field(default_factory=list, max_length=16)


def read_inventory(accounts, access, *, before=None, revision=None):
    if (before is None) != (revision is None):
        raise AuthError('invalid_inventory_page', 422)
    with accounts.db.transaction() as conn:
        # Auth, revision, count and records describe the same committed snapshot.
        conn.execute('SET TRANSACTION ISOLATION LEVEL REPEATABLE READ')
        player = accounts.authenticate(conn, access).player_id
        version = conn.execute('SELECT revision FROM trainer_backend.loot_revisions WHERE player_id=%s', (player,)).fetchone()
        current = str(version['revision']) if version else '0'
        if revision is not None and revision != current:
            raise AuthError('inventory_changed', 409)
        total = conn.execute('SELECT count(*) AS n FROM trainer_backend.loot_items WHERE player_id=%s', (player,)).fetchone()['n']
        rows = conn.execute('''SELECT sequence,id,game_id,adapter_id,payload_version,kind,presentation,state,received_at
            FROM trainer_backend.loot_items WHERE player_id=%s AND (%s::bigint IS NULL OR sequence<%s)
            ORDER BY sequence DESC LIMIT %s''', (player, before, before, PAGE_SIZE+1)).fetchall()
        items = []
        for row in rows[:PAGE_SIZE]:
            # Never forward arbitrary JSON, URLs, HTML or game save bytes to QML.
            presentation = Presentation.model_validate(row['presentation']).model_dump(exclude_none=True)
            items.append({**{key: row[key] for key in ('id', 'game_id', 'adapter_id', 'payload_version', 'kind', 'state', 'received_at')},
                          'presentation': presentation, 'actions': []})
        return {'version': 1, 'player_id': player, 'revision': current, 'total': total,
                'items': items, 'next': str(rows[PAGE_SIZE-1]['sequence']) if len(rows)>PAGE_SIZE else None,
                'transfers_available': False}


@router.get('/v1/me/loot')
def inventory(request: Request,
              before: int | None = Query(default=None, ge=1, le=9223372036854775807),
              revision: str | None = Query(default=None, pattern=r'^(0|[1-9][0-9]{0,18})$')):
    return wire(read_inventory(service(request), bearer(request), before=before, revision=revision))
