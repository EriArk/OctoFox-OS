# SPDX-License-Identifier: GPL-3.0-or-later
"""Weekly places, paid atomically through the existing progression ledger.

No custody of goods, automatic renewal, refunds or runtime place provisioning.
An expired receipt remains history; occupancy is derived from the server clock.
"""
from uuid import uuid4
from datetime import timedelta
from ..accounts.provider import AuthError
from ..events import EventSpec, publish


def validate_event(value):
    if set(value) != {'place_id','bazaar_id'} or not all(isinstance(v,str) for v in value.values()):
        raise ValueError('invalid_rental_event')


CHANGED = EventSpec('inventory.bazaar_place_changed','inventory',validate_event)


def changed(conn, actor, place, action):
    conn.execute('INSERT INTO trainer_backend.audit_events(id,actor_id,action,resource_id) VALUES(%s,%s,%s,%s)',
                 (uuid4(),actor.player_id,action,place['id']))
    publish(conn,CHANGED,uuid4(),place['id'],place['revision'],
            {'place_id':str(place['id']),'bazaar_id':str(place['bazaar_id'])})


def visible(conn, actor, bazaar_id):
    row=conn.execute('SELECT * FROM trainer_backend.bazaars WHERE id=%s AND (listed OR owner_id=%s) FOR SHARE',
                     (bazaar_id,actor.player_id)).fetchone()
    if not row:raise AuthError('bazaar_not_found',404)
    return row


def places(service, access, bazaar_id, after=None):
    with service.db.transaction() as conn:
        actor=service.progression.account(conn,access)
        bazaar=visible(conn,actor,bazaar_id)
        blocked=bool(conn.execute('SELECT 1 FROM trainer_backend.bazaar_blocks WHERE bazaar_id=%s AND player_id=%s',
                                 (bazaar_id,actor.player_id)).fetchone())
        allowed=bazaar['access']=='open' and not blocked and bazaar['owner_id']!=actor.player_id
        rows=conn.execute('''SELECT p.*,r.tenant_id,r.expires_at FROM trainer_backend.bazaar_places p
            LEFT JOIN LATERAL (SELECT tenant_id,expires_at FROM trainer_backend.bazaar_rentals
                WHERE place_id=p.id AND expires_at>clock_timestamp() ORDER BY expires_at DESC LIMIT 1) r ON true
            WHERE p.bazaar_id=%s AND (%s::uuid IS NULL OR p.id>%s) ORDER BY p.id LIMIT 25''',
            (bazaar_id,after,after)).fetchall()
        return {'player_id':actor.player_id,'bazaar_id':bazaar_id,'owned':bazaar['owner_id']==actor.player_id,
                'items':[{**r,'rentable':allowed and r['weekly_price'] is not None and r['tenant_id'] is None} for r in rows[:24]],
                'next':str(rows[23]['id']) if len(rows)>24 else None}


def price(service, access, bazaar_id, place_id, revision, weekly_price):
    with service.db.transaction() as conn:
        actor=service.progression.account(conn,access)
        service._owner(conn,actor,bazaar_id)
        row=conn.execute('SELECT * FROM trainer_backend.bazaar_places WHERE id=%s AND bazaar_id=%s FOR UPDATE',
                         (place_id,bazaar_id)).fetchone()
        if not row:raise AuthError('place_not_found',404)
        if row['weekly_price']!=weekly_price:
            if row['revision']!=revision:raise AuthError('place_changed',409)
            row=conn.execute('UPDATE trainer_backend.bazaar_places SET weekly_price=%s,revision=revision+1 WHERE id=%s RETURNING *',
                             (weekly_price,place_id)).fetchone()
            changed(conn,actor,row,'bazaar.place_price')
        return {'player_id':actor.player_id,'place':row}


def receipt(service, access, operation):
    with service.db.transaction() as conn:
        actor=service.progression.account(conn,access)
        row=conn.execute('SELECT * FROM trainer_backend.bazaar_rentals WHERE tenant_id=%s AND operation_id=%s',
                         (actor.player_id,operation)).fetchone()
        if not row:raise AuthError('rental_not_found',404)
        return {'player_id':actor.player_id,'receipt':row}


def rent(service, access, operation, bazaar_id, place_id, revision, expected_price):
    with service.db.transaction() as conn:
        actor=service.progression.account(conn,access)
        # Read immutable ownership, then lock accounts in UUID order. Never hold a
        # place/bazaar lock while waiting for an account (creation locks account first).
        owner=conn.execute('SELECT owner_id FROM trainer_backend.bazaars WHERE id=%s',(bazaar_id,)).fetchone()
        if not owner:raise AuthError('bazaar_not_found',404)
        accounts=conn.execute('SELECT * FROM trainer_backend.progression_accounts WHERE player_id=ANY(%s) ORDER BY player_id FOR UPDATE',
                              ([actor.player_id,owner['owner_id']],)).fetchall()
        prior=conn.execute('''SELECT r.*,p.bazaar_id FROM trainer_backend.bazaar_rentals r
            JOIN trainer_backend.bazaar_places p ON p.id=r.place_id WHERE r.tenant_id=%s AND r.operation_id=%s''',
            (actor.player_id,operation)).fetchone()
        if prior:
            if (prior['bazaar_id'],prior['place_id'],prior['offer_revision'],prior['price']) != (bazaar_id,place_id,revision,expected_price):
                raise AuthError('rental_identity_conflict',409)
            return {'player_id':actor.player_id,'receipt':prior}
        bazaar=visible(conn,actor,bazaar_id)
        if bazaar['owner_id']==actor.player_id:raise AuthError('own_place',409)
        if bazaar['access']!='open' or conn.execute('SELECT 1 FROM trainer_backend.bazaar_blocks WHERE bazaar_id=%s AND player_id=%s',
                                                   (bazaar_id,actor.player_id)).fetchone():
            raise AuthError('bazaar_access_denied',409)
        place=conn.execute('SELECT * FROM trainer_backend.bazaar_places WHERE id=%s AND bazaar_id=%s FOR UPDATE',
                           (place_id,bazaar_id)).fetchone()
        if not place:raise AuthError('place_not_found',404)
        if (place['revision'],place['weekly_price'])!=(revision,expected_price):raise AuthError('place_changed',409)
        now=conn.execute('SELECT clock_timestamp() AS now').fetchone()['now']
        if conn.execute('SELECT 1 FROM trainer_backend.bazaar_rentals WHERE place_id=%s AND expires_at>%s',(place_id,now)).fetchone():
            raise AuthError('place_occupied',409)
        payer=next(r for r in accounts if r['player_id']==actor.player_id)
        if payer['balance']<expected_price:raise AuthError('insufficient_sparks',409)
        rental=conn.execute('''INSERT INTO trainer_backend.bazaar_rentals
            (id,place_id,tenant_id,owner_id,operation_id,offer_revision,price,started_at,expires_at)
            VALUES(%s,%s,%s,%s,%s,%s,%s,%s,%s) RETURNING *''',
            (uuid4(),place_id,actor.player_id,bazaar['owner_id'],operation,revision,expected_price,now,now+timedelta(days=7))).fetchone()
        for player,source,amount in [(actor.player_id,'bazaar.rent',-expected_price),(bazaar['owner_id'],'bazaar.rent_income',expected_price)]:
            conn.execute('''INSERT INTO trainer_backend.reward_ledger
                (id,player_id,source,event_id,title,xp,sparks,base_sparks,policy,earned_at,rental_id)
                VALUES(%s,%s,%s,%s,%s,0,%s,0,'bazaar-week-v1',%s,%s)''',
                (uuid4(),player,source,str(rental['id']),place['name']+' · 7 days',amount,now,rental['id']))
            conn.execute('UPDATE trainer_backend.progression_accounts SET balance=balance+%s,revision=revision+1 WHERE player_id=%s',(amount,player))
        place=conn.execute('UPDATE trainer_backend.bazaar_places SET revision=revision+1 WHERE id=%s RETURNING *',(place_id,)).fetchone()
        changed(conn,actor,place,'bazaar.rent')
        return {'player_id':actor.player_id,'receipt':rental}
