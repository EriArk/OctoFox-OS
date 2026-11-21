from uuid import uuid4

import psycopg
import pytest

from test_accounts import account, login
from test_bazaar import create, development_payments, prepared
from trainer_backend.accounts.provider import AuthError
from trainer_backend.bazaar import festival, rentals, trading, visits
from trainer_backend.economy.maintenance import grant_test_sparks
from trainer_backend.inventory import read_inventory


def test_plush_trade_and_host_handover(account, postgres):
    shop, mika, service = prepared(account, postgres)
    owner = mika['access_token']
    bazaar = create(shop, owner)['bazaar']['id']
    with psycopg.connect(postgres[0]) as db:
        db.execute("INSERT INTO trainer_backend.bazaar_worlds VALUES ('mika-island',%s)", (bazaar,))
    account.provider.subject = '774411'
    ren = login(account)
    tenant = ren['access_token']
    grant_test_sparks(postgres[0], ren['player_id'], account.provider.subject, 1000, 'Island rehearsal', uuid4())
    def island(token):
        return trading.world(service, token, 'mika-island')
    assert island(owner)['stall_offer']['price'] == 500
    assert island(tenant)['stall_offer'] is None
    buy = uuid4()
    for _ in range(2):
        shop.purchase(owner, buy, 'bazaar.stall', 1, 500, first_island_stall=True)
    with pytest.raises(AuthError, match='place_changed'):
        shop.purchase(owner, uuid4(), 'bazaar.stall', 1, 500, first_island_stall=True)
    place, = island(owner)['places']
    price = rentals.price(service, owner, bazaar, place['id'], place['revision'], 110)['place']
    lease = rentals.rent(service, tenant, uuid4(), bazaar, place['id'], price['revision'], 110)['receipt']
    trading.hire(service, tenant, lease['id'], uuid4(), 'Frog', 1, 100)
    a,b = uuid4(), uuid4()
    assert visits.update(service, owner, a)['host'] == a
    assert visits.update(service, tenant, b)['host'] == a
    code = '2-one-two-three-four-five-six-seven-eight'
    assert visits.update(service, owner, a, offers={b:code})['code'] is None
    assert visits.update(service, tenant, b)['code'] == code
    visits.update(service, owner, a, leave=True)
    assert visits.update(service, tenant, b)['host'] == b
    with pytest.raises(AuthError, match='bazaar_not_found'):
        rentals.price(service, tenant, bazaar, place['id'], price['revision'], 1)
    ticket = festival.enter(service, tenant, 'gallery', uuid4(), 10)['round']['id']
    for i, (x,y) in enumerate([(-142,94),(0,94),(142,94)]):
        festival.attempt(service, tenant, 'gallery', ticket, i, x, y)
    op = uuid4()
    item = trading.create_listing(service, tenant, lease['id'], ticket, op, 30)['listing']
    trading.reprice(service, tenant, item['id'], item['revision'], 25)
    assert trading.create_listing(service, tenant, lease['id'], ticket, op, 30)['listing']['price'] == 30
    assert island(owner)['places'][0]['showcase'][0]['title'] == 'Honey Bear'
    with pytest.raises(AuthError, match='listing_changed|offer_changed'):
        trading.buy(service, owner, item['id'], uuid4(), 1, 30)
    trading.withdraw(service, tenant, item['id'], 2)
    assert not island(owner)['places'][0]['showcase']
    item = trading.create_listing(service, tenant, lease['id'], ticket, uuid4(), 25)['listing']
    visits.update(service, tenant, b, leave=True)
    balance = shop.progression.snapshot(tenant)['balance']
    trading.buy(service, owner, item['id'], uuid4(), 1, 25)
    assert shop.progression.snapshot(tenant)['balance'] == balance + 25
    assert ticket in [i['id'] for i in read_inventory(account, owner)['items']]
    assert island(tenant)['places'][0]['recent_sale'] == dict(title='Honey Bear', price=25)
    assert 'recent_sale' not in island(owner)['places'][0]
    assert festival.status(service, tenant, 'gallery')['won'] == ['Honey Bear']
    assert festival.status(service, owner, 'gallery')['won'] == []
