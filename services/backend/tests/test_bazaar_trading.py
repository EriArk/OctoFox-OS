from concurrent.futures import ThreadPoolExecutor
from uuid import UUID,uuid4
import psycopg
import pytest
from fastapi.testclient import TestClient
from trainer_backend.app import create_app
from trainer_backend.config import Settings
from trainer_backend.accounts.provider import AuthError
from trainer_backend.bazaar import rentals,trading,policy
from trainer_backend.economy.maintenance import grant_test_sparks
from trainer_backend.inventory import read_inventory
from test_accounts import account,login,CONFIG,Provider
from test_bazaar import development_payments
from test_bazaar_rentals import setup
from test_inventory import seed


def market(account,postgres):
    shop,s,owner,seller,bid,pid=setup(account,postgres)
    rent=rentals.rent(s,seller['access_token'],uuid4(),bid,pid,1,100)['receipt']
    trading.hire(s,seller['access_token'],rent['id'],uuid4(),'Frog',1,100)
    item=UUID(seed(postgres,seller['player_id'])[0])
    listing=trading.create_listing(s,seller['access_token'],rent['id'],item,uuid4(),250)['listing']
    account.provider.subject='774411';buyer=login(account)
    grant_test_sparks(postgres[0],buyer['player_id'],account.provider.subject,1000,'Isolated trading test',uuid4())
    return shop,s,owner,seller,buyer,rent,listing


def test_purchase_atomic_ownership_and_private_idempotent_recovery(account,postgres,monkeypatch):
    shop,s,owner,seller,buyer,rent,listing=market(account,postgres)
    op=uuid4();token=buyer['access_token']
    before=read_inventory(account,seller['access_token'])
    result=trading.buy(s,token,listing['id'],op,1,250)['receipt']
    assert shop.progression.snapshot(token)['balance']==750
    assert shop.progression.snapshot(seller['access_token'])['balance']==1050
    assert read_inventory(account,token)['items'][0]['id']==listing['item_id']
    assert read_inventory(account,seller['access_token'])['items']==[]
    assert read_inventory(account,seller['access_token'])['revision']!=before['revision']
    monkeypatch.setattr(policy,'PAYMENTS_AVAILABLE',False)
    assert trading.buy(s,token,listing['id'],op,1,250)['receipt']==result
    assert trading.receipt(s,token,op)['receipt']==result
    with pytest.raises(AuthError,match='identity_conflict'):trading.buy(s,token,listing['id'],op,1,251)
    with pytest.raises(AuthError,match='not_found'):trading.receipt(s,seller['access_token'],op)
    with s.db.transaction() as conn:
        rows=conn.execute('SELECT sparks FROM trainer_backend.reward_ledger WHERE trade_id=%s',(result['id'],)).fetchall()
        assert len(rows)==2 and sum(r['sparks'] for r in rows)==0
        assert conn.execute('SELECT payload FROM trainer_backend.loot_items WHERE id=%s',(listing['item_id'],)).fetchone()['payload']['private_save_bytes']=='never-forward'


def test_competing_buyers_and_retry_do_not_duplicate_goods(account,postgres):
    shop,s,owner,seller,buyer,rent,listing=market(account,postgres)
    account.provider.subject='774412';other=login(account)
    grant_test_sparks(postgres[0],other['player_id'],account.provider.subject,1000,'Isolated second buyer',uuid4())
    def buy(token):
        try:trading.buy(s,token,listing['id'],uuid4(),1,250);return 'paid'
        except AuthError as e:return e.code
    with ThreadPoolExecutor(2) as pool:assert sorted(pool.map(buy,[buyer['access_token'],other['access_token']]))==['listing_changed','paid']
    assert shop.progression.snapshot(buyer['access_token'])['balance']+shop.progression.snapshot(other['access_token'])['balance']==1750
    assert read_inventory(account,buyer['access_token'])['total']+read_inventory(account,other['access_token'])['total']==1


def test_failed_ledger_rolls_back_item_receipt_and_listing(account,postgres,monkeypatch):
    shop,s,owner,seller,buyer,rent,listing=market(account,postgres)
    def fail(*args):raise RuntimeError('test ledger fault')
    monkeypatch.setattr(trading,'ledger',fail)
    op=uuid4()
    with pytest.raises(RuntimeError):trading.buy(s,buyer['access_token'],listing['id'],op,1,250)
    assert shop.progression.snapshot(buyer['access_token'])['balance']==1000
    assert read_inventory(account,seller['access_token'])['items'][0]['state']=='listed'
    with pytest.raises(AuthError,match='not_found'):trading.receipt(s,buyer['access_token'],op)


def test_expiry_blocks_sale_but_owner_can_withdraw_when_payments_closed(account,postgres,monkeypatch):
    shop,s,owner,seller,buyer,rent,listing=market(account,postgres)
    with psycopg.connect(postgres[0]) as conn:
        conn.execute("UPDATE trainer_backend.bazaar_rentals SET started_at=started_at-interval '8 days',expires_at=expires_at-interval '8 days' WHERE id=%s",(rent['id'],))
    assert trading.listings(s,buyer['access_token'],rent['place_id'])['items']==[]
    with pytest.raises(AuthError,match='expired'):trading.buy(s,buyer['access_token'],listing['id'],uuid4(),1,250)
    monkeypatch.setattr(policy,'PAYMENTS_AVAILABLE',False)
    with pytest.raises(AuthError,match='not_found'):trading.withdraw(s,buyer['access_token'],listing['id'],1)
    result=trading.withdraw(s,seller['access_token'],listing['id'],1)
    assert result['listing']['state']=='withdrawn'
    assert trading.withdraw(s,seller['access_token'],listing['id'],1)==result
    assert read_inventory(account,seller['access_token'])['items'][0]['state']=='stored'


def test_seller_cost_is_per_rental_replay_and_no_permanent_unlock(account,postgres,monkeypatch):
    shop,s,owner,tenant,bid,pid=setup(account,postgres);token=tenant['access_token']
    rent=rentals.rent(s,token,uuid4(),bid,pid,1,100)['receipt'];op=uuid4()
    item=UUID(seed(postgres,tenant['player_id'])[0])
    with pytest.raises(AuthError,match='seller_required'):trading.create_listing(s,token,rent['id'],item,uuid4(),20)
    with pytest.raises(AuthError,match='offer_changed'):trading.hire(s,token,rent['id'],op,'Dino',1,99)
    first=trading.hire(s,token,rent['id'],op,'Dino',1,100)
    assert shop.progression.snapshot(token)['balance']==800
    with pytest.raises(AuthError,match='already_hired'):trading.hire(s,token,rent['id'],uuid4(),'Frog',1,100)
    monkeypatch.setattr(policy,'PAYMENTS_AVAILABLE',False)
    assert trading.hire(s,token,rent['id'],op,'Dino',1,100)==first
    with pytest.raises(AuthError,match='identity_conflict'):trading.hire(s,token,rent['id'],op,'Frog',1,100)


def test_listing_privacy_and_strict_routes(account,postgres):
    shop,s,owner,seller,buyer,rent,listing=market(account,postgres)
    rows=trading.listings(s,buyer['access_token'],rent['place_id'])['items']
    assert len(rows)==1 and 'payload' not in str(rows) and 'operation_id' not in rows[0]
    with pytest.raises(AuthError,match='own_listing'):trading.buy(s,seller['access_token'],listing['id'],uuid4(),1,250)
    auth={'Authorization':'Bearer '+buyer['access_token']}
    with TestClient(create_app(Settings(postgres[1],'test',oauth=CONFIG),provider=Provider())) as client:
        path='/v1/bazaar-listings/'+str(listing['id'])+'/buy'
        assert client.post(path,json={}).status_code in (401,422)
        for extra in [{'expected_price':True},{'expected_price':1.5},{'owner_id':str(buyer['player_id'])}]:
            assert client.post(path,headers=auth,json={'operation_id':str(uuid4()),'revision':'1','expected_price':250,**extra}).status_code==422
        assert client.post(path,headers=auth,json={'operation_id':str(uuid4()),'revision':'1','expected_price':250}).status_code==200


def test_world_mapping_requires_real_owner_and_provisioned_places(account,postgres):
    shop,s,owner,seller,buyer,rent,listing=market(account,postgres)
    token=buyer['access_token']
    with pytest.raises(AuthError,match='world_not_configured'):trading.world(s,token,'festival')
    with psycopg.connect(postgres[0]) as conn:
        bid=conn.execute('SELECT bazaar_id FROM trainer_backend.bazaar_places WHERE id=%s',(rent['place_id'],)).fetchone()[0]
        conn.execute("INSERT INTO trainer_backend.bazaar_worlds VALUES('festival',%s)",(bid,))
        conn.execute("INSERT INTO trainer_backend.bazaar_world_places VALUES('festival',1,%s)",(rent['place_id'],))
    data=trading.world(s,token,'festival')
    assert data['owner_id']==owner['player_id'] and data['seller_price']==100
    assert data['places'][0]['species']=='Frog' and data['places'][0]['rental_id']==rent['id']
    with pytest.raises(psycopg.errors.InsufficientPrivilege):
        with s.db.transaction() as conn:conn.execute("UPDATE trainer_backend.bazaar_worlds SET world_key='stolen'")


def test_listing_http_uses_uuid_strings_and_preserves_existing_item(account,postgres):
    shop,s,owner,seller,buyer,rent,listing=market(account,postgres)
    item=seed(postgres,seller['player_id'])[0]
    with TestClient(create_app(Settings(postgres[1],'test',oauth=CONFIG),provider=Provider())) as client:
        path='/v1/me/bazaar-rentals/'+str(rent['id'])+'/listings';auth={'Authorization':'Bearer '+seller['access_token']}
        body={'operation_id':str(uuid4()),'item_id':item,'price':30}
        first=client.post(path,headers=auth,json=body)
        assert first.status_code==200,first.text
        assert client.post(path,headers=auth,json=body).json()==first.json()
        assert client.post(path,headers=auth,json={**body,'payload':{}}).status_code==422


def test_official_owner_can_set_rent_without_consuming_personal_license(account,postgres,tmp_path):
    import json
    from trainer_backend.bazaar.registry import register
    from trainer_backend.bazaar.service import owned
    owner=login(account);subject=account.provider.subject
    manifest=tmp_path/'world.json'
    manifest.write_text(json.dumps({'world_key':'festival','owner_id':str(owner['player_id']),'expected_fluxer_subject':subject,'name':'Festival'}))
    bid=register(postgres[0],manifest);assert register(postgres[0],manifest)==bid
    # The operator binds an existing verified identity; no personal right is minted.
    from trainer_backend.economy.service import Progression
    from trainer_backend.bazaar.service import Bazaars
    s=Bazaars(Progression(account.db,account))
    data=trading.world(s,owner['access_token'],'festival');assert len(data['places'])==12
    with s.db.transaction() as conn:
        assert owned(conn,owner['player_id']) is None
        with pytest.raises(psycopg.errors.InsufficientPrivilege):
            conn.execute("INSERT INTO trainer_backend.bazaars(id,owner_id,kind,offer_id,name) VALUES(%s,%s,'official',NULL,'Fake')",(uuid4(),owner['player_id']))
    place=data['places'][0]
    assert place['weekly_price'] is None
    assert rentals.price(s,owner['access_token'],bid,place['id'],1,350)['place']['weekly_price']==350
    from trainer_backend.economy.shop import Shop
    shop=Shop(s.progression)
    grant_test_sparks(postgres[0],owner['player_id'],subject,6000,'Isolated official owner test',uuid4())
    shop.purchase(owner['access_token'],uuid4(),'bazaar.personal',1,5000)
    personal=s.create(owner['access_token'],{'name':'My own Bazaar','description':'','listed':True,'access':'open'})['bazaar']
    assert personal['id']!=bid and personal['kind']=='personal'
    bought=shop.purchase(owner['access_token'],uuid4(),'bazaar.stall',1,500)
    assert bought['purchased_place']['bazaar_id']==personal['id']
    assert len(trading.world(s,owner['access_token'],'festival')['places'])==12
    manifest.write_text(manifest.read_text().replace(subject,'999999999'))
    with pytest.raises(ValueError,match='identity_mismatch'):register(postgres[0],manifest)


def test_costumes_have_server_alpha_prices_but_cannot_charge_without_assets(account,postgres):
    shop,s,owner,tenant,bid,pid=setup(account,postgres);token=tenant['access_token']
    with TestClient(create_app(Settings(postgres[1],'test',oauth=CONFIG),provider=Provider())) as client:
        response=client.get('/v1/bazaar-costumes',headers={'Authorization':'Bearer '+token})
        assert response.status_code==200
        data=response.json();assert not data['payments_available']
        assert len(data['items'])==3 and all(v['price']==50 for v in data['items'])
    # Even an accidental operator availability flip cannot sell undeliverable clothes.
    with psycopg.connect(postgres[0]) as conn:conn.execute("UPDATE trainer_backend.shop_offers SET available=true WHERE purpose='avatar_costume'")
    for key in ('traveller','mage','merchant'):
        with pytest.raises(AuthError,match='costume_assets_unavailable'):shop.purchase(token,uuid4(),'costume.'+key,1,50)
    assert shop.progression.snapshot(token)['balance']==1000
