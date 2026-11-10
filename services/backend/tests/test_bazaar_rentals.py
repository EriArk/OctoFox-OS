from concurrent.futures import ThreadPoolExecutor
from datetime import timedelta
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
from test_bazaar import prepared,create,DETAILS


def setup(account,postgres,price=100):
    shop,owner,service=prepared(account,postgres)
    bid=create(shop,owner['access_token'])['bazaar']['id'];pid=uuid4()
    # Existing provisioned place only, in disposable fixture DB. No free live stalls.
    with psycopg.connect(postgres[0]) as conn:
        conn.execute('INSERT INTO trainer_backend.bazaar_places(id,bazaar_id,name,weekly_price) VALUES(%s,%s,%s,%s)',(pid,bid,'Lantern stall',price))
    account.provider.subject='998877';tenant=login(account)
    grant_test_sparks(postgres[0],tenant['player_id'],account.provider.subject,1000,'Isolated rental test',uuid4())
    return shop,service,owner,tenant,bid,pid


def test_rent_transfers_once_and_replays_after_price_and_access_change(account,postgres):
    shop,s,owner,tenant,bid,pid=setup(account,postgres);token=tenant['access_token'];op=uuid4()
    first=rentals.rent(s,token,op,bid,pid,1,100)['receipt']
    assert first['expires_at']-first['started_at']==timedelta(days=7)
    assert shop.progression.snapshot(token)['balance']==900
    assert shop.progression.snapshot(owner['access_token'])['balance']==5100
    rentals.price(s,owner['access_token'],bid,pid,2,200)
    s.block(owner['access_token'],bid,tenant['player_id'],True,1)
    assert rentals.rent(s,token,op,bid,pid,1,100)['receipt']['id']==first['id']
    assert rentals.receipt(s,token,op)['receipt']['id']==first['id']
    with pytest.raises(AuthError,match='identity_conflict'):rentals.rent(s,token,op,bid,pid,3,200)
    with pytest.raises(AuthError,match='not_found'):rentals.receipt(s,owner['access_token'],op)
    rows=rentals.places(s,owner['access_token'],bid)['items'];assert rows[0]['tenant_id']==tenant['player_id'] and rows[0]['expires_at']==first['expires_at']
    with account.db.transaction() as conn:
        rows=conn.execute('SELECT source,sparks FROM trainer_backend.reward_ledger WHERE rental_id=%s',(first['id'],)).fetchall()
        assert len(rows)==2 and sum(r['sparks'] for r in rows)==0


def test_simultaneous_tenants_and_repeated_payment_cannot_double_charge(account,postgres):
    shop,s,owner,tenant,bid,pid=setup(account,postgres);op=uuid4()
    def attempt(_):return rentals.rent(s,tenant['access_token'],op,bid,pid,1,100)['receipt']['id']
    with ThreadPoolExecutor(2) as pool:assert len(set(pool.map(attempt,range(2))))==1
    assert shop.progression.snapshot(tenant['access_token'])['balance']==900
    # A fresh place and two different tenants race for the same offer.
    second=uuid4()
    with psycopg.connect(postgres[0]) as conn:conn.execute('INSERT INTO trainer_backend.bazaar_places(id,bazaar_id,name,weekly_price) VALUES(%s,%s,%s,100)',(second,bid,'Second'))
    account.provider.subject='998878';other=login(account)
    grant_test_sparks(postgres[0],other['player_id'],account.provider.subject,1000,'Isolated competing tenant',uuid4())
    def race(token):
        try:rentals.rent(s,token,uuid4(),bid,second,1,100);return 'rented'
        except AuthError as error:return error.code
    with ThreadPoolExecutor(2) as pool:assert sorted(pool.map(race,[tenant['access_token'],other['access_token']]))==['place_changed','rented']
    assert shop.progression.snapshot(tenant['access_token'])['balance']+shop.progression.snapshot(other['access_token'])['balance']==1800


def test_expiry_releases_place_without_inventory_or_ledger_deletion(account,postgres):
    shop,s,owner,tenant,bid,pid=setup(account,postgres);token=tenant['access_token'];op=uuid4()
    shop.purchase(token,uuid4(),'profile.aurora',1,250)
    old=rentals.rent(s,token,op,bid,pid,1,100)['receipt']
    assert not rentals.places(s,token,bid)['items'][0]['rentable']
    with psycopg.connect(postgres[0]) as conn:
        conn.execute("UPDATE trainer_backend.bazaar_rentals SET started_at=started_at-interval '8 days',expires_at=expires_at-interval '8 days' WHERE id=%s",(old['id'],))
    row=rentals.places(s,token,bid)['items'][0];assert row['rentable'] and row['tenant_id'] is None
    assert rentals.rent(s,token,op,bid,pid,1,100)['receipt']['id']==old['id']
    new=rentals.rent(s,token,uuid4(),bid,pid,2,100)['receipt'];assert new['id']!=old['id']
    assert len(shop.snapshot(token)['items'])==1
    assert shop.progression.snapshot(token)['balance']==550
    with pytest.raises(psycopg.errors.InsufficientPrivilege):
        with account.db.transaction() as conn:conn.execute('DELETE FROM trainer_backend.bazaar_rentals')
    with pytest.raises(psycopg.errors.InsufficientPrivilege):
        with account.db.transaction() as conn:conn.execute('INSERT INTO trainer_backend.bazaar_places(id,bazaar_id,name) VALUES(%s,%s,%s)',(uuid4(),bid,'Minted'))


def test_failed_transfer_rolls_back_every_effect(account,postgres,monkeypatch):
    shop,s,owner,tenant,bid,pid=setup(account,postgres)
    def fail(*args):raise RuntimeError('outbox unavailable')
    monkeypatch.setattr(rentals,'publish',fail)
    with pytest.raises(RuntimeError):rentals.rent(s,tenant['access_token'],uuid4(),bid,pid,1,100)
    assert shop.progression.snapshot(tenant['access_token'])['balance']==1000
    assert shop.progression.snapshot(owner['access_token'])['balance']==5000
    assert rentals.places(s,tenant['access_token'],bid)['items'][0]['revision']==1
    with account.db.transaction() as conn:
        assert conn.execute('SELECT count(*) n FROM trainer_backend.bazaar_rentals').fetchone()['n']==0
        assert conn.execute('SELECT count(*) n FROM trainer_backend.reward_ledger WHERE rental_id IS NOT NULL').fetchone()['n']==0


def test_owner_terms_access_balance_and_strict_http(account,postgres):
    shop,s,owner,tenant,bid,pid=setup(account,postgres,price=None);token=tenant['access_token'];own=owner['access_token']
    assert not rentals.places(s,token,bid)['items'][0]['rentable']
    with pytest.raises(AuthError,match='not_found'):rentals.price(s,token,bid,pid,1,100)
    rentals.price(s,own,bid,pid,1,1100)
    with pytest.raises(AuthError,match='place_changed'):rentals.price(s,own,bid,pid,1,100)
    with pytest.raises(AuthError,match='insufficient'):rentals.rent(s,token,uuid4(),bid,pid,2,1100)
    with pytest.raises(AuthError,match='own_place'):rentals.rent(s,own,uuid4(),bid,pid,2,1100)
    s.block(own,bid,tenant['player_id'],True,1)
    with pytest.raises(AuthError,match='access_denied'):rentals.rent(s,token,uuid4(),bid,pid,2,1100)
    s.block(own,bid,tenant['player_id'],False,2)
    s.update(own,bid,3,{**DETAILS,'access':'closed'})
    with pytest.raises(AuthError,match='access_denied'):rentals.rent(s,token,uuid4(),bid,pid,2,1100)
    auth={'Authorization':'Bearer '+own};path='/v1/me/bazaars/'+str(bid)+'/places/'+str(pid)
    with TestClient(create_app(Settings(postgres[1],'test',oauth=CONFIG),provider=Provider())) as client:
        assert client.get('/v1/bazaars/'+str(bid)+'/places').status_code==401
        for extra in [{'weekly_price':0},{'weekly_price':True},{'weekly_price':1.5},{'host_id':str(tenant['player_id'])}]:
            assert client.put(path,headers=auth,json={'revision':'2','weekly_price':100,**extra}).status_code==422
        assert client.put(path,headers=auth,json={'revision':'2','weekly_price':100}).status_code==200
        assert client.get('/v1/bazaars/'+str(bid)+'/places',headers=auth).json()['items'][0]['revision']=='3'
        body={'operation_id':str(uuid4()),'revision':'3','expected_price':100,'days':14}
        assert client.post('/v1/bazaars/'+str(bid)+'/places/'+str(pid)+'/rent',headers=auth,json=body).status_code==422


def test_rent_and_shop_share_spending_lock(account,postgres):
    shop,s,owner,tenant,bid,pid=setup(account,postgres,800);token=tenant['access_token']
    def attempt(kind):
        try:
            if kind=='rent':rentals.rent(s,token,uuid4(),bid,pid,1,800)
            else:shop.purchase(token,uuid4(),'profile.aurora',1,250)
            return 'paid'
        except AuthError as error:return error.code
    with ThreadPoolExecutor(2) as pool:assert sorted(pool.map(attempt,['rent','shop']))==['insufficient_sparks','paid']
    assert shop.progression.snapshot(token)['balance'] in (200,750)


def test_places_page_and_hidden_bazaar_are_bounded(account,postgres):
    shop,s,owner,tenant,bid,pid=setup(account,postgres)
    with psycopg.connect(postgres[0]) as conn:
        for _ in range(25):conn.execute('INSERT INTO trainer_backend.bazaar_places(id,bazaar_id,name) VALUES(%s,%s,%s)',(uuid4(),bid,'Other place'))
    first=rentals.places(s,tenant['access_token'],bid);assert len(first['items'])==24 and first['next']
    second=rentals.places(s,tenant['access_token'],bid,first['next']);assert len(second['items'])==2 and second['next'] is None
    assert len({r['id'] for r in first['items']+second['items']})==26
    s.update(owner['access_token'],bid,1,{**DETAILS,'listed':False})
    with pytest.raises(AuthError,match='not_found'):rentals.places(s,tenant['access_token'],bid)
    assert rentals.places(s,owner['access_token'],bid)['owned']
