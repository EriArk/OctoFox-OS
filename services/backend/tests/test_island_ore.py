from uuid import uuid4

import psycopg
import pytest
from fastapi.testclient import TestClient
from test_accounts import CONFIG, Provider, account
from test_bazaar_rentals import setup
from trainer_backend.app import create_app
from trainer_backend.bazaar import policy, rentals, trading
from trainer_backend.config import Settings
from trainer_backend.economy import workshop


@pytest.mark.parametrize('ore, metal, style, part', [('bauxite', 'Aluminium', 'traveller', 'hat'),
                                                    ('magnetite', 'Steel', 'merchant', 'top')])
def test_sell_refine_and_print(account, postgres, monkeypatch, ore, metal, style, part):
    monkeypatch.setattr(policy, 'PAYMENTS_AVAILABLE', True)
    _, bazaar, buyer, seller, bid, place = setup(account, postgres)
    workshop_url = '/v1/me/workshop'
    with psycopg.connect(postgres[0]) as db:
        day = db.execute('SELECT floor(extract(epoch FROM now())/86400)::int').fetchone()[0]
        # The Bazaar fixture supplies both accounts. Leave only the refined metal available for printing.
        while lot := workshop.stored(db, buyer['player_id'], 'material', metal):
            workshop.write(db, buyer['player_id'], 'material', {**lot[1], 'units': 0}, lot[0])
        workshop.write(db, buyer['player_id'], 'blueprint', {'sku': style})
        workshop.write(db, buyer['player_id'], 'material', {'sku': 'Cotton', 'units': 6})
    with TestClient(create_app(Settings(postgres[1], 'test', oauth=CONFIG), provider=Provider())) as client:
        def auth(user):
            return {'Authorization': 'Bearer ' + user['access_token']}

        def status(user):
            return client.get(workshop_url, headers=auth(user)).json()

        def command(user, action, **fields):
            fields.update(operation_id=str(uuid4()), revision=status(user)['revision'])
            return client.post(workshop_url+'/'+action, headers=auth(user), json=fields)

        sample = dict(ore=ore, day=day, player_id=str(seller['player_id']))

        def land(**changes):
            return client.post(workshop_url+'/collect', headers=auth(seller), json={**sample, **changes})

        assert land(day=day+1).status_code == 422
        assert land(ore='gold').status_code == 422
        lump = land().json()['item_id']
        assert land().json()['item_id'] == lump
        lease = rentals.rent(bazaar, seller['access_token'], uuid4(), bid, place, 1, 100)['receipt']
        trading.hire(bazaar, seller['access_token'], lease['id'], uuid4(), 'Frog', 1, 100)
        lot = trading.create_listing(bazaar, seller['access_token'], lease['id'], lump, uuid4(), 1)['listing']
        assert command(seller, 'print', ore=ore, hours=2).status_code == 409
        trading.buy(bazaar, buyer['access_token'], lot['id'], uuid4(), 1, 1)
        assert command(buyer, 'print', ore=ore, hours=1).status_code == 409
        job = command(buyer, 'print', ore=ore, hours=status(buyer)['refining_hours']).json()['job_id']
        assert 7190 <= status(buyer)['prints']['material.'+metal]['remaining_seconds'] <= 7200
        assert command(buyer, 'collect', job=job).status_code == 409
        assert command(buyer, 'print', ore=ore, hours=2).status_code == 409
        with psycopg.connect(postgres[0]) as db:
            db.execute("""UPDATE trainer_backend.workshop_prints SET started_at=started_at-interval '2 hours',
                       ready_at=ready_at-interval '2 hours' WHERE id=%s""", (job,))
        item = command(buyer, 'collect', job=job).json()['item_id']
        assert command(buyer, 'collect', job=job).json()['item_id'] == item
        assert {'kind': 'material', 'sku': metal, 'units': 1} in status(buyer)['stock']
        hours = status(buyer)['print_hours'][style][part]
        assert command(buyer, 'print', style=style, part=part, hours=hours).status_code == 200
        assert all(r['sku'] != metal for r in status(buyer)['stock'])
