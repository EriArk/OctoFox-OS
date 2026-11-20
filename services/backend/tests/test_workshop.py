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
        assert min(v for parts in first['print_hours'].values() for v in parts.values()) == 1
        assert max(v for parts in first['print_hours'].values() for v in parts.values()) == 24
        assert submit('print', operation(style='traveller', part='top')).status_code == 409
        body = operation(style='traveller', part='top', hours=6)
        with ThreadPoolExecutor(2) as pool:
            results = list(pool.map(lambda _: submit('print', body), range(2)))
        assert [r.status_code for r in results] == [200, 200]
        assert results[0].json() == results[1].json()
        job = results[0].json()['job_id']
        order = get()['prints']['traveller.top']
        assert order['id'] == job and order['quantity'] == 1 and 21590 <= order['remaining_seconds'] <= 21600
        assert client.get(path + '/garments', headers=auth).json()['items'] == []
        assert submit('collect', operation(job=job)).json()['code'] == 'print_in_progress'
        second_login = login(account)
        auth = {'Authorization': 'Bearer ' + second_login['access_token']}
        assert get()['prints']['traveller.top']['id'] == job
        account.provider.subject = '85315942'
        stranger = login(account)
        other_auth = {'Authorization': 'Bearer ' + stranger['access_token']}
        assert client.get(path, headers=other_auth).json()['prints'] == {}
        forbidden = client.post(path+'/collect', headers=other_auth, json={'revision': '0','operation_id': str(uuid4()),'job': job})
        assert forbidden.status_code == 404
        with psycopg.connect(postgres[0]) as conn:
            conn.execute("UPDATE trainer_backend.workshop_prints SET started_at=started_at-interval '6 hours',ready_at=ready_at-interval '6 hours' WHERE id=%s", (job,))
        assert get()['prints']['traveller.top']['remaining_seconds'] == 0
        claim = operation(job=job)
        with ThreadPoolExecutor(2) as pool:
            claims = list(pool.map(lambda _: submit('collect', claim), range(2)))
        assert all(r.status_code == 200 for r in claims) and claims[0].json() == claims[1].json()
        item = claims[0].json()['item_id']
        assert get()['prints'] == {}
        assert submit('collect', operation(job=job)).json()['item_id'] == item
        assert submit('print', operation(style='traveller', part='top', hours=6)).json()['code'] == 'insufficient_cartridges'
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
        job = workshop.print_piece(conn, me, 'traveller', 'top', 6)
    with psycopg.connect(postgres[0]) as conn:
        conn.execute("UPDATE trainer_backend.workshop_prints SET started_at=started_at-interval '1 day',ready_at=ready_at-interval '1 day' WHERE id=%s", (job,))
    with account.db.transaction() as conn:
        piece = workshop.collect(conn, me, job)
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


def test_parallel_prints_keep_each_deadline_and_material_charge(account, postgres):
    player = login(account)['player_id']
    with account.db.transaction() as conn:
        for style in ('merchant', 'mage'):
            workshop.write(conn, player, 'blueprint', {'sku': style})
        for sku, units in [('Cotton', 11), ('Aluminium', 2)]:
            workshop.write(conn, player, 'material', {'sku': sku, 'units': units})
        short = workshop.print_piece(conn, player, 'merchant', 'hat', 1)
        second = workshop.print_piece(conn, player, 'merchant', 'hat', 1)
        long = workshop.print_piece(conn, player, 'mage', 'top', 24)
        jobs = workshop.snapshot(conn, player)['prints']
        assert jobs['merchant.hat']['quantity'] == 2 and jobs['mage.top']['quantity'] == 1
        assert 3590 <= jobs['merchant.hat']['remaining_seconds'] <= 3600
        assert 86390 <= jobs['mage.top']['remaining_seconds'] <= 86400
        assert not workshop.stored(conn, player, 'material', 'Cotton')
    with psycopg.connect(postgres[0]) as conn:
        conn.execute("UPDATE trainer_backend.workshop_prints SET started_at=started_at-interval '1 hour',ready_at=ready_at-interval '1 hour' WHERE id=%s", (short,))
    with account.db.transaction() as conn:
        workshop.collect(conn, player, short)
        jobs = workshop.snapshot(conn, player)['prints']
        assert jobs['merchant.hat']['id'] == second and jobs['merchant.hat']['quantity'] == 1
        assert jobs['mage.top']['id'] == long
