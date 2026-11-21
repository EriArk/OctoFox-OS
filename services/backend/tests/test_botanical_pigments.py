from concurrent.futures import ThreadPoolExecutor
from uuid import uuid4

import psycopg
from fastapi.testclient import TestClient
from test_accounts import CONFIG, Provider, account
from test_bazaar_rentals import setup
from trainer_backend.app import create_app
from trainer_backend.bazaar import policy, rentals, trading
from trainer_backend.config import Settings


def test_harvest_to_traded_colour(account, postgres, monkeypatch):
    monkeypatch.setattr(policy, 'PAYMENTS_AVAILABLE', True)
    _, bazaar, buyer, seller, bid, place = setup(account, postgres)
    source = '/v1/me/workshop'
    seller_auth = {'Authorization': 'Bearer ' + seller['access_token']}
    buyer_auth = {'Authorization': 'Bearer ' + buyer['access_token']}
    with psycopg.connect(postgres[0]) as db:
        day = db.execute('SELECT floor(extract(epoch FROM now())/86400)::int').fetchone()[0]
    batch = {'plant': 'starbloom', 'day': day, 'player_id': str(seller['player_id'])}
    with TestClient(create_app(Settings(postgres[1], 'test', oauth=CONFIG), provider=Provider())) as client:
        def deposit(payload):
            return client.post(source+'/collect', headers=seller_auth, json=payload)
        def command(action, auth, **args):
            revision = client.get(source, headers=auth).json()['revision']
            return client.post(source+'/'+action, headers=auth,
                               json=dict(operation_id=str(uuid4()), revision=revision, **args))

        assert deposit(dict(batch, day=day+1)).status_code == 422
        assert deposit(dict(batch, day=day-1)).status_code == 422
        assert deposit(dict(batch, player_id=str(buyer['player_id']))).status_code == 409
        with ThreadPoolExecutor(max_workers=2) as pool:
            samples = list(pool.map(lambda _: deposit(batch).json()['item_id'], range(2)))
        assert samples[0] == samples[1]
        assert command('print', seller_auth, plant='starbloom', hours=0).status_code == 409
        revision = client.get(source, headers=seller_auth).json()['revision']
        order = dict(operation_id=str(uuid4()), revision=revision, plant='starbloom', hours=1)
        def start():
            return client.post(source+'/print', headers=seller_auth, json=order)
        job = start().json()['job_id']
        assert start().json()['job_id'] == job
        assert command('print', seller_auth, plant='starbloom', hours=1).status_code == 409
        progress = client.get(source, headers=seller_auth).json()['prints']['pigment.aurora']
        assert progress['quantity'] == 1 and 3590 <= progress['remaining_seconds'] <= 3600
        assert command('collect', seller_auth, job=job).status_code == 409

        with psycopg.connect(postgres[0]) as db:
            db.execute("""UPDATE trainer_backend.workshop_prints SET started_at=started_at-interval '1 hour',
                       ready_at=ready_at-interval '1 hour' WHERE id=%s""", (job,))
        item = command('collect', seller_auth, job=job).json()['item_id']
        assert command('collect', seller_auth, job=job).json()['item_id'] == item
        assert deposit(batch).json()['item_id'] == samples[0]
        inventory = client.get('/v1/me/loot', headers=seller_auth).json()['items']
        assert any(row['id'] == item and row['kind'] == 'pigment' for row in inventory)
        lease = rentals.rent(bazaar, seller['access_token'], uuid4(), bid, place, 1, 100)['receipt']
        trading.hire(bazaar, seller['access_token'], lease['id'], uuid4(), 'Frog', 1, 100)
        listing = trading.create_listing(bazaar, seller['access_token'], lease['id'], item, uuid4(), 1)['listing']
        assert command('activate', seller_auth, color='aurora').status_code == 409
        trading.buy(bazaar, buyer['access_token'], listing['id'], uuid4(), 1, 1)
        assert command('activate', buyer_auth, color='aurora').status_code == 200
        assert 'aurora' in client.get(source, headers=buyer_auth).json()['palette']
        assert command('activate', buyer_auth, color='aurora').status_code == 409
        assert client.get(source, headers=seller_auth).json()['palette'] == []

        sample = deposit(dict(batch, plant='sunbell')).json()['item_id']
        lot = trading.create_listing(bazaar, seller['access_token'], lease['id'], sample, uuid4(), 1)['listing']
        assert command('print', seller_auth, plant='sunbell', hours=1).status_code == 409
        trading.buy(bazaar, buyer['access_token'], lot['id'], uuid4(), 1, 1)
        assert command('print', buyer_auth, plant='sunbell', hours=1).status_code == 200
        assert deposit(dict(batch, plant='sunbell')).json()['item_id'] == sample
        assert command('print', seller_auth, plant='sunbell', hours=1).status_code == 409
