from concurrent.futures import ThreadPoolExecutor
from uuid import uuid4
import psycopg
import pytest
from fastapi.testclient import TestClient
from trainer_backend.app import create_app
from trainer_backend.config import Settings
from trainer_backend.accounts.provider import AuthError
from trainer_backend.bazaar.service import Bazaars
from trainer_backend.economy.maintenance import grant_test_sparks
from test_accounts import account, login, CONFIG, Provider
from test_shop import funded

DETAILS = {'name': 'Little square', 'description': 'Meet here', 'listed': True, 'access': 'open'}


def prepared(account, postgres):
    shop, user = funded(account)
    # Isolated database only: a deterministic balance for purchase tests.
    grant_test_sparks(postgres[0], user['player_id'], account.provider.subject, 9000, 'Isolated Bazaar test', uuid4())
    return shop, user, Bazaars(shop.progression)


def buy(shop, access, operation=None, details=None):
    return shop.purchase(access, operation or uuid4(), 'bazaar.personal', 1, 5000, details or DETAILS)


def test_creation_is_atomic_permanent_one_per_account_and_recoverable(account, postgres):
    shop, user, service = prepared(account, postgres); token=user['access_token']; op=uuid4()
    result=buy(shop,token,op); place=result['bazaar']
    assert place['owner_id']==user['player_id'] and place['name']==DETAILS['name']
    assert result['receipt']['details']==DETAILS and result['receipt']['price']==5000
    assert shop.progression.snapshot(token)['balance']==5000
    with ThreadPoolExecutor(2) as pool:
        replay=list(pool.map(lambda _:buy(shop,token,op),range(2)))
    assert all(r['bazaar']['id']==place['id'] for r in replay)
    with pytest.raises(AuthError,match='already_owned'):buy(shop,token)
    with pytest.raises(AuthError,match='identity_conflict'):buy(shop,token,op,{**DETAILS,'name':'Changed'})
    restored=shop.snapshot(login(account)['access_token'],op)
    assert restored['bazaar']['id']==place['id'] and restored['receipt']['id']==result['receipt']['id']
    assert shop.progression.snapshot(token)['balance']==5000
    assert sum(r['sparks'] for r in shop.progression.snapshot(token)['history'])==5000
    row=service.directory(token)['items'][0]
    assert row['owned'] and row['visitors'] is None and not row['join_available']


def test_two_creations_and_shop_spend_share_the_same_account_lock(account, postgres):
    shop,user,_=prepared(account,postgres);token=user['access_token']
    def attempt(_):
        try:buy(shop,token);return 'bought'
        except AuthError as error:return error.code
    with ThreadPoolExecutor(2) as pool:assert sorted(pool.map(attempt,range(2)))==['already_owned','bought']
    assert shop.progression.snapshot(token)['balance']==5000
    with account.db.transaction() as conn:
        assert conn.execute("SELECT count(*) n FROM trainer_backend.reward_ledger WHERE source='shop.purchase'").fetchone()['n']==1


def test_create_rolls_back_with_ledger_receipt_ownership_and_outbox(account, postgres, monkeypatch):
    shop,user,_=prepared(account,postgres)
    import trainer_backend.economy.shop as module
    def fail(*args):raise RuntimeError('outbox unavailable')
    monkeypatch.setattr(module,'publish',fail)
    with pytest.raises(RuntimeError):buy(shop,user['access_token'])
    assert shop.snapshot(user['access_token'])['bazaar'] is None
    assert shop.progression.snapshot(user['access_token'])['balance']==10000
    with account.db.transaction() as conn:
        for table in ['bazaars','purchases','owned_items']:
            assert conn.execute('SELECT count(*) n FROM trainer_backend.'+table).fetchone()['n']==0


def test_owner_edit_conflict_hidden_catalogue_and_revoked_credentials(account, postgres):
    shop,user,service=prepared(account,postgres);token=user['access_token'];place=buy(shop,token)['bazaar']
    account.provider.subject='99999';other=login(account)['access_token']
    assert not service.directory(other)['items'][0]['owned']
    with pytest.raises(AuthError,match='not_found'):service.update(other,place['id'],1,DETAILS)
    edited=service.update(token,place['id'],1,{**DETAILS,'listed':False,'access':'closed'})['bazaar']
    assert edited['revision']==2 and not service.directory(other)['items']
    assert service.directory(token)['items'][0]['id']==place['id']
    assert not service.directory(token,search='absent')['items']
    assert not service.directory(token,favorites=[])['items']
    with pytest.raises(AuthError,match='changed'):service.update(token,place['id'],1,DETAILS)
    assert shop.progression.snapshot(token)['balance']==5000
    account.revoke(token,user['session_id'])
    with pytest.raises(AuthError):service.update(token,place['id'],2,DETAILS)


def test_creation_revalidates_price_balance_and_rejects_unrelated_details(account, postgres):
    shop,user=funded(account);token=user['access_token']
    with pytest.raises(AuthError,match='insufficient'):buy(shop,token)
    with pytest.raises(AuthError,match='offer_changed'):shop.purchase(token,uuid4(),'bazaar.personal',1,1,DETAILS)
    with pytest.raises(AuthError,match='invalid_bazaar'):shop.purchase(token,uuid4(),'bazaar.personal',1,5000)
    with pytest.raises(AuthError,match='invalid_bazaar'):shop.purchase(token,uuid4(),'profile.dusk',1,250,DETAILS)
    assert shop.snapshot(token)['bazaar'] is None


def test_http_contract_rejects_forged_owner_host_and_invalid_edits(account, postgres):
    shop,user,service=prepared(account,postgres);auth={'Authorization':'Bearer '+user['access_token']}
    with TestClient(create_app(Settings(postgres[1],'test',oauth=CONFIG),provider=Provider())) as client:
        assert client.get('/v1/bazaars').status_code==401
        body={'operation_id':str(uuid4()),'offer_id':'bazaar.personal','offer_revision':1,'expected_price':5000,'bazaar':DETAILS}
        for extra in [{'owner_id':str(user['player_id'])},{'host_id':'other'},{'listed':1},{'name':'  '}]:
            assert client.post('/v1/me/purchases',headers=auth,json={**body,'bazaar':{**DETAILS,**extra}}).status_code==422
        result=client.post('/v1/me/purchases',headers=auth,json=body)
        assert result.status_code==200
        place=result.json()['bazaar'];assert place['revision']=='1'
        assert client.put('/v1/me/bazaars/'+place['id'],headers=auth,json={**DETAILS,'revision':'1','owner_id':'other'}).status_code==422
        response=client.put('/v1/me/bazaars/'+place['id'],headers=auth,json={**DETAILS,'revision':'1','name':'New name'})
        assert response.status_code==200 and response.json()['bazaar']['revision']=='2'
        assert client.get('/v1/bazaars',headers=auth,params={'q':'New name'}).json()['items'][0]['id']==place['id']
        assert client.get('/v1/bazaars',headers=auth,params={'favorites':'invalid'}).status_code==422
        assert client.post('/v1/bazaars/'+place['id']+'/join',headers=auth,json={}).status_code==404
    with pytest.raises(psycopg.errors.InsufficientPrivilege):
        with account.db.transaction() as conn:conn.execute('DELETE FROM trainer_backend.bazaars')


def test_bazaar_and_other_shop_purchase_cannot_overspend(account, postgres):
    shop,user=funded(account);token=user['access_token']
    grant_test_sparks(postgres[0], user['player_id'], account.provider.subject, 4000, 'Isolated concurrent purchase', uuid4())
    def attempt(offer):
        try:
            if offer=='bazaar.personal':buy(shop,token)
            else:shop.purchase(token,uuid4(),offer,1,250)
            return 'bought'
        except AuthError as error:return error.code
    with ThreadPoolExecutor(2) as pool:result=list(pool.map(attempt,['bazaar.personal','profile.aurora']))
    assert sorted(result)==['bought','insufficient_sparks']
    progress=shop.progression.snapshot(token)
    assert progress['balance'] in (0,4750)
    assert sum(row['sparks'] for row in progress['history'])==progress['balance']


def test_directory_pages_favorites_and_owner_columns_are_bounded(account, postgres):
    from trainer_backend.economy.shop import Shop
    from trainer_backend.economy.service import Progression
    shop=Shop(Progression(account.db,account));service=Bazaars(shop.progression)
    first=None
    for number in range(26):
        account.provider.subject=str(900000+number);user=login(account)
        first=first or user
        grant_test_sparks(postgres[0],user['player_id'],account.provider.subject,5000,'Isolated catalogue test',uuid4())
        buy(shop,user['access_token'],details={**DETAILS,'name':'Square '+str(number)})
    page=service.directory(first['access_token']);assert len(page['items'])==24 and page['next']
    tail=service.directory(first['access_token'],after=page['next']);assert len(tail['items'])==2 and tail['next'] is None
    assert len({str(row['id']) for row in page['items']+tail['items']})==26
    chosen=page['items'][3]['id']
    favorites=service.directory(first['access_token'],favorites=[chosen]);assert [row['id'] for row in favorites['items']]==[chosen]
    with pytest.raises(psycopg.errors.InsufficientPrivilege):
        with account.db.transaction() as conn:conn.execute('UPDATE trainer_backend.bazaars SET owner_id=owner_id')
