# SPDX-License-Identifier: GPL-3.0-or-later
"""Trade already-custodied profile items; never accept adapter payloads or mint goods.

Lock order: progression accounts (UUID order), bazaar, place, listing, loot.
Receipt identity is checked before the development gate, so recovery survives it.
"""
from uuid import uuid4
from . import policy, rentals
from ..accounts.provider import AuthError
from ..inventory import Presentation

SPECIES = ('Casual_Female','Casual_Male','Chef_Female','Kimono_Female','OldClassy_Male',
           'Wizard','Witch','Bunny','Yeti','Dino','Frog','Birb')
SELLER_PRICE = 100


def enabled():
    if not policy.PAYMENTS_AVAILABLE:
        raise AuthError('bazaar_under_development',409)


def accounts(conn, players):
    return conn.execute('SELECT * FROM trainer_backend.progression_accounts WHERE player_id=ANY(%s) ORDER BY player_id FOR UPDATE',
                        (list(set(players)),)).fetchall()


def lease(conn, actor, rental_id, *, active=True):
    row=conn.execute('''SELECT r.*,p.bazaar_id FROM trainer_backend.bazaar_rentals r
        JOIN trainer_backend.bazaar_places p ON p.id=r.place_id WHERE r.id=%s''',(rental_id,)).fetchone()
    if not row or row['tenant_id']!=actor.player_id:raise AuthError('rental_not_found',404)
    if active:
        access(conn,actor,row['bazaar_id'])
    conn.execute('SELECT id FROM trainer_backend.bazaar_places WHERE id=%s FOR UPDATE',(row['place_id'],))
    if active and row['expires_at']<=conn.execute('SELECT clock_timestamp() now').fetchone()['now']:
        raise AuthError('rental_expired',409)
    return row


def access(conn, actor, bazaar_id):
    bazaar=rentals.visible(conn,actor,bazaar_id)
    if bazaar['access']!='open' or conn.execute('SELECT 1 FROM trainer_backend.bazaar_blocks WHERE bazaar_id=%s AND player_id=%s',
                                             (bazaar_id,actor.player_id)).fetchone():
        raise AuthError('bazaar_access_denied',409)


def prior(conn, actor, operation, identity):
    row=conn.execute('SELECT * FROM trainer_backend.bazaar_trades WHERE buyer_id=%s AND operation_id=%s',
                     (actor.player_id,operation)).fetchone()
    if row and any(row[k]!=v for k,v in identity.items()):raise AuthError('trade_identity_conflict',409)
    return row


def ledger(conn, trade, title):
    changes=[(trade['buyer_id'],'bazaar.seller' if trade['kind']=='seller' else 'bazaar.buy',-trade['price'])]
    if trade['seller_id']:changes.append((trade['seller_id'],'bazaar.sale',trade['price']))
    for player,source,amount in changes:
        conn.execute('''INSERT INTO trainer_backend.reward_ledger
            (id,player_id,source,event_id,title,xp,sparks,base_sparks,policy,earned_at,trade_id)
            VALUES(%s,%s,%s,%s,%s,0,%s,0,'bazaar-trade-v1',%s,%s)''',
            (uuid4(),player,source,str(trade['id']),title,amount,trade['created_at'],trade['id']))
        conn.execute('UPDATE trainer_backend.progression_accounts SET balance=balance+%s,revision=revision+1 WHERE player_id=%s',(amount,player))
    conn.execute('INSERT INTO trainer_backend.audit_events(id,actor_id,action,resource_id) VALUES(%s,%s,%s,%s)',
                 (uuid4(),trade['buyer_id'],'bazaar.'+trade['kind'],trade['id']))


def receipt(service, token, operation):
    with service.db.transaction() as conn:
        actor=service.progression.account(conn,token)
        row=conn.execute('SELECT * FROM trainer_backend.bazaar_trades WHERE buyer_id=%s AND operation_id=%s',(actor.player_id,operation)).fetchone()
        if not row:raise AuthError('trade_not_found',404)
        return {'player_id':actor.player_id,'receipt':row}


def hire(service, token, rental_id, operation, species, revision, expected_price):
    if species not in SPECIES:raise AuthError('invalid_seller',422)
    with service.db.transaction() as conn:
        actor=service.progression.account(conn,token)
        payer=accounts(conn,[actor.player_id])[0]
        identity={'kind':'seller','rental_id':rental_id,'species':species,'offer_revision':revision,'price':expected_price}
        old=prior(conn,actor,operation,identity)
        if old:return {'player_id':actor.player_id,'receipt':old}
        enabled()
        if revision!=1 or expected_price!=SELLER_PRICE:raise AuthError('offer_changed',409)
        lease(conn,actor,rental_id)
        if conn.execute('SELECT 1 FROM trainer_backend.bazaar_sellers WHERE rental_id=%s',(rental_id,)).fetchone():
            raise AuthError('seller_already_hired',409)
        if payer['balance']<expected_price:raise AuthError('insufficient_sparks',409)
        conn.execute('INSERT INTO trainer_backend.bazaar_sellers(rental_id,species) VALUES(%s,%s)',(rental_id,species))
        trade=conn.execute('''INSERT INTO trainer_backend.bazaar_trades
            (id,buyer_id,operation_id,kind,rental_id,species,offer_revision,price)
            VALUES(%s,%s,%s,'seller',%s,%s,%s,%s) RETURNING *''',
            (uuid4(),actor.player_id,operation,rental_id,species,revision,expected_price)).fetchone()
        ledger(conn,trade,'NPC seller · current rental')
        return {'player_id':actor.player_id,'receipt':trade}


def create_listing(service, token, rental_id, item_id, operation, price):
    with service.db.transaction() as conn:
        actor=service.progression.account(conn,token);accounts(conn,[actor.player_id])
        old=conn.execute('SELECT * FROM trainer_backend.bazaar_listings WHERE seller_id=%s AND operation_id=%s',(actor.player_id,operation)).fetchone()
        if old:
            if (old['rental_id'],old['item_id'],old['price'])!=(rental_id,item_id,price):raise AuthError('listing_identity_conflict',409)
            return {'player_id':actor.player_id,'listing':old}
        enabled();lease(conn,actor,rental_id)
        if not conn.execute('SELECT 1 FROM trainer_backend.bazaar_sellers WHERE rental_id=%s',(rental_id,)).fetchone():
            raise AuthError('seller_required',409)
        item=conn.execute('SELECT id,player_id,state FROM trainer_backend.loot_items WHERE id=%s FOR UPDATE',(item_id,)).fetchone()
        if not item or item['player_id']!=actor.player_id:raise AuthError('item_not_found',404)
        if item['state']!='stored':raise AuthError('item_unavailable',409)
        conn.execute("UPDATE trainer_backend.loot_items SET state='listed' WHERE id=%s",(item_id,))
        row=conn.execute('''INSERT INTO trainer_backend.bazaar_listings(id,rental_id,seller_id,item_id,operation_id,price)
            VALUES(%s,%s,%s,%s,%s,%s) RETURNING *''',(uuid4(),rental_id,actor.player_id,item_id,operation,price)).fetchone()
        return {'player_id':actor.player_id,'listing':row}


def withdraw(service, token, listing_id, revision):
    # Always available to the owner, even after expiry, blocking or payments closing.
    with service.db.transaction() as conn:
        actor=service.progression.account(conn,token);accounts(conn,[actor.player_id])
        row=conn.execute('SELECT * FROM trainer_backend.bazaar_listings WHERE id=%s AND seller_id=%s',(listing_id,actor.player_id)).fetchone()
        if not row:raise AuthError('listing_not_found',404)
        lease(conn,actor,row['rental_id'],active=False)
        row=conn.execute('SELECT * FROM trainer_backend.bazaar_listings WHERE id=%s FOR UPDATE',(listing_id,)).fetchone()
        if row['state']=='withdrawn':return {'player_id':actor.player_id,'listing':row}
        if row['state']!='listed' or row['revision']!=revision:raise AuthError('listing_changed',409)
        item=conn.execute('SELECT player_id,state FROM trainer_backend.loot_items WHERE id=%s FOR UPDATE',(row['item_id'],)).fetchone()
        if item['player_id']!=actor.player_id or item['state']!='listed':raise AuthError('item_unavailable',409)
        conn.execute("UPDATE trainer_backend.loot_items SET state='stored' WHERE id=%s",(row['item_id'],))
        row=conn.execute("UPDATE trainer_backend.bazaar_listings SET state='withdrawn',revision=revision+1 WHERE id=%s RETURNING *",(listing_id,)).fetchone()
        return {'player_id':actor.player_id,'listing':row}


def listings(service, token, place_id=None, after=None):
    with service.db.transaction() as conn:
        actor=service.progression.account(conn,token)
        if place_id:
            place=conn.execute('SELECT bazaar_id FROM trainer_backend.bazaar_places WHERE id=%s',(place_id,)).fetchone()
            if not place:raise AuthError('place_not_found',404)
            access(conn,actor,place['bazaar_id'])
        rows=conn.execute('''SELECT l.*,r.expires_at,r.place_id,i.presentation,i.game_id,i.kind
            FROM trainer_backend.bazaar_listings l JOIN trainer_backend.bazaar_rentals r ON r.id=l.rental_id
            JOIN trainer_backend.loot_items i ON i.id=l.item_id
            WHERE (%s::uuid IS NULL AND l.seller_id=%s OR r.place_id=%s AND l.state='listed' AND r.expires_at>clock_timestamp())
            AND (%s::uuid IS NULL OR l.id>%s) ORDER BY l.id LIMIT 25''',(place_id,actor.player_id,place_id,after,after)).fetchall()
        items=[]
        for row in rows[:24]:
            # Never expose payload or the seller's private operation identity.
            value={k:row[k] for k in ('id','rental_id','seller_id','item_id','price','revision','state','expires_at','place_id','game_id','kind')}
            value['presentation']=Presentation.model_validate(row['presentation']).model_dump(exclude_none=True)
            items.append(value)
        return {'player_id':actor.player_id,'items':items,'next':str(rows[23]['id']) if len(rows)>24 else None,
                'payments_available':policy.PAYMENTS_AVAILABLE}


def buy(service, token, listing_id, operation, revision, expected_price):
    with service.db.transaction() as conn:
        actor=service.progression.account(conn,token)
        listing=conn.execute('SELECT * FROM trainer_backend.bazaar_listings WHERE id=%s',(listing_id,)).fetchone()
        if not listing:raise AuthError('listing_not_found',404)
        locked=accounts(conn,[actor.player_id,listing['seller_id']])
        identity={'kind':'loot','listing_id':listing_id,'offer_revision':revision,'price':expected_price}
        old=prior(conn,actor,operation,identity)
        if old:return {'player_id':actor.player_id,'receipt':old}
        enabled()
        if actor.player_id==listing['seller_id']:raise AuthError('own_listing',409)
        rental=conn.execute('''SELECT r.*,p.bazaar_id FROM trainer_backend.bazaar_rentals r
            JOIN trainer_backend.bazaar_places p ON p.id=r.place_id WHERE r.id=%s''',(listing['rental_id'],)).fetchone()
        access(conn,actor,rental['bazaar_id'])
        # A blocked seller's goods cannot still be sold by a stale storefront.
        if conn.execute('SELECT 1 FROM trainer_backend.bazaar_blocks WHERE bazaar_id=%s AND player_id=%s',
                        (rental['bazaar_id'],listing['seller_id'])).fetchone():raise AuthError('listing_unavailable',409)
        conn.execute('SELECT id FROM trainer_backend.bazaar_places WHERE id=%s FOR UPDATE',(rental['place_id'],))
        if rental['expires_at']<=conn.execute('SELECT clock_timestamp() now').fetchone()['now']:raise AuthError('rental_expired',409)
        row=conn.execute('SELECT * FROM trainer_backend.bazaar_listings WHERE id=%s FOR UPDATE',(listing_id,)).fetchone()
        if (row['state'],row['revision'],row['price'])!=('listed',revision,expected_price):raise AuthError('listing_changed',409)
        item=conn.execute('SELECT * FROM trainer_backend.loot_items WHERE id=%s FOR UPDATE',(row['item_id'],)).fetchone()
        if item['player_id']!=row['seller_id'] or item['state']!='listed':raise AuthError('item_unavailable',409)
        payer=next(r for r in locked if r['player_id']==actor.player_id)
        if payer['balance']<expected_price:raise AuthError('insufficient_sparks',409)
        payee=next(r for r in locked if r['player_id']==row['seller_id'])
        if payee['balance']>9007199254740991-expected_price:raise AuthError('balance_limit',409)
        trade=conn.execute('''INSERT INTO trainer_backend.bazaar_trades
            (id,buyer_id,operation_id,kind,listing_id,seller_id,item_id,offer_revision,price)
            VALUES(%s,%s,%s,'loot',%s,%s,%s,%s,%s) RETURNING *''',
            (uuid4(),actor.player_id,operation,listing_id,row['seller_id'],row['item_id'],revision,expected_price)).fetchone()
        conn.execute("UPDATE trainer_backend.loot_items SET player_id=%s,state='stored' WHERE id=%s",(actor.player_id,row['item_id']))
        conn.execute("UPDATE trainer_backend.bazaar_listings SET state='sold',revision=revision+1 WHERE id=%s",(listing_id,))
        ledger(conn,trade,Presentation.model_validate(item['presentation']).title)
        return {'player_id':actor.player_id,'receipt':trade}


def world(service, token, key):
    with service.db.transaction() as conn:
        actor=service.progression.account(conn,token)
        bound=conn.execute('SELECT bazaar_id FROM trainer_backend.bazaar_worlds WHERE world_key=%s',(key,)).fetchone()
        if not bound:raise AuthError('world_not_configured',409)
        access(conn,actor,bound['bazaar_id'])
        rows=conn.execute('''SELECT w.slot,p.id,p.name,p.weekly_price,p.revision,r.id AS rental_id,r.tenant_id,r.expires_at,s.species
            FROM trainer_backend.bazaar_world_places w JOIN trainer_backend.bazaar_places p ON p.id=w.place_id
            LEFT JOIN LATERAL (SELECT * FROM trainer_backend.bazaar_rentals WHERE place_id=p.id AND expires_at>clock_timestamp()
                ORDER BY expires_at DESC LIMIT 1) r ON true
            LEFT JOIN trainer_backend.bazaar_sellers s ON s.rental_id=r.id
            WHERE w.world_key=%s AND p.bazaar_id=%s ORDER BY w.slot''',(key,bound['bazaar_id'])).fetchall()
        owner=conn.execute('SELECT owner_id FROM trainer_backend.bazaars WHERE id=%s',(bound['bazaar_id'],)).fetchone()['owner_id']
        return {'player_id':actor.player_id,'bazaar_id':bound['bazaar_id'],'owner_id':owner,'places':rows,
                'payments_available':policy.PAYMENTS_AVAILABLE,'seller_price':SELLER_PRICE,'seller_revision':1}
