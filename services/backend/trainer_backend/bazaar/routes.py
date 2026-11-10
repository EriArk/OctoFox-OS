# SPDX-License-Identifier: GPL-3.0-or-later
from typing import Literal
from uuid import UUID
from fastapi import APIRouter, Request, Query
from pydantic import Field
from ..accounts.routes import StrictBody, bearer, wire
from ..accounts.provider import AuthError

router = APIRouter()


class BazaarDetails(StrictBody):
    name: str = Field(min_length=1, max_length=48, pattern=r'^[^\x00-\x1f\x7f]+$')
    description: str = Field(default='', max_length=280, pattern=r'^[^\x00-\x1f\x7f]*$')
    listed: bool = True
    access: Literal['open', 'closed'] = 'open'


class EditBazaar(BazaarDetails):
    revision: str = Field(pattern=r'^[1-9][0-9]{0,17}$')


def service(request):
    if request.app.state.bazaars is None:
        raise AuthError('provider_not_configured', 503)
    return request.app.state.bazaars


@router.get('/v1/bazaars')
def directory(request: Request, q: str = Query(default='', max_length=64), after: UUID | None = None,
              favorites: str | None = Query(default=None, max_length=3700)):
    ids = None
    if favorites is not None:
        try:
            ids = [UUID(v) for v in favorites.split(',') if v]
            if len(ids)>100:
                raise ValueError()
        except ValueError:
            raise AuthError('invalid_request', 422)
    return wire(service(request).directory(bearer(request), q, after, ids))


@router.put('/v1/me/bazaars/{bazaar_id}')
def update(bazaar_id: UUID, body: EditBazaar, request: Request):
    return wire(service(request).update(bearer(request), bazaar_id, int(body.revision),
                                       body.model_dump(exclude={'revision'})))


@router.post('/v1/me/bazaars')
def create(body: BazaarDetails, request: Request):
    return wire(service(request).create(bearer(request), body.model_dump()))
