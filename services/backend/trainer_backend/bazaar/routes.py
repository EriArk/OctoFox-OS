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
    cover: Literal['market','grove','harbor'] | None = None
    badge: Literal['shop','community','companion','trophy','guide'] | None = None


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
                                       body.model_dump(exclude={'revision'},exclude_none=True)))


@router.post('/v1/me/bazaars')
def create(body: BazaarDetails, request: Request):
    return wire(service(request).create(bearer(request), body.model_dump(exclude_none=True)))


class BlockPlayer(StrictBody):
    revision: str = Field(pattern=r'^[1-9][0-9]{0,17}$')
    blocked: bool


@router.get('/v1/me/bazaars/{bazaar_id}/access')
def access_settings(bazaar_id: UUID, request: Request, after: UUID | None = None, target: UUID | None = None):
    return wire(service(request).access_settings(bearer(request),bazaar_id,after,target))


@router.put('/v1/me/bazaars/{bazaar_id}/blocks/{player_id}')
def block_player(bazaar_id: UUID, player_id: UUID, body: BlockPlayer, request: Request):
    return wire(service(request).block(bearer(request),bazaar_id,player_id,body.blocked,int(body.revision)))


@router.get('/v1/bazaars/{bazaar_id}/access')
def access_policy(bazaar_id: UUID, request: Request):
    return wire(service(request).access_policy(bearer(request),bazaar_id))


# Provisioned places only. No client or temporary host can create paid inventory.
from . import rentals


class PlacePrice(StrictBody):
    revision: str = Field(pattern=r'^[1-9][0-9]{0,17}$')
    weekly_price: int = Field(ge=1,le=2147483647)


class RentPlace(StrictBody):
    operation_id: str = Field(pattern=r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
    revision: str = Field(pattern=r'^[1-9][0-9]{0,17}$')
    expected_price: int = Field(ge=1,le=2147483647)


@router.get('/v1/bazaars/{bazaar_id}/places')
def places(bazaar_id: UUID, request: Request, after: UUID | None = None):
    return wire(rentals.places(service(request),bearer(request),bazaar_id,after))


@router.put('/v1/me/bazaars/{bazaar_id}/places/{place_id}')
def place_price(bazaar_id: UUID, place_id: UUID, body: PlacePrice, request: Request):
    return wire(rentals.price(service(request),bearer(request),bazaar_id,place_id,int(body.revision),body.weekly_price))


@router.post('/v1/bazaars/{bazaar_id}/places/{place_id}/rent')
def rent_place(bazaar_id: UUID, place_id: UUID, body: RentPlace, request: Request):
    return wire(rentals.rent(service(request),bearer(request),UUID(body.operation_id),bazaar_id,place_id,int(body.revision),body.expected_price))


@router.get('/v1/me/bazaar-rentals/{operation_id}')
def rental_receipt(operation_id: UUID, request: Request):
    return wire(rentals.receipt(service(request),bearer(request),operation_id))

# A seller is paid once for this rental only, not a permanent profile unlock.
from . import trading


class HireSeller(RentPlace):
    species: Literal['Casual_Female','Casual_Male','Chef_Female','Kimono_Female','OldClassy_Male',
                     'Wizard','Witch','Bunny','Yeti','Dino','Frog','Birb']


class ListItem(StrictBody):
    operation_id: str = Field(pattern=r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
    item_id: str = Field(pattern=r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
    price: int = Field(ge=1,le=2147483647)


class ListingRevision(StrictBody):
    revision: str = Field(pattern=r'^[1-9][0-9]{0,17}$')


@router.get('/v1/bazaar-sellers')
def seller_catalogue(request: Request):
    s=service(request)
    with s.db.transaction() as conn:
        actor=s.progression.account(conn,bearer(request))
        return wire({'player_id':actor.player_id,'items':[{'id':v,'price':trading.SELLER_PRICE,'revision':1} for v in trading.SPECIES],
                     'payments_available':trading.policy.PAYMENTS_AVAILABLE,'duration':'current_rental'})


@router.post('/v1/me/bazaar-rentals/{rental_id}/seller')
def hire_seller(rental_id: UUID, body: HireSeller, request: Request):
    return wire(trading.hire(service(request),bearer(request),rental_id,UUID(body.operation_id),body.species,int(body.revision),body.expected_price))


@router.post('/v1/me/bazaar-rentals/{rental_id}/listings')
def list_item(rental_id: UUID, body: ListItem, request: Request):
    return wire(trading.create_listing(service(request),bearer(request),rental_id,UUID(body.item_id),UUID(body.operation_id),body.price))


@router.get('/v1/me/bazaar-listings')
def own_listings(request: Request, after: UUID | None = None):
    return wire(trading.listings(service(request),bearer(request),after=after))


@router.get('/v1/bazaar-places/{place_id}/listings')
def place_listings(place_id: UUID, request: Request, after: UUID | None = None):
    return wire(trading.listings(service(request),bearer(request),place_id,after))


@router.post('/v1/me/bazaar-listings/{listing_id}/withdraw')
def withdraw_listing(listing_id: UUID, body: ListingRevision, request: Request):
    return wire(trading.withdraw(service(request),bearer(request),listing_id,int(body.revision)))


@router.post('/v1/bazaar-listings/{listing_id}/buy')
def buy_listing(listing_id: UUID, body: RentPlace, request: Request):
    return wire(trading.buy(service(request),bearer(request),listing_id,UUID(body.operation_id),int(body.revision),body.expected_price))


@router.get('/v1/me/bazaar-trades/{operation_id}')
def trade_receipt(operation_id: UUID, request: Request):
    return wire(trading.receipt(service(request),bearer(request),operation_id))


@router.get('/v1/bazaar-worlds/{world_key}')
def world_services(world_key: str, request: Request):
    if world_key!='festival':raise AuthError('world_not_found',404)
    return wire(trading.world(service(request),bearer(request),world_key))


@router.get('/v1/bazaar-costumes')
def costume_catalogue(request: Request):
    s=service(request)
    with s.db.transaction() as conn:
        actor=s.progression.account(conn,bearer(request))
        rows=conn.execute("SELECT id,title,description,price,revision FROM trainer_backend.shop_offers WHERE purpose='avatar_costume' ORDER BY id LIMIT 24").fetchall()
        return wire({'player_id':actor.player_id,'items':rows,'payments_available':False,'reason':'costume_assets_unavailable'})
