"""Run the handheld trade rehearsal on a disposable loopback-only PostgreSQL."""
from contextlib import contextmanager
import argparse
import json
from pathlib import Path
from uuid import uuid4

import psycopg
from psycopg.types.json import Jsonb
import uvicorn

from conftest import postgres
from test_accounts import CONFIG, Provider, login
from trainer_backend.accounts.service import Accounts
from trainer_backend.app import create_app
from trainer_backend.bazaar import policy, rentals, trading
from trainer_backend.bazaar.registry import register
from trainer_backend.bazaar.service import Bazaars
from trainer_backend.config import Settings
from trainer_backend.db import Database
from trainer_backend.economy.maintenance import grant_test_sparks
from trainer_backend.economy.service import Progression


def prepare(db, directory):
    admin, runtime = db
    accounts = Accounts(Database(runtime), CONFIG, Provider())
    service = Bazaars(Progression(accounts.db, accounts))
    for i, name in enumerate(['Festival owner', 'Mika', 'Ren']):
        subject = str(984001 + i)
        accounts.provider.subject = subject
        session = login(accounts)
        player = session['player_id']
        with psycopg.connect(admin) as conn:
            conn.execute('UPDATE trainer_backend.public_profiles SET display_name=%s WHERE player_id=%s',(name,player))
        if i == 0:
            manifest = directory / 'festival.json'
            manifest.write_text(json.dumps(dict(world_key='festival',owner_id=str(player),expected_fluxer_subject=subject,name='Festival Park')))
            venue = register(admin,manifest)
            place = trading.world(service,session['access_token'],'festival')['places'][1]
            rentals.price(service,session['access_token'],venue,place['id'],1,150)
            continue
        grant_test_sparks(admin,player,subject,1000,'Disposable Bazaar handheld rehearsal',uuid4())
        wallet = directory / (name+'.json')
        with wallet.open('x') as out:
            wallet.chmod(0o600)
            json.dump({'refresh_token':session['refresh_token']},out)
        if name=='Mika':
            with psycopg.connect(admin) as conn:
                for title in ['Oran Berry','Pecha Berry']:
                    conn.execute('''INSERT INTO trainer_backend.loot_items
                        (id,player_id,game_id,adapter_id,payload_version,kind,payload,presentation)
                        VALUES(%s,%s,'pokemon.emerald','pokemon.emerald',1,'item',%s,%s)''',
                        (uuid4(),player,Jsonb({'fixture':True,'serial':str(uuid4())}),
                         Jsonb({'title':title,'game':'Pokémon Emerald','icon':'star'})))
    return create_app(Settings(runtime,'test',oauth=CONFIG),provider=accounts.provider)


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('directory',type=Path)
    parser.add_argument('--port',type=int,default=18641)
    args=parser.parse_args()
    args.directory.mkdir(mode=0o700,exist_ok=True)
    with contextmanager(postgres.__wrapped__)() as db:
        app=prepare(db,args.directory)
        policy.PAYMENTS_AVAILABLE=True
        try:
            uvicorn.run(app,host='127.0.0.1',port=args.port,access_log=False)
        finally:
            with psycopg.connect(db[0]) as conn:
                balances=dict(conn.execute("""SELECT p.display_name,a.balance FROM trainer_backend.public_profiles p
                    JOIN trainer_backend.progression_accounts a USING(player_id)""").fetchall())
                items=conn.execute("""SELECT p.display_name,i.id,i.presentation->>'title',i.state FROM trainer_backend.loot_items i
                    JOIN trainer_backend.public_profiles p USING(player_id) ORDER BY i.id""").fetchall()
                trades=conn.execute("SELECT kind,price FROM trainer_backend.bazaar_trades ORDER BY created_at").fetchall()
            (args.directory/'report.json').write_text(json.dumps(dict(balances=balances,items=items,trades=trades),default=str,indent=2))

if __name__=='__main__':
    main()
