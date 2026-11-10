from uuid import uuid4
import pytest
from fastapi.testclient import TestClient
from trainer_backend.app import create_app
from trainer_backend.config import Settings
from trainer_backend.accounts.provider import AuthError
from trainer_backend.bazaar import policy,rentals
from test_accounts import account,login,CONFIG,Provider
from test_bazaar import prepared,DETAILS


def test_default_preview_blocks_all_bazaar_spending_and_keeps_other_shop(account,postgres):
    assert policy.PAYMENTS_AVAILABLE is False
    shop,user,bazaars=prepared(account,postgres);token=user['access_token']
    before=shop.progression.snapshot(token)['balance'];auth={'Authorization':'Bearer '+token}
    with TestClient(create_app(Settings(postgres[1],'test',oauth=CONFIG),provider=Provider())) as client:
        snap=client.get('/v1/me/inventory',headers=auth).json()
        assert not snap['bazaar_payments_available'] and snap['bazaar_offer'] is None and snap['bazaar_stall_offer'] is None
        for offer,price in [('bazaar.personal',5000),('bazaar.stall',500)]:
            result=client.post('/v1/me/purchases',headers=auth,json={'operation_id':str(uuid4()),'offer_id':offer,'offer_revision':1,'expected_price':price})
            assert result.status_code==409 and result.json()['code']=='bazaar_under_development'
    assert shop.progression.snapshot(token)['balance']==before
    assert shop.snapshot(token)['bazaar'] is None
    shop.purchase(token,uuid4(),'profile.aurora',1,250)
    assert shop.progression.snapshot(token)['balance']==before-250


def test_paid_receipts_and_places_survive_pause_but_new_rent_cannot_charge(account,postgres,monkeypatch):
    shop,owner,bazaars=prepared(account,postgres);token=owner['access_token'];buy=uuid4();stall=uuid4();rent=uuid4()
    with monkeypatch.context() as active:
        active.setattr(policy,'PAYMENTS_AVAILABLE',True)
        shop.purchase(token,buy,'bazaar.personal',1,5000)
        bid=bazaars.create(token,DETAILS)['bazaar']['id']
        place=shop.purchase(token,stall,'bazaar.stall',1,500)['purchased_place']
        rentals.price(bazaars,token,bid,place['id'],1,100)
        account.provider.subject='987654';tenant=login(account)
        from trainer_backend.economy.maintenance import grant_test_sparks
        grant_test_sparks(postgres[0],tenant['player_id'],account.provider.subject,1000,'Isolated preview test',uuid4())
        receipt=rentals.rent(bazaars,tenant['access_token'],rent,bid,place['id'],2,100)['receipt']
    assert policy.PAYMENTS_AVAILABLE is False
    assert shop.purchase(token,buy,'bazaar.personal',1,5000)['bazaar_license']
    assert shop.purchase(token,stall,'bazaar.stall',1,500)['purchased_place']['id']==place['id']
    assert rentals.rent(bazaars,tenant['access_token'],rent,bid,place['id'],2,100)['receipt']['id']==receipt['id']
    assert not rentals.places(bazaars,tenant['access_token'],bid)['items'][0]['rentable']
    with pytest.raises(AuthError,match='under_development'):
        rentals.rent(bazaars,tenant['access_token'],uuid4(),bid,place['id'],3,100)
    auth={'Authorization':'Bearer '+tenant['access_token']}
    with TestClient(create_app(Settings(postgres[1],'test',oauth=CONFIG),provider=Provider())) as client:
        result=client.post(f'/v1/bazaars/{bid}/places/{place["id"]}/rent',headers=auth,json={'operation_id':str(uuid4()),'revision':'3','expected_price':100})
        assert result.status_code==409 and result.json()['code']=='bazaar_under_development'
    assert shop.progression.snapshot(tenant['access_token'])['balance']==900
    assert shop.progression.snapshot(token)['balance']==4600
