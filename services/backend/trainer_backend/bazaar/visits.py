# SPDX-License-Identifier: GPL-3.0-or-later
"""Coordinate short-lived visits. Movement records travel over the peer channels."""
from ..accounts.provider import AuthError
from . import trading


def update(service, token, visit, *, leave=False, offers=None):
    with service.db.transaction() as conn:
        actor=service.progression.account(conn,token)
        venue=conn.execute("SELECT bazaar_id FROM trainer_backend.bazaar_worlds WHERE world_key='mika-island'").fetchone()
        if not venue:raise AuthError('world_not_configured',409)
        bazaar=venue['bazaar_id']
        conn.execute('SELECT pg_advisory_xact_lock(hashtextextended(%s,0))',(str(bazaar),))
        if not leave:trading.access(conn,actor,bazaar)
        conn.execute("""DELETE FROM trainer_backend.bazaar_visitors WHERE bazaar_id=%s AND
            (seen < clock_timestamp()-interval '18 seconds' OR player_id IN
            (SELECT player_id FROM trainer_backend.bazaar_blocks WHERE bazaar_id=%s))""",(bazaar,bazaar))
        if leave:
            conn.execute('DELETE FROM trainer_backend.bazaar_visitors WHERE bazaar_id=%s AND player_id=%s AND visit_id=%s',
                         (bazaar,actor.player_id,visit))
        else:
            current=conn.execute('SELECT visit_id FROM trainer_backend.bazaar_visitors WHERE bazaar_id=%s AND player_id=%s',
                                 (bazaar,actor.player_id)).fetchone()
            if current and current['visit_id']!=visit:raise AuthError('visit_in_use',409)
            if not current and conn.execute('SELECT count(*) n FROM trainer_backend.bazaar_visitors WHERE bazaar_id=%s',
                                            (bazaar,)).fetchone()['n']>=8:raise AuthError('island_full',409)
            conn.execute('''INSERT INTO trainer_backend.bazaar_visitors(bazaar_id,player_id,visit_id) VALUES(%s,%s,%s)
                ON CONFLICT(bazaar_id,player_id) DO UPDATE SET seen=clock_timestamp()''',(bazaar,actor.player_id,visit))
        members=conn.execute('''SELECT v.visit_id,p.display_name FROM trainer_backend.bazaar_visitors v
            JOIN trainer_backend.public_profiles p USING(player_id) WHERE bazaar_id=%s ORDER BY arrived,visit_id''',(bazaar,)).fetchall()
        host=members[0]['visit_id'] if members else None
        guests=[m['visit_id'] for m in members[1:]]
        conn.execute('''DELETE FROM trainer_backend.bazaar_peer_offers WHERE bazaar_id=%s AND
            (host_visit IS DISTINCT FROM %s OR NOT(guest_visit=ANY(%s::uuid[])))''',(bazaar,host,guests))
        if visit==host:
            for guest,code in (offers or {}).items():
                if guest in guests:
                    conn.execute('''INSERT INTO trainer_backend.bazaar_peer_offers VALUES(%s,%s,%s,%s)
                        ON CONFLICT(bazaar_id,host_visit,guest_visit) DO UPDATE SET code=excluded.code''',(bazaar,host,guest,code))
        invitation=None if leave else conn.execute('SELECT code FROM trainer_backend.bazaar_peer_offers WHERE bazaar_id=%s AND guest_visit=%s',
                                                  (bazaar,visit)).fetchone()
        return {'player_id':actor.player_id,'bazaar_id':bazaar,'members':members if not leave else [],
                'host':host,'code':invitation['code'] if invitation else None}
