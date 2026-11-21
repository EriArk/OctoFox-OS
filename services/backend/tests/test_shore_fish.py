from uuid import uuid4

import psycopg
from fastapi.testclient import TestClient
from trainer_backend.app import create_app
from trainer_backend.config import Settings
from test_accounts import CONFIG, Provider, account, login


def test_land_fish_replay_and_inventory(account, postgres):
    user = login(account)
    headers = {'Authorization': 'Bearer ' + user['access_token']}
    route = '/v1/me/workshop/fish'
    item = {'id': str(uuid4()), 'species': 'ribbon', 'site': 3}
    with TestClient(create_app(Settings(postgres[1], 'test', oauth=CONFIG), provider=Provider())) as client:
        assert client.post(route, json=item).status_code == 401
        assert client.post(route, headers=headers, json=dict(item, site=1)).status_code == 422
        assert client.post(route, headers=headers, json=dict(item, price=10)).status_code == 422
        def send(fish):
            return client.post(route, headers=headers, json=fish)
        assert send(item).json()['item_id'] == item['id']
        assert send(item).json()['item_id'] == item['id']
        assert send(dict(item, species='glassfin')).status_code == 409
        stock = client.get('/v1/me/loot', headers=headers).json()
        assert stock['total'] == 1
        assert stock['items'][0]['presentation']['title'] == 'Ribbon ray'
        assert stock['items'][0]['id'] == item['id']
        # Recovery after the item has left the livewell or entered a market listing.
        with psycopg.connect(postgres[0]) as conn:
            conn.execute("UPDATE trainer_backend.loot_items SET state='listed' WHERE id=%s", (item['id'],))
        assert send(item).status_code == 200
        assert client.get('/v1/me/loot', headers=headers).json()['items'][0]['state'] == 'listed'
        for _ in range(23):
            assert send(dict(item, id=str(uuid4()))).status_code == 200
        assert send(dict(item, id=str(uuid4()))).status_code == 429
        assert send(item).status_code == 200


def test_buyer_can_display_original_fish(account, postgres, monkeypatch):
    from trainer_backend.bazaar import policy, rentals, trading
    from test_bazaar_rentals import setup
    monkeypatch.setattr(policy, 'PAYMENTS_AVAILABLE', True)
    _, bazaar, buyer, seller, bid, pid = setup(account, postgres)
    def auth(player):
        return {'Authorization': 'Bearer ' + player['access_token']}
    item = {'id': str(uuid4()), 'species': 'loach', 'site': 1}
    root = '/v1/me/workshop/'
    with TestClient(create_app(Settings(postgres[1], 'test', oauth=CONFIG), provider=Provider())) as client:
        def place(who):
            return client.post(root+'fishdisplay', headers=auth(who), json={'id': item['id'], 'display': True})
        def stock(who):
            return client.get(root+'fishstock', headers=auth(who)).json()
        assert client.post(root+'fish', headers=auth(seller), json=item).status_code == 200
        assert place(buyer).status_code == 409
        assert place(seller).status_code == 200
        assert place(seller).status_code == 200
        assert stock(seller)['tank'] == [item] and not stock(seller)['items']
        rent = rentals.rent(bazaar, seller['access_token'], uuid4(), bid, pid, 1, 100)['receipt']
        trading.hire(bazaar, seller['access_token'], rent['id'], uuid4(), 'Frog', 1, 100)
        from uuid import UUID
        listing = trading.create_listing(bazaar, seller['access_token'], rent['id'], UUID(item['id']), uuid4(), 1)['listing']
        assert not stock(seller)['tank'] and place(seller).status_code == 409
        trading.buy(bazaar, buyer['access_token'], listing['id'], uuid4(), 1, 1)
        assert stock(buyer)['items'] == [item]
        assert place(buyer).status_code == 200 and stock(buyer)['tank'] == [item]
        # A stale transport acknowledgement cannot reissue the sold instance to the angler.
        assert client.post(root+'fish', headers=auth(seller), json=item).status_code == 200
        assert not stock(seller)['items'] and not stock(seller)['tank']
