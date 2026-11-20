# SPDX-License-Identifier: GPL-3.0-or-later
from uuid import UUID
from fastapi import APIRouter, Request, Query
from pydantic import Field
from ..accounts.routes import StrictBody, bearer, wire
from ..accounts.provider import AuthError
from .routes import service
from .prizes import Prizes

router = APIRouter()


def prize_wire(request, snapshot):
    if request.query_params.get('format') != '2':
        # Older shells reject the entire history when any grant has an unknown kind.
        rows = snapshot['items'] + snapshot['waiting']
        for group in snapshot['collection']:
            rows.extend(group['grants'])
        for row in rows:
            if row['kind'] == 'workshop':
                row['kind'] = 'clothing'
        for level in snapshot['upcoming']:
            if level.pop('workshop', False):
                level['clothing'] = True
    return wire(snapshot)


class Seen(StrictBody):
    ids: list[str] = Field(max_length=100)


class Shelf(StrictBody):
    games: list[int] = Field(max_length=5)


@router.get('/v1/me/prizes')
def prizes(request: Request, before: int | None = Query(default=None, ge=1),
           group_before: int | None = Query(default=None, ge=1)):
    return prize_wire(request, Prizes(service(request)).snapshot(bearer(request), before, group_before))


@router.post('/v1/me/prizes/seen')
def seen(body: Seen, request: Request):
    try:
        ids = [UUID(i) for i in body.ids]
    except ValueError:
        raise AuthError('invalid_prize_ids', 422) from None
    return prize_wire(request, Prizes(service(request)).acknowledge(bearer(request), ids))


@router.put('/v1/me/prizes/shelf')
def shelf(body: Shelf, request: Request):
    if any(type(i) is not int or not 0 < i <= 2147483647 for i in body.games):
        raise AuthError('invalid_shelf', 422)
    return prize_wire(request, Prizes(service(request)).shelf(bearer(request), body.games))
