# SPDX-License-Identifier: GPL-3.0-or-later
from uuid import uuid4
from psycopg.types.json import Jsonb
from ..accounts.provider import AuthError
from . import policy

# cm in the target plane. Rings use x/z relative to the centre of the counter.
TOYS = [(-142, 94, 'Peach Bunny'), (0, 94, 'Pond Frog'), (142, 94, 'Honey Bear'),
        (-78, 182, 'Sky Bird'), (78, 182, 'Moon Cat')]
PEGS = [(-75, -24, 2), (6, 20, 1), (75, -32, 3)]
LIMIT = {'gallery': 5, 'rings': 3, 'golf_local': 1, 'golf_online': 1}
PRICES = dict.fromkeys(LIMIT, 10)


def latest(conn, player, game):
    return conn.execute('''SELECT * FROM trainer_backend.festival_rounds WHERE player_id=%s AND game=%s
        ORDER BY started_at DESC LIMIT 1''', (player, game)).fetchone()


def view(player, game, row):
    return {'player_id': player, 'game': game, 'price': PRICES[game], 'limit': LIMIT[game],
            'payments_available': policy.PAYMENTS_AVAILABLE, 'round': None if not row else
            {k: row[k] for k in ('id', 'operation_id', 'price', 'attempts', 'complete', 'prize')}}


def status(service, token, game):
    with service.db.transaction() as conn:
        player = service.progression.account(conn, token).player_id
        return view(player, game, latest(conn, player, game))


def enter(service, token, game, operation, expected):
    with service.db.transaction() as conn:
        player = service.progression.account(conn, token).player_id
        wallet = conn.execute('SELECT balance FROM trainer_backend.progression_accounts WHERE player_id=%s FOR UPDATE',
                              (player,)).fetchone()
        prior = conn.execute('SELECT * FROM trainer_backend.festival_rounds WHERE player_id=%s AND operation_id=%s',
                             (player, operation)).fetchone()
        if prior:
            if prior['game'] != game or prior['price'] != expected:
                raise AuthError('ticket_conflict', 409)
            return view(player, game, prior)
        if not policy.PAYMENTS_AVAILABLE:
            raise AuthError('market_closed', 409)
        if expected != PRICES[game]:
            raise AuthError('offer_changed', 409)
        prior = latest(conn, player, game)
        if prior and not prior['complete']:
            raise AuthError('ticket_already_open', 409)
        if not wallet or wallet['balance'] < expected:
            raise AuthError('insufficient_sparks', 409)
        row = conn.execute('''INSERT INTO trainer_backend.festival_rounds(id,player_id,operation_id,game,price)
            VALUES(%s,%s,%s,%s,%s) RETURNING *''', (uuid4(), player, operation, game, expected)).fetchone()
        conn.execute('''INSERT INTO trainer_backend.reward_ledger(id,player_id,source,event_id,title,xp,sparks,base_sparks,policy,earned_at,festival_id)
            VALUES(%s,%s,'festival.entry',%s,%s,0,%s,0,'festival-v1',clock_timestamp(),%s)''',
                     (uuid4(), player, str(row['id']), 'Festival Park · '+game, -expected, row['id']))
        conn.execute('UPDATE trainer_backend.progression_accounts SET balance=balance-%s,revision=revision+1 WHERE player_id=%s',
                     (expected, player))
        return view(player, game, row)


def attempt(service, token, game, ticket, index, x, y):
    with service.db.transaction() as conn:
        player = service.progression.account(conn, token).player_id
        row = conn.execute('SELECT * FROM trainer_backend.festival_rounds WHERE id=%s AND player_id=%s AND game=%s FOR UPDATE',
                           (ticket, player, game)).fetchone()
        if not row:
            raise AuthError('ticket_not_found', 404)
        shots = row['attempts']
        if index < len(shots) and (shots[index]['x'], shots[index]['y']) == (x, y):
            return view(player, game, row)
        if index != len(shots) or row['complete']:
            raise AuthError('round_changed', 409)
        target, points, prize = -1, 0, row['prize']
        if game == 'gallery':
            down = {s['target'] for s in shots if s['target'] >= 0}
            for i, (cx, cy, name) in enumerate(TOYS):
                if i not in down and ((x-cx)/25)**2 + ((y-cy)/30)**2 <= 1:
                    target, points = i, 1
                    if len(down) == 2:
                        prize = name
                    break
        elif game == 'rings':
            for i, (cx, cy, award) in enumerate(PEGS):
                if (x-cx)**2 + (y-cy)**2 <= 9**2:
                    target, points = i, award
                    break
        elif x or y:
            raise AuthError('invalid_round', 422)
        shots.append({'x': x, 'y': y, 'target': target, 'points': points})
        updated = conn.execute('''UPDATE trainer_backend.festival_rounds SET attempts=%s,complete=%s,prize=%s
            WHERE id=%s RETURNING *''', (Jsonb(shots), len(shots)==LIMIT[game], prize, ticket)).fetchone()
        return view(player, game, updated)
