# SPDX-License-Identifier: GPL-3.0-or-later
"""Explicit operator registration, not an HTTP/SDK privilege or wallet grant."""
import json
from pathlib import Path
from uuid import UUID, uuid4
import psycopg
from psycopg.rows import dict_row


def register(database_url, manifest):
    data=json.loads(Path(manifest).read_text())
    if set(data)!={'world_key','owner_id','expected_fluxer_subject','name'} or data['world_key']!='festival':
        raise ValueError('invalid_world_manifest')
    owner=UUID(data['owner_id']);name=data['name'];subject=data['expected_fluxer_subject']
    if not isinstance(name,str) or not 1<=len(name.strip())<=48 or any(ord(c)<32 or ord(c)==127 for c in name):raise ValueError('invalid_name')
    if not isinstance(subject,str) or not subject.isascii() or not subject.isdigit():raise ValueError('invalid_subject')
    with psycopg.connect(database_url,row_factory=dict_row,options='-c statement_timeout=15000 -c lock_timeout=5000') as conn:
        conn.execute("SELECT pg_advisory_xact_lock(hashtextextended('traineros:official-festival',0))")
        identity=conn.execute('''SELECT e.player_id FROM trainer_backend.external_identities e
            JOIN trainer_backend.principals p ON p.id=e.player_id WHERE e.player_id=%s AND e.provider='fluxer'
            AND e.instance='https://fluxer.app' AND e.subject=%s AND p.kind='player' AND p.state='active' FOR SHARE OF e,p''',(owner,subject)).fetchone()
        if not identity:raise ValueError('owner_identity_mismatch')
        prior=conn.execute('''SELECT b.* FROM trainer_backend.bazaar_worlds w JOIN trainer_backend.bazaars b ON b.id=w.bazaar_id
            WHERE w.world_key='festival' ''').fetchone()
        if prior:
            if prior['owner_id']!=owner or prior['kind']!='official':raise ValueError('world_owner_conflict')
            return prior['id']
        # The owner receives weekly rent through the normal account/ledger path.
        conn.execute('INSERT INTO trainer_backend.progression_accounts(player_id) VALUES(%s) ON CONFLICT DO NOTHING',(owner,))
        bid=uuid4()
        conn.execute("INSERT INTO trainer_backend.bazaars(id,owner_id,kind,offer_id,name) VALUES(%s,%s,'official',NULL,%s)",(bid,owner,name.strip()))
        conn.execute("INSERT INTO trainer_backend.bazaar_worlds VALUES('festival',%s)",(bid,))
        for slot in range(1,13):
            place=uuid4()
            conn.execute('INSERT INTO trainer_backend.bazaar_places(id,bazaar_id,name) VALUES(%s,%s,%s)',(place,bid,f'Festival stall {slot:02d}'))
            conn.execute("INSERT INTO trainer_backend.bazaar_world_places VALUES('festival',%s,%s)",(slot,place))
        conn.execute("INSERT INTO trainer_backend.audit_events(id,actor_id,action,resource_id) VALUES(%s,%s,'bazaar.official_registered',%s)",(uuid4(),owner,bid))
        return bid
