from uuid import uuid4
from concurrent.futures import ThreadPoolExecutor
import psycopg
import pytest
from fastapi.testclient import TestClient
from trainer_backend.app import create_app
from trainer_backend.config import Settings
from trainer_backend.inventory import read_inventory
from trainer_backend.economy import workshop
from trainer_backend.accounts.provider import AuthError
from trainer_backend.bazaar import trading, rentals
from test_accounts import account, login, CONFIG, Provider


def test_workshop_loop_through_http(account, postgres):
    user = login(account)
    token = user['access_token']
    player = user['player_id']
    auth = {'Authorization': 'Bearer ' + token}
    with TestClient(create_app(Settings(postgres[1], 'test', oauth=CONFIG), provider=Provider())) as client:
        path = '/v1/me/workshop'
        def get():
            return client.get(path, headers=auth).json()
        def operation(**data):
            return dict(operation_id=str(uuid4()), revision=get()['revision'], **data)
        def submit(name, data):
            return client.post(path + '/' + name, headers=auth, json=data)
        assert client.get(path).status_code == 401
        assert get()['stock'] == []
        session = {'session': str(uuid4())}
        assert submit('play', session).status_code == 200
        assert get()['stock'] == []
        with psycopg.connect(postgres[0]) as conn:
            conn.execute("UPDATE trainer_backend.workshop_play SET started_at=clock_timestamp()-interval '6 minutes' WHERE player_id=%s", (player,))
        assert submit('play', session).status_code == 200
        first = get()
        history = client.get('/v1/me/prizes?format=2', headers=auth).json()
        assert history['items'][0]['kind'] == 'workshop'
        assert client.get('/v1/me/prizes', headers=auth).json()['items'][0]['kind'] == 'clothing'
        assert submit('play', session).status_code == 200 and get() == first
        body = operation(style='traveller', part='top')
        with ThreadPoolExecutor(2) as pool:
            results = list(pool.map(lambda _: submit('print', body), range(2)))
        assert [r.status_code for r in results] == [200, 200]
        assert results[0].json() == results[1].json()
        item = results[0].json()['item_id']
        assert submit('print', operation(style='traveller', part='top')).json()['code'] == 'insufficient_cartridges'
        locked = operation(item=item, channel='primary', color='sea-glass')
        assert submit('paint', locked).json()['code'] == 'color_locked'
        unlock = operation(color='sea-glass')
        assert submit('activate', unlock).status_code == 200
        assert submit('activate', unlock).status_code == 200
        assert submit('paint', locked).json()['code'] == 'inventory_changed'
        for channel in ('primary', 'trim'):
            assert submit('paint', operation(item=item, channel=channel, color='sea-glass')).status_code == 200
        assert get()['palette'] == ['sea-glass']
        piece = client.get(path + '/garments', headers=auth).json()['items'][0]
        assert piece['colors'] == {'primary': 'sea-glass', 'trim': 'sea-glass'}
        kinds = sorted(r['kind'] for r in read_inventory(account, token)['items'])
        assert kinds == ['blueprint', 'garment']
        account.provider.subject = '12348765'
        other = login(account)
        auth = {'Authorization': 'Bearer ' + other['access_token']}
        assert get()['palette'] == [] and get()['stock'] == []
        assert submit('paint', operation(item=item, channel='primary', color='original')).status_code == 409


def test_traded_lots_and_painted_garment_keep_identity(account, postgres, monkeypatch):
    from test_bazaar_rentals import setup
    from trainer_backend.bazaar import policy
    monkeypatch.setattr(policy, 'PAYMENTS_AVAILABLE', True)
    _, bazaar, buyer, seller, bid, pid = setup(account, postgres)
    me, them = seller['player_id'], buyer['player_id']
    with account.db.transaction() as conn:
        workshop.reward(conn, me, 'fixture.1')
        workshop.reward(conn, me, 'fixture.2')
        piece = workshop.print_piece(conn, me, 'traveller', 'top')
        workshop.activate(conn, me, 'sea-glass')
        workshop.paint(conn, me, piece, 'trim', 'sea-glass')
    rent = rentals.rent(bazaar, seller['access_token'], uuid4(), bid, pid, 1, 100)['receipt']
    trading.hire(bazaar, seller['access_token'], rent['id'], uuid4(), 'Frog', 1, 100)
    rows = read_inventory(account, seller['access_token'])['items']
    assert {r['kind'] for r in rows} == {'blueprint', 'pigment', 'material', 'garment'}
    for row in rows:
        listing = trading.create_listing(bazaar, seller['access_token'], rent['id'], row['id'], uuid4(), 1)['listing']
        if row['kind'] == 'garment':
            with pytest.raises(AuthError, match='garment_unavailable'), account.db.transaction() as conn:
                workshop.paint(conn, me, piece, 'trim', 'original')
        trading.buy(bazaar, buyer['access_token'], listing['id'], uuid4(), 1, 1)
    with account.db.transaction() as conn:
        assert workshop.snapshot(conn, me)['palette'] == ['sea-glass']
        assert workshop.snapshot(conn, them)['palette'] == []
        assert workshop.stored(conn, them, 'garment', 'traveller.top')['payload']['colors'] == {'trim': 'sea-glass'}
        workshop.activate(conn, them, 'rose-gold')
    assert read_inventory(account, seller['access_token'])['total'] == 0


def test_verified_first_achievement_and_replay(account):
    from test_progression import linked, release
    service, user, proof = linked(account)
    token = user['access_token']
    service.sync(token, 'k' * 32, [1])
    before = read_inventory(account, token)
    assert before['total'] > 0
    assert {'blueprint', 'material', 'pigment'} == {r['kind'] for r in before['items']}
    with account.db.transaction() as conn:
        first = conn.execute("SELECT event FROM trainer_backend.workshop_rewards WHERE player_id=%s AND ordinal=1",
                             (user['player_id'],)).fetchone()
    assert first['event'].startswith('ra.achievement:')
    release(account.db)
    service.sync(token, 'k' * 32, [1])
    assert read_inventory(account, token) == before
