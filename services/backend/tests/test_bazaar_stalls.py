from concurrent.futures import ThreadPoolExecutor
from uuid import uuid4
import psycopg
import pytest
from fastapi.testclient import TestClient
from trainer_backend.app import create_app
from trainer_backend.config import Settings
from trainer_backend.accounts.provider import AuthError
from trainer_backend.bazaar import rentals
from trainer_backend.economy.maintenance import grant_test_sparks
from test_accounts import account,login,CONFIG,Provider
from test_bazaar import prepared,buy,DETAILS


def stall(shop,token,op=None):
    return shop.purchase(token,op or uuid4(),'bazaar.stall',1,500)


def test_stall_requires_created_bazaar_then_pays_once_and_can_rent(account,postgres):
    shop,owner,s=prepared(account,postgres);token=owner['access_token']
    with pytest.raises(AuthError,match='bazaar_required'):stall(shop,token)
    buy(shop,token)
    with pytest.raises(AuthError,match='bazaar_required'):stall(shop,token)
    bid=s.create(token,DETAILS)['bazaar']['id'];op=uuid4()
    result=stall(shop,token,op);place=result['purchased_place']
    assert place['purchase_id']==result['receipt']['id'] and place['bazaar_id']==bid
    assert place['weekly_price'] is None and len(rentals.places(s,token,bid)['items'])==1
    assert stall(shop,token,op)['purchased_place']['id']==place['id']
    assert shop.snapshot(login(account)['access_token'],op)['purchased_place']['id']==place['id']
    assert shop.progression.snapshot(token)['balance']==4500
    second=stall(shop,token)['purchased_place'];assert second['id']!=place['id'] and second['name']!=place['name']
    assert shop.progression.snapshot(token)['balance']==4000
    rentals.price(s,token,bid,place['id'],1,100)
    account.provider.subject='98989';tenant=login(account)
    grant_test_sparks(postgres[0],tenant['player_id'],account.provider.subject,100,'Isolated purchased stall rent',uuid4())
    rentals.rent(s,tenant['access_token'],uuid4(),bid,place['id'],2,100)
    assert shop.progression.snapshot(token)['balance']==4100
    assert shop.progression.snapshot(tenant['access_token'])['balance']==0
    assert shop.snapshot(token,op)['purchased_place']['purchase_id']==place['purchase_id']


def test_concurrent_replays_create_one_stall_and_new_purchases_do_not_overspend(account,postgres):
    shop,owner,s=prepared(account,postgres);token=owner['access_token'];buy(shop,token);s.create(token,DETAILS);op=uuid4()
    with ThreadPoolExecutor(2) as pool:
        results=list(pool.map(lambda _:stall(shop,token,op)['purchased_place']['id'],range(2)))
    assert len(set(results))==1 and shop.progression.snapshot(token)['balance']==4500
    # Spend the remaining fixture budget, then race the last 500 Sparks.
    for _ in range(8):stall(shop,token)
    def attempt(_):
        try:stall(shop,token);return 'paid'
        except AuthError as error:return error.code
    with ThreadPoolExecutor(2) as pool:assert sorted(pool.map(attempt,range(2)))==['insufficient_sparks','paid']
    assert shop.progression.snapshot(token)['balance']==0
    with account.db.transaction() as conn:
        assert conn.execute('SELECT count(*) n FROM trainer_backend.bazaar_places').fetchone()['n']==10
        assert conn.execute("SELECT count(*) n FROM trainer_backend.owned_items WHERE offer_id='bazaar.stall'").fetchone()['n']==0
        assert not conn.execute('SELECT * FROM trainer_backend.provision_bazaar_stall(%s)',(uuid4(),)).fetchall()


def test_failed_stall_creation_rolls_back_charge_and_receipt(account,postgres,monkeypatch):
    shop,owner,s=prepared(account,postgres);token=owner['access_token'];buy(shop,token);bid=s.create(token,DETAILS)['bazaar']['id']
    import trainer_backend.economy.shop as module
    def fail(*args):raise RuntimeError('outbox unavailable')
    monkeypatch.setattr(module,'publish',fail)
    with pytest.raises(RuntimeError):stall(shop,token)
    assert shop.progression.snapshot(token)['balance']==5000 and not rentals.places(s,token,bid)['items']
    with account.db.transaction() as conn:
        assert conn.execute("SELECT count(*) n FROM trainer_backend.purchases WHERE offer_id='bazaar.stall'").fetchone()['n']==0


def test_stall_http_price_replay_identity_and_restricted_provisioning(account,postgres):
    shop,owner,s=prepared(account,postgres);token=owner['access_token'];buy(shop,token);s.create(token,DETAILS)
    auth={'Authorization':'Bearer '+token}
    with TestClient(create_app(Settings(postgres[1],'test',oauth=CONFIG),provider=Provider())) as client:
        body={'operation_id':str(uuid4()),'offer_id':'bazaar.stall','offer_revision':1,'expected_price':500}
        assert client.post('/v1/me/purchases',headers=auth,json={**body,'owner_id':str(owner['player_id'])}).status_code==422
        assert client.post('/v1/me/purchases',headers=auth,json={**body,'expected_price':1}).status_code==409
        result=client.post('/v1/me/purchases',headers=auth,json=body);assert result.status_code==200
        place=result.json()['purchased_place'];assert place['revision']=='1' and place['weekly_price'] is None
        assert client.get('/v1/me/purchases/'+body['operation_id'],headers=auth).json()['purchased_place']==place
        assert client.post('/v1/me/purchases',headers=auth,json={**body,'expected_price':501}).json()['code']=='purchase_identity_conflict'
    with pytest.raises(psycopg.errors.InsufficientPrivilege):
        with account.db.transaction() as conn:conn.execute('UPDATE trainer_backend.bazaar_places SET purchase_id=NULL')
    # Other permanent licenses still cannot be bought twice.
    with pytest.raises(AuthError,match='already_owned'):buy(shop,token)
