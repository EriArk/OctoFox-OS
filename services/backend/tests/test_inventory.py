from uuid import UUID, uuid4

import psycopg
from psycopg.types.json import Jsonb
import pytest
from fastapi.testclient import TestClient

from trainer_backend.app import create_app
from trainer_backend.config import Settings
from trainer_backend.inventory import read_inventory
from trainer_backend.accounts.provider import AuthError
from test_accounts import account, login, CONFIG, Provider


def seed(postgres, player, count=1):
    """Synthetic collectibles inserted by the isolated test DB owner, never runtime."""
    ids = []
    with psycopg.connect(postgres[0]) as conn:
        for i in range(count):
            item = uuid4(); ids.append(str(item))
            conn.execute('''INSERT INTO trainer_backend.loot_items
                (id,player_id,game_id,adapter_id,payload_version,kind,payload,presentation)
                VALUES(%s,%s,%s,%s,1,%s,%s,%s)''',
                (item, player, 'fixture.rpg' if i%2 else 'fixture.racer', 'fixture.adapter',
                 'equipment' if i%2 else 'vehicle', Jsonb({'private_save_bytes': 'never-forward', 'serial': i}),
                 Jsonb({'title': f'Item {i}', 'game': 'Fixture game', 'icon': 'shield' if i%2 else 'gamepad',
                        'facts': [{'label': 'Material', 'value': 'Iron'}]})))
    return ids


def test_empty_private_projection_is_real_and_not_shop_inventory(account, postgres):
    owner = login(account)
    data = read_inventory(account, owner['access_token'])
    assert data == {'version': 1, 'player_id': owner['player_id'], 'revision': '0', 'total': 0,
                    'items': [], 'next': None, 'transfers_available': False}
    seed(postgres, owner['player_id'])
    result = read_inventory(account, owner['access_token'])
    assert result['total'] == 1 and result['revision'] == '1'
    assert result['items'][0]['actions'] == []
    assert 'payload' not in result['items'][0] and 'private_save_bytes' not in str(result)
    assert 'sequence' not in result['items'][0] and 'purchase_id' not in result['items'][0]
    # Reconstructing the reader still returns the persisted row, with the same ID.
    assert read_inventory(account, owner['access_token']) == result
    account.provider.subject = '987654321'
    other = login(account)
    assert read_inventory(account, other['access_token'])['items'] == []
    assert read_inventory(account, other['access_token'])['revision'] == '0'


def test_pages_are_owner_scoped_revision_checked_and_fail_after_revocation(account, postgres):
    owner = login(account); token = owner['access_token']; ids = seed(postgres, owner['player_id'], 61)
    first = read_inventory(account, token)
    assert len(first['items']) == 60 and first['total'] == 61
    second = read_inventory(account, token, before=int(first['next']), revision=first['revision'])
    assert second['next'] is None and [str(r['id']) for r in first['items']+second['items']] == ids[::-1]
    with pytest.raises(AuthError, match='invalid_inventory_page'):
        read_inventory(account, token, before=1)
    # Even a same-count presentation / ownership change invalidates an old chain.
    with psycopg.connect(postgres[0]) as conn:
        conn.execute("UPDATE trainer_backend.loot_items SET state='listed' WHERE id=%s", (ids[0],))
    with pytest.raises(AuthError, match='inventory_changed'):
        read_inventory(account, token, before=int(first['next']), revision=first['revision'])
    account.provider.subject = '987654321'; other = login(account)
    with psycopg.connect(postgres[0]) as conn:
        conn.execute('UPDATE trainer_backend.loot_items SET player_id=%s WHERE id=%s', (other['player_id'], ids[0]))
    assert read_inventory(account, token)['total'] == 60
    assert read_inventory(account, other['access_token'])['revision'] == '1'
    with psycopg.connect(postgres[0]) as conn:
        conn.execute('DELETE FROM trainer_backend.loot_items WHERE id=%s', (ids[0],))
    assert read_inventory(account, other['access_token'])['revision'] == '2'
    with account.db.transaction() as conn:
        conn.execute('UPDATE trainer_backend.device_sessions SET revoked_at=clock_timestamp() WHERE id=%s', (owner['session_id'],))
    with pytest.raises(AuthError):
        read_inventory(account, token, before=int(first['next']), revision=first['revision'])


def test_runtime_cannot_mint_edit_or_delete_collectibles(account, postgres):
    owner = login(account); ids = seed(postgres, owner['player_id'])
    for statement in (
        'DELETE FROM trainer_backend.loot_items',
        "UPDATE trainer_backend.loot_items SET state='listed'",
        "INSERT INTO trainer_backend.loot_revisions VALUES('11111111-1111-4111-8111-111111111111',1)",
        'INSERT INTO trainer_backend.loot_items(id,player_id,game_id,adapter_id,payload_version,kind,payload,presentation) '
        'SELECT id,player_id,game_id,adapter_id,payload_version,kind,payload,presentation FROM trainer_backend.loot_items',
        'TRUNCATE trainer_backend.loot_items',
    ):
        with pytest.raises(psycopg.errors.InsufficientPrivilege):
            with account.db.transaction() as conn: conn.execute(statement)
    assert str(read_inventory(account, owner['access_token'])['items'][0]['id']) == ids[0]


def test_http_bounds_authentication_and_no_mutation_routes(account, postgres):
    owner = login(account); headers = {'Authorization': 'Bearer '+owner['access_token']}
    ids = seed(postgres, owner['player_id'])
    with TestClient(create_app(Settings(postgres[1], 'test', oauth=CONFIG), provider=Provider())) as client:
        path = '/v1/me/loot'
        assert client.get(path).status_code == 401
        result = client.get(path, headers=headers)
        assert result.status_code == 200 and result.headers['cache-control'] == 'no-store'
        assert result.json()['items'][0]['id'] == ids[0]
        assert result.json()['items'][0]['presentation']['subtitle'] == ''
        for query in ('?before=0&revision=1', '?before=9223372036854775808&revision=1', '?before=1', '?revision=1', '?before=1&revision=wat'):
            assert client.get(path+query, headers=headers).status_code == 422
        assert client.get(path+'?before=1&revision=0', headers=headers).status_code == 409
        for method in ('post', 'put', 'delete'):
            assert getattr(client, method)(path, headers=headers).status_code == 405
        caps = client.get('/v1/capabilities').json()['capabilities']
        assert caps['inventory.loot_read'] == 1 and caps['inventory.loot_transfer'] == 0
        assert caps['bazaar.payments'] == 0
        # Broken storage is a service error, never a misleading empty inventory or arbitrary URL.
        with psycopg.connect(postgres[0]) as conn:
            conn.execute('UPDATE trainer_backend.loot_items SET presentation=%s WHERE id=%s',
                         (Jsonb({'title': 'Bad', 'game': 'Fixture', 'image': 'file:///private'}), ids[0]))
        broken = client.get(path, headers=headers)
        assert broken.status_code == 503 and 'file:' not in broken.text
    with TestClient(create_app(Settings(postgres[1], 'test'))) as client:
        assert client.get('/v1/me/loot', headers=headers).status_code == 503
        assert 'inventory.loot_read' not in client.get('/v1/capabilities').json()['capabilities']
