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

@pytest.fixture(autouse=True)
def development_payments(monkeypatch):
    from trainer_backend.bazaar import policy
    monkeypatch.setattr(policy,'PAYMENTS_AVAILABLE',True)


DETAILS = {'name': 'Little square', 'description': 'Meet here', 'listed': True, 'access': 'open'}


def prepared(account, postgres):
    shop, user = funded(account)
    # Isolated database only: a deterministic balance for purchase tests.
    grant_test_sparks(postgres[0], user['player_id'], account.provider.subject, 9000, 'Isolated Bazaar test', uuid4())
    return shop, user, Bazaars(shop.progression)


def buy(shop, access, operation=None):
    return shop.purchase(access, operation or uuid4(), 'bazaar.personal', 1, 5000)


def create(shop, access, details=DETAILS):
    buy(shop, access)
    return Bazaars(shop.progression).create(access, details)


def test_purchase_then_create_later_after_login_without_second_payment(account, postgres):
    shop,user,service=prepared(account,postgres);token=user['access_token'];op=uuid4()
    with pytest.raises(AuthError,match='license_required'):service.create(token,DETAILS)
    result=buy(shop,token,op)
    assert result['bazaar'] is None and result['bazaar_license']
    assert result['receipt']['details']=={} and result['receipt']['price']==5000
    assert not service.directory(token)['items']
    restored=shop.snapshot(login(account)['access_token'],op)
    assert restored['bazaar'] is None and restored['bazaar_license']
    assert restored['receipt']['id']==result['receipt']['id']
    assert buy(shop,token,op)['bazaar'] is None
    with pytest.raises(AuthError,match='already_owned'):buy(shop,token)
    with ThreadPoolExecutor(2) as pool:
        results=list(pool.map(lambda n:service.create(token,{**DETAILS,'name':'Place '+str(n)}),range(2)))
    place=results[0]['bazaar']
    assert results[1]['bazaar']['id']==place['id'] and results[1]['bazaar']['name']==place['name']
    assert service.create(token,DETAILS)['bazaar']['name']==place['name']
    assert shop.progression.snapshot(token)['balance']==5000
    assert sum(r['sparks'] for r in shop.progression.snapshot(token)['history'])==5000
    row=service.directory(token)['items'][0]
    assert row['owned'] and row['visitors'] is None and not row['join_available']


def test_creation_failure_keeps_paid_right_for_retry(account, postgres, monkeypatch):
    shop,user,service=prepared(account,postgres);token=user['access_token'];buy(shop,token)
    import trainer_backend.bazaar.service as module
    original=module.publish
    def fail(*args):raise RuntimeError('outbox unavailable')
    monkeypatch.setattr(module,'publish',fail)
    with pytest.raises(RuntimeError):service.create(token,DETAILS)
    snapshot=shop.snapshot(token)
    assert snapshot['bazaar'] is None and snapshot['bazaar_license']
    assert shop.progression.snapshot(token)['balance']==5000
    monkeypatch.setattr(module,'publish',original)
    assert service.create(token,DETAILS)['bazaar']['name']==DETAILS['name']
    assert shop.progression.snapshot(token)['balance']==5000


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
    shop,user,service=prepared(account,postgres);token=user['access_token'];place=create(shop,token)['bazaar']
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
    with pytest.raises(AuthError,match='offer_changed'):shop.purchase(token,uuid4(),'bazaar.personal',1,1)
    with pytest.raises(AuthError,match='invalid_bazaar'):shop.purchase(token,uuid4(),'bazaar.personal',1,5000,DETAILS)
    with pytest.raises(AuthError,match='invalid_bazaar'):shop.purchase(token,uuid4(),'profile.dusk',1,250,DETAILS)
    assert shop.snapshot(token)['bazaar'] is None


def test_http_contract_rejects_forged_owner_host_and_invalid_edits(account, postgres):
    shop,user,service=prepared(account,postgres);auth={'Authorization':'Bearer '+user['access_token']}
    with TestClient(create_app(Settings(postgres[1],'test',oauth=CONFIG),provider=Provider())) as client:
        assert client.get('/v1/bazaars').status_code==401
        body={'operation_id':str(uuid4()),'offer_id':'bazaar.personal','offer_revision':1,'expected_price':5000}
        for extra in [{'owner_id':str(user['player_id'])},{'host_id':'other'},{'listed':1},{'name':'  '}]:
            assert client.post('/v1/me/bazaars',headers=auth,json={**DETAILS,**extra}).status_code==422
        result=client.post('/v1/me/purchases',headers=auth,json=body)
        assert result.status_code==200
        assert result.json()['bazaar'] is None and result.json()['bazaar_license']
        assert client.post('/v1/me/purchases',headers=auth,json={**body,'operation_id':str(uuid4()),'bazaar':DETAILS}).status_code==422
        result=client.post('/v1/me/bazaars',headers=auth,json=DETAILS)
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
        create(shop,user['access_token'],details={**DETAILS,'name':'Square '+str(number)})
    page=service.directory(first['access_token']);assert len(page['items'])==24 and page['next']
    tail=service.directory(first['access_token'],after=page['next']);assert len(tail['items'])==2 and tail['next'] is None
    assert len({str(row['id']) for row in page['items']+tail['items']})==26
    chosen=page['items'][3]['id']
    favorites=service.directory(first['access_token'],favorites=[chosen]);assert [row['id'] for row in favorites['items']]==[chosen]
    with pytest.raises(psycopg.errors.InsufficientPrivilege):
        with account.db.transaction() as conn:conn.execute('UPDATE trainer_backend.bazaars SET owner_id=owner_id')


def test_card_presets_persist_and_old_clients_do_not_reset_them(account,postgres):
    shop,user,service=prepared(account,postgres);token=user['access_token']
    place=create(shop,token,{**DETAILS,'cover':'grove','badge':'guide'})['bazaar']
    assert place['cover']=='grove' and place['badge']=='guide'
    edited=service.update(token,place['id'],1,{**DETAILS,'cover':'harbor','badge':'trophy'})['bazaar']
    assert edited['revision']==2 and service.directory(token)['items'][0]['cover']=='harbor'
    legacy=service.update(token,place['id'],2,{**DETAILS,'description':'Legacy edit'})['bazaar']
    assert legacy['cover']=='harbor' and legacy['badge']=='trophy'
    assert shop.progression.snapshot(token)['balance']==5000
    for key,value in [('cover','https://untrusted/image.png'),('badge','file:///etc/passwd')]:
        with pytest.raises(AuthError,match='invalid_bazaar'):service.update(token,place['id'],3,{**DETAILS,key:value})


def test_access_rules_belong_to_owner_not_another_player_and_never_admit(account,postgres):
    shop,user,service=prepared(account,postgres);owner=user['access_token'];place=create(shop,owner)['bazaar'];bid=place['id']
    account.provider.subject='99001';visitor=login(account);token=visitor['access_token'];pid=visitor['player_id']
    assert service.access_policy(token,bid)['policy_allows'] and not service.access_policy(token,bid)['join_available']
    for operation in [lambda:service.access_settings(token,bid),lambda:service.block(token,bid,pid,True,1)]:
        with pytest.raises(AuthError,match='not_found'):operation()
    with pytest.raises(AuthError,match='owner_cannot'):service.block(owner,bid,user['player_id'],True,1)
    blocked=service.block(owner,bid,pid,True,1)
    assert blocked['bazaar']['revision']==2 and not blocked['live_moderation']
    assert service.access_policy(token,bid)['reason']=='blocked'
    assert not service.access_policy(token,bid)['policy_allows']
    settings=service.access_settings(owner,bid,target=pid)
    assert settings['target']['blocked'] and settings['blocks'][0]['player_id']==pid
    assert service.block(owner,bid,pid,True,1)['bazaar']['revision']==2 # idempotent repeat
    with pytest.raises(AuthError,match='changed'):service.block(owner,bid,pid,False,1)
    service.block(owner,bid,pid,False,2)
    service.block(owner,bid,pid,True,3)
    with pytest.raises(AuthError,match='changed'):service.block(owner,bid,pid,False,2) # delayed old unblock
    service.block(owner,bid,pid,False,4)
    service.update(owner,bid,5,{**DETAILS,'access':'closed'})
    assert service.access_policy(token,bid)['reason']=='closed'
    assert service.access_policy(owner,bid)['reason']=='owner'
    service.update(owner,bid,6,{**DETAILS,'listed':False})
    with pytest.raises(AuthError,match='not_found'):service.access_policy(token,bid)
    assert service.access_policy(owner,bid)['policy_allows']


def test_block_outbox_failure_rolls_back_and_http_rejects_host_authority(account,postgres,monkeypatch):
    shop,user,service=prepared(account,postgres);owner=user['access_token'];place=create(shop,owner)['bazaar'];bid=place['id']
    account.provider.subject='99002';visitor=login(account);pid=visitor['player_id']
    import trainer_backend.bazaar.service as module
    original=module.publish
    def fail(*args):raise RuntimeError('outbox unavailable')
    monkeypatch.setattr(module,'publish',fail)
    with pytest.raises(RuntimeError):service.block(owner,bid,pid,True,1)
    assert not service.access_settings(owner,bid)['blocks'] and service.access_settings(owner,bid)['bazaar']['revision']==1
    monkeypatch.setattr(module,'publish',original)
    auth={'Authorization':'Bearer '+owner};path='/v1/me/bazaars/'+str(bid)
    with TestClient(create_app(Settings(postgres[1],'test',oauth=CONFIG),provider=Provider())) as client:
        assert client.get(path+'/access').status_code==401
        assert client.get(path+'/access',headers={'Authorization':'Bearer '+visitor['access_token']}).status_code==404
        assert client.put(path+'/blocks/'+str(pid),headers=auth,json={'revision':'1','blocked':True,'host_id':str(pid)}).status_code==422
        assert client.put(path+'/blocks/'+str(pid),headers=auth,json={'revision':'1','blocked':1}).status_code==422
        assert client.put(path+'/blocks/'+str(pid),headers=auth,json={'revision':'1','blocked':True}).status_code==200
        assert client.get(path+'/access',headers=auth).json()['blocks'][0]['player_id']==str(pid)
    account.revoke(owner,user['session_id'])
    with pytest.raises(AuthError):service.block(owner,bid,pid,False,2)


def test_blocked_players_list_is_paged_without_cross_owner_access(account,postgres):
    shop,user,service=prepared(account,postgres);owner=user['access_token'];bid=create(shop,owner)['bazaar']['id']
    for n in range(101):
        # Seed identities in the disposable fixture DB, without bypassing production OAuth limits.
        with account.db.transaction() as conn:
            player=conn.execute('SELECT trainer_backend.resolve_fluxer_player(%s,%s) AS id',('https://fluxer.app',str(990000+n))).fetchone()['id']
        service.block(owner,bid,player,True,n+1)
    first=service.access_settings(owner,bid);assert len(first['blocks'])==100 and first['next']
    second=service.access_settings(owner,bid,after=first['next']);assert len(second['blocks'])==1 and second['next'] is None
    assert len({str(row['player_id']) for row in first['blocks']+second['blocks']})==101
