import secrets
from uuid import uuid4
from concurrent.futures import ThreadPoolExecutor
import pytest
from fastapi.testclient import TestClient
from trainer_backend.accounts.provider import FluxerProvider,AuthError
from trainer_backend.accounts.service import challenge
from trainer_backend.app import create_app
from trainer_backend.config import Settings
from test_accounts import account,CONFIG,Provider,login
from test_profiles import RECIPE

TOKEN='session-for-isolated-tests-only'

def begin(account,subject=None):
    proof=secrets.token_urlsafe(32)
    row=account.begin(uuid4(),{'provider':'fluxer','flow':'social','device_label':'new device',
        'expected_subject':subject or account.provider.subject,'claim_challenge_method':'S256','claim_challenge':challenge(proof)})
    return row['attempt_id'],proof

def provider(account):
    def identify(token):
        if token!=TOKEN: raise AuthError('fluxer_session_rejected',401)
        return {'subject':account.provider.subject}
    account.provider.identify_session=identify

def automatic(account):
    key,proof=begin(account);account.verify_social(key,proof,TOKEN)
    return account.claim(key,proof)

def test_new_identity_has_temporary_name_and_returning_keeps_custom_profile(account):
    provider(account);first=automatic(account);profile=account.profile(first['access_token'])
    assert profile['display_name'].startswith('Fox-')
    assert profile['needs_name'] and profile['needs_avatar']
    profile=account.rename(first['access_token'],'  New Fox  ',profile['revision'])
    assert profile['display_name']=='New Fox' and not profile['needs_name']
    account.profile(first['access_token'],avatar=RECIPE)
    second=automatic(account)
    assert second['player_id']==first['player_id']
    current=account.profile(second['access_token'])
    assert current['display_name']=='New Fox' and current['avatar']==RECIPE
    assert not current['needs_name'] and not current['needs_avatar']
    # Legacy OAuth cannot rename a chosen OctoFox identity on subsequent login.
    oauth=login(account)
    assert oauth['player_id']==first['player_id']
    assert account.profile(oauth['access_token'])==current

def test_session_verification_rejects_forgery_and_does_not_create_players(account,db):
    provider(account)
    for subject,proof_bad,token in [('999999',False,TOKEN),(None,True,TOKEN),(None,False,'wrong-token-value')]:
        key,proof=begin(account,subject)
        with pytest.raises(AuthError): account.verify_social(key,'x'*43 if proof_bad else proof,token)
    with db.transaction() as conn:
        assert conn.execute('SELECT count(*) AS n FROM trainer_backend.players').fetchone()['n']==0

def test_social_attempt_cannot_be_opened_as_browser_login(account):
    from urllib.parse import parse_qs,urlsplit
    row=account.begin(uuid4(),{'provider':'fluxer','flow':'social','device_label':'new',
        'expected_subject':account.provider.subject,'claim_challenge_method':'S256','claim_challenge':challenge('x'*43)})
    ticket=parse_qs(urlsplit(row['authorization_url']).query)['ticket'][0]
    with pytest.raises(AuthError):account.start(row['attempt_id'],ticket)

def test_concurrent_verified_sessions_share_one_player_and_retry_is_safe(account,db):
    provider(account)
    with ThreadPoolExecutor(max_workers=3) as pool: users=list(pool.map(lambda _:automatic(account),range(3)))
    assert len({u['player_id'] for u in users})==1
    key,proof=begin(account);account.verify_social(key,proof,TOKEN);account.verify_social(key,proof,TOKEN)
    first=account.claim(key,proof)
    assert account.claim(key,proof)==first
    account.refresh(first["refresh_token"])
    with pytest.raises(AuthError):account.claim(key,proof)
    with db.transaction() as conn:
        assert conn.execute('SELECT count(*) AS n FROM trainer_backend.players').fetchone()['n']==1
        assert TOKEN not in str(conn.execute('SELECT * FROM trainer_backend.login_attempts').fetchall())

@pytest.mark.parametrize('name',['','  ','x'*25,'line\nbreak','a\u202eb','a\0b'])
def test_nickname_rejects_invalid_content(account,name):
    provider(account);u=automatic(account);p=account.profile(u['access_token'])
    with pytest.raises(AuthError):account.rename(u['access_token'],name,p['revision'])

def test_nickname_revision_prevents_overwrite_and_new_subject_gets_new_identity(account):
    provider(account);u=automatic(account);p=account.profile(u['access_token'])
    account.rename(u['access_token'],'First',p['revision'])
    with pytest.raises(AuthError,match='profile_changed'):account.rename(u['access_token'],'Late',p['revision'])
    account.provider.subject='987654321'
    assert automatic(account)['player_id']!=u['player_id']

def test_session_transport_uses_fixed_current_user_endpoint_and_rejects_bots(monkeypatch):
    p=FluxerProvider(CONFIG);seen=[]
    def request(path,**kwargs):
        seen.append((path,kwargs));return {'id':'12345','global_name':'Untrusted presentation'}
    monkeypatch.setattr(p,'_request',request)
    assert p.identify_session(TOKEN)=={'subject':'12345'}
    assert seen==[('/v1/users/@me',{'session':TOKEN})]
    monkeypatch.setattr(p,'_request',lambda *a,**k:{'id':'12345','bot':True})
    with pytest.raises(AuthError):p.identify_session(TOKEN)
    with pytest.raises(AuthError):p.identify_session('secret\r\nHeader: forged')

def test_automatic_http_flow_never_needs_a_second_browser(postgres,db):
    p=Provider();p.identify_session=lambda token:{'subject':p.subject} if token==TOKEN else (_ for _ in ()).throw(AuthError())
    with TestClient(create_app(Settings(postgres[1],'test',oauth=CONFIG),provider=p)) as client:
        proof=secrets.token_urlsafe(32)
        row=client.post('/v1/auth/login-attempts',headers={'Idempotency-Key':str(uuid4())},json={
            'flow':'social','provider':'fluxer','device_label':'first run','expected_subject':p.subject,
            'claim_challenge_method':'S256','claim_challenge':challenge(proof)}).json()
        body={'attempt_id':row['attempt_id'],'claim_verifier':proof,'fluxer_token':TOKEN}
        assert client.post('/v1/auth/fluxer/session',json=body).status_code==204
        body.pop('fluxer_token')
        session=client.post('/v1/auth/login-attempts/claim',json=body)
        assert session.status_code==200
        auth={'Authorization':'Bearer '+session.json()['access_token']}
        profile=client.get('/v1/me/profile',headers=auth).json()
        result=client.put('/v1/me/profile/name',headers=auth,json={'display_name':'Fox friend','revision':profile['revision']})
        assert result.status_code==200 and not result.json()['needs_name']
        denied=client.put('/v1/me/profile/name',headers=auth,json={'display_name':'another','revision':profile['revision'],'player_id':str(uuid4())})
        assert denied.status_code==422
