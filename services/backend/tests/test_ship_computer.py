from uuid import uuid4

import psycopg
from fastapi.testclient import TestClient
from test_accounts import CONFIG, Provider, account, login
from trainer_backend.app import create_app
from trainer_backend.config import Settings
from trainer_backend.economy import workshop


def test_supply_terminal_and_parallel_refining(account, postgres, monkeypatch):
    user = login(account)
    player = user['player_id']
    path = '/v1/me/workshop'
    auth = {'Authorization': 'Bearer ' + user['access_token']}
    with TestClient(create_app(Settings(postgres[1], 'test', oauth=CONFIG), provider=Provider())) as client:
        def snapshot():
            return client.get(path, headers=auth).json()

        def args(**fields):
            return dict(operation_id=str(uuid4()), revision=snapshot()['revision'], **fields)

        def post(action, payload):
            return client.post(path+'/'+action, headers=auth, json=payload)

        def buy(key, price):
            return args(offer=key, price=price, player_id=str(player))

        assert post('buy', buy('case-plan', 1)).json()['code'] == 'offer_changed'
        assert post('buy', buy('case-plan', 30)).json()['code'] == 'insufficient_sparks'
        with psycopg.connect(postgres[0]) as db:
            workshop.lock_account(db, player)
            db.execute('UPDATE trainer_backend.progression_accounts SET balance=1000 WHERE player_id=%s', (player,))
            workshop.write(db, player, 'material', {'sku': 'Plastic', 'units': 1})
            for _ in range(2):
                workshop.write(db, player, 'ore', {'sku': 'bauxite'})
        order = buy('case-plan',30)
        plan = post('buy', order).json()['item_id']
        assert post('buy', order).json()['item_id'] == plan
        assert snapshot()['sparks'] == 970
        assert post('buy', dict(buy('case',12),player_id=str(uuid4()))).status_code == 409
        first = post('print', args(ore='bauxite',hours=2)).json()['job_id']
        assert post('print',args(ore='bauxite',hours=2)).json()['code']=='extra_cartridge_required'
        assert post('print',args(ore='bauxite',hours=2,extra_case=True)).json()['code']=='insufficient_cartridges'
        case = post('print', args(casing='empty',hours=1)).json()['job_id']
        with psycopg.connect(postgres[0]) as db:
            db.execute("""UPDATE trainer_backend.workshop_prints SET started_at=started_at-interval '1 hour',
                       ready_at=ready_at-interval '1 hour' WHERE id=%s""",(case,))
        assert post('collect',args(job=case)).status_code==200
        second=post('print',args(ore='bauxite',hours=2,extra_case=True)).json()['job_id']
        assert first!=second and snapshot()['prints']['material.Aluminium']['quantity']==2
        assert not any(row['sku']=='Empty' for row in snapshot()['stock'])
        store = '/v1/bazaar-worlds/festival/store'
        assert set(snapshot()['supplies']) == {'case-plan', 'traveller-plan', 'merchant-plan'}
        assert post('buy', buy('case-plan', 30)).json()['code'] == 'blueprint_already_owned'
        assert post('buy', buy('cap',35)).json()['code'] == 'offer_changed'
        assert all(row['kind'] != 'blueprint' for row in client.get(store,headers=auth).json()['items'])
        assert client.post(store,headers=auth,json=buy('cap',35)).json()['code'] == 'bazaar_under_development'
        monkeypatch.setattr('trainer_backend.bazaar.policy.PAYMENTS_AVAILABLE', True)
        assert client.post(store,headers=auth,json=buy('case-plan',30)).json()['code'] == 'offer_changed'
        cap_order = buy('cap',35)
        cap = client.post(store,headers=auth,json=cap_order).json()
        assert cap['operation_id'] == cap_order['operation_id']
        assert client.post(store,headers=auth,json=cap_order).json()['item_id'] == cap['item_id']
        assert client.get(path+'/garments',headers=auth).json()['items'][0]['sku']=='merchant.hat'
        assert client.post(store,headers=auth,json=buy('boost-kit',300)).status_code==200
        fitted=args(module='capacitor',player_id=str(player))
        assert post('install',fitted).status_code==200
        assert post('install',fitted).status_code==200
        assert post('install',args(module='capacitor',player_id=str(player))).json()['code']=='already_installed'
        assert snapshot()['installed']==['capacitor'] and snapshot()['sparks']==635
        history = client.get('/v1/me/progression', headers=auth).json()['history']
        assert sum(row['sparks'] for row in history if row['source']=='shop.purchase') == -365
        with psycopg.connect(postgres[0]) as db:
            assert db.execute("SELECT sum(sparks) FROM trainer_backend.reward_ledger WHERE supply_item IS NOT NULL AND player_id=%s",(player,)).fetchone()[0]==-365
