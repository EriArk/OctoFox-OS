"""Two or more logged-in SDK hosts: full shared scorecard demo, no game simulation.

python scorecard_demo.py endpoint-a.json endpoint-b.json [endpoint-c.json ...]
Runs ONLY the explicitly named integration-demo ruleset. No production Golf scores.
"""
import argparse
import json
from pathlib import Path
import sys
import time
import uuid
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'python'))
from traineros import Client,HostError

def run(endpoints, verify_trophies=False):
    clients=[Client('org.traineros.scorecard-demo',endpoint,timeout=20) for endpoint in endpoints]
    try:
        people=[client.account()['player_id'] for client in clients]
        assert len(set(people))==len(clients) and all(people)
        for client in clients:
            opened=client.play_open('traineros.scorecard-demo.v1')
            assert opened['trust']=='peer_confirmed' and 'token' not in json.dumps(opened)
        def round(seats,values):
            mode='teams' if max(seats)>1 else 'individual'
            payload={'mode':mode,'seats':seats};operation=str(uuid.uuid4())
            first=clients[0].play('create',payload,operation)
            assert clients[0].play('create',payload,operation)['receipt_id']==first['receipt_id']
            key=first['match']['id']
            sides=[s for s,n in enumerate(seats) for _ in range(n)]
            for client,side in zip(clients[1:],sides[1:]):client.play('join',{'match_id':key,'side':side})
            clients[0].play('start',{'match_id':key})
            scores={'match_id':key,'scores':[{'side':i,'values':[v,v,v]} for i,v in enumerate(values)]}
            for client in clients:client.play('submit',scores)
            deadline=time.monotonic()+15
            while time.monotonic()<deadline:
                result=clients[0].play('get',{'match_id':key})
                if result['state']=='confirmed':break
                time.sleep(0.1)
            assert result['state']=='confirmed',result['state']
            board=clients[0].board(mode=mode)
            assert len(board['items'])==len(seats)
            assert clients[0].play('stats')['wins']>=1
            return key,board
        def has_cup(client):
            return next(t['earned'] for t in client.trophies()['items'] if t['id'] == 'demo-cup')
        if verify_trophies:
            assert not any(has_cup(client) for client in clients)
        solo,board=round([1]*len(clients),list(range(2,2+len(clients))))
        report={'players':len(clients),'sdk_socket':True,'http_api':True,'individual':'confirmed','receipt_replay':'same',
                'board_rows':len(board['items']),'credentials_exported':False,'identity_provider':'isolated_fixture'}
        if verify_trophies:
            assert [has_cup(client) for client in clients] == [True] + [False] * (len(clients)-1)
        if len(clients)==5:
            team,teamboard=round([2,3],[2,4]);assert sorted(len(x['members']) for x in teamboard['items'])==[2,3]
            report['teams_2_vs_3']='confirmed'
        # A contradictory late report immediately removes all solo outcomes.
        clients[-1].play('submit',{'match_id':solo,'scores':[{'side':i,'values':[9,9,9]} for i in range(len(clients))]})
        assert not clients[0].board()['items']
        try:clients[0].board(revision=board['revision'])
        except HostError as error:assert error.code=='stale_revision'
        else:raise AssertionError('stale page accepted')
        report['late_conflict']='withdrawn';report['pagination']='stale_revision_rejected'
        if verify_trophies:
            winners = 2 if len(clients) == 5 else 0
            assert [has_cup(client) for client in clients] == [i < winners for i in range(len(clients))]
            report['game_trophies'] = 'confirmed_winners_only'
        return report
    finally:
        for client in clients:client.close()

if __name__=='__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--verify-trophies', action='store_true')
    parser.add_argument('endpoints', nargs='+')
    args = parser.parse_args()
    if not 2 <= len(args.endpoints) <= 16:
        parser.error('Provide 2..16 explicit SDK endpoint files')
    print(json.dumps(run(args.endpoints, args.verify_trophies), indent=2))
