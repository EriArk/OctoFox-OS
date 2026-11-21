from concurrent.futures import ThreadPoolExecutor
from uuid import uuid4

import pytest
from trainer_backend.accounts.provider import AuthError
from trainer_backend.bazaar import festival, policy
from trainer_backend.inventory import read_inventory
from test_accounts import account
from test_bazaar import prepared, development_payments


def test_paid_gallery_and_collectible(account, postgres, monkeypatch):
    shop, user, service = prepared(account, postgres)
    token = user['access_token']
    balance = shop.progression.snapshot(token)['balance']
    op = uuid4()
    def enter(_):
        return festival.enter(service, token, 'gallery', op, 10)['round']['id']
    with ThreadPoolExecutor(2) as pool:
        one, two = pool.map(enter, range(2))
    assert one == two
    with pytest.raises(AuthError, match='ticket_already_open'):
        festival.enter(service, token, 'gallery', uuid4(), 10)
    assert shop.progression.snapshot(token)['balance'] == balance-10
    assert read_inventory(account,token)['total']==0
    monkeypatch.setattr(policy, 'PAYMENTS_AVAILABLE', False)
    coords = [(-142,94),(-142,94),(0,94),(142,94),(200,250)]
    for index,(x,y) in enumerate(coords):
        result=festival.attempt(service,token,'gallery',one,index,x,y)
        assert festival.attempt(service,token,'gallery',one,index,x,y)==result
        assert festival.status(service,token,'gallery')['round']==result['round']
    assert [s['points'] for s in result['round']['attempts']]==[1,0,1,1,0]
    assert result['round']['complete'] and result['round']['prize']=='Honey Bear'
    items=read_inventory(account,token)['items']
    assert len(items)==1 and items[0]['presentation']['title']=='Honey Bear'
    assert items[0]['id']==one and items[0]['state']=='stored'
    with pytest.raises(AuthError,match='market_closed'):
        festival.enter(service,token,'gallery',uuid4(),10)


def test_ring_score_and_cup_ticket(account,postgres):
    shop,user,s=prepared(account,postgres)
    token=user['access_token']
    ticket=festival.enter(s,token,'rings',uuid4(),10)['round']['id']
    with pytest.raises(AuthError,match='round_changed'):
        festival.attempt(s,token,'rings',ticket,2,0,0)
    for i,(x,y,points) in enumerate(festival.PEGS):
        assert festival.attempt(s,token,'rings',ticket,i,x,y)['round']['attempts'][i]['points']==points
    for game in ['golf_local','golf_online']:
        cup=festival.enter(s,token,game,uuid4(),festival.PRICES[game])['round']
        assert festival.attempt(s,token,game,cup['id'],0,0,0)['round']['complete']
    assert read_inventory(account,token)['total']==0


def test_ticket_requires_quoted_price_and_belongs_to_buyer(account, postgres):
    from fastapi.testclient import TestClient
    from trainer_backend.app import create_app
    from trainer_backend.config import Settings
    from test_accounts import CONFIG, Provider, login

    shop, user, _ = prepared(account, postgres)
    balance = shop.progression.snapshot(user['access_token'])['balance']
    auth = {'Authorization': 'Bearer '+user['access_token']}
    account.provider.subject = '23456789'
    other = {'Authorization': 'Bearer '+login(account)['access_token']}
    path = '/v1/me/festival/gallery'
    entry = {'operation_id': str(uuid4()), 'expected_price': 10}
    with TestClient(create_app(Settings(postgres[1], 'test', oauth=CONFIG), provider=Provider())) as client:
        assert client.get(path).status_code == 401
        assert client.post(path, headers=other, json=entry).status_code == 409
        assert client.post(path, headers=auth, json={**entry,'expected_price':1}).status_code == 409
        assert client.get(path, headers=auth).json()['round'] is None
        paid = client.post(path, headers=auth, json=entry).json()['round']
        attempt = path+'/'+paid['id']+'/attempt'
        shot = {'index':0,'x':-142,'y':94}
        assert client.post(attempt, headers=other, json=shot).status_code == 404
        assert client.post(attempt, headers=auth, json={**shot,'prize':'Moon Cat'}).status_code == 422
        assert client.post(attempt, headers=auth, json={**shot,'index':-1}).status_code == 422
        assert client.get(path, headers=other).json()['round'] is None
        assert client.get(path, headers=auth).json()['round']['attempts'] == []
        assert shop.progression.snapshot(user['access_token'])['balance'] == balance-10
