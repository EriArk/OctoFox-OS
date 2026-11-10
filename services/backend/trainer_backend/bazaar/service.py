# SPDX-License-Identifier: GPL-3.0-or-later
"""Persistent catalogue/owner settings. No realtime membership or host authority."""
from uuid import UUID, uuid4
from ..accounts.provider import AuthError
from ..events import EventSpec, publish


def details(value):
    if (not isinstance(value, dict) or not {'name','description','listed','access'} <= set(value)
            or set(value) - {'name','description','listed','access','cover','badge'}):
        raise AuthError('invalid_bazaar', 422)
    if (('cover' in value and value['cover'] not in ('market','grove','harbor'))
            or ('badge' in value and value['badge'] not in ('shop','community','companion','trophy','guide'))):
        raise AuthError('invalid_bazaar', 422)
    name, description = value['name'], value['description']
    if (not isinstance(name, str) or not 1 <= len(name.strip()) <= 48 or len(name) > 48
            or not isinstance(description, str) or len(description) > 280
            or any(ord(c) < 32 or ord(c) == 127 for c in name + description)
            or type(value['listed']) is not bool or value['access'] not in ('open', 'closed')):
        raise AuthError('invalid_bazaar', 422)
    return {**value, 'name': name.strip(), 'description': description.strip()}


def validate_event(value):
    if set(value) != {'bazaar_id', 'owner_id'} or not all(isinstance(v, str) for v in value.values()):
        raise ValueError('invalid_bazaar_event')


CHANGED = EventSpec('inventory.bazaar_changed', 'inventory', validate_event)


def owned(conn, owner):
    return conn.execute('SELECT * FROM trainer_backend.bazaars WHERE owner_id=%s', (owner,)).fetchone()


def create_owned(conn, owner, value):
    value = details(value)
    row = conn.execute('''INSERT INTO trainer_backend.bazaars(id,owner_id,name,description,listed,access,cover,badge)
        VALUES(%s,%s,%s,%s,%s,%s,%s,%s) RETURNING *''',
        (uuid4(), owner, value['name'], value['description'], value['listed'], value['access'],value.get('cover','market'),value.get('badge','shop'))).fetchone()
    publish(conn, CHANGED, uuid4(), row['id'], row['revision'], {'bazaar_id': str(row['id']), 'owner_id': str(owner)})
    return row


class Bazaars:
    def __init__(self, progression):
        self.progression, self.db = progression, progression.db

    def create(self, access, value):
        value = details(value)
        with self.db.transaction() as conn:
            actor = self.progression.account(conn, access)
            # Same account lock as purchases: one permanent right, one space.
            conn.execute('SELECT revision FROM trainer_backend.progression_accounts WHERE player_id=%s FOR UPDATE', (actor.player_id,)).fetchone()
            if not conn.execute("SELECT 1 FROM trainer_backend.owned_items WHERE player_id=%s AND offer_id='bazaar.personal'", (actor.player_id,)).fetchone():
                raise AuthError('bazaar_license_required', 409)
            row = owned(conn, actor.player_id)
            if not row:
                row = create_owned(conn, actor.player_id, value)
                conn.execute('INSERT INTO trainer_backend.audit_events(id,actor_id,action,resource_id) VALUES(%s,%s,%s,%s)',
                             (uuid4(), actor.player_id, 'inventory.bazaar_created', row['id']))
            # Retrying a lost response returns the existing space, never edits it.
            return {'player_id': actor.player_id, 'bazaar_license': True, 'bazaar': row}

    def directory(self, access, search='', after=None, favorites=None):
        with self.db.transaction() as conn:
            actor = self.progression.account(conn, access)
            rows = conn.execute('''SELECT b.*,COALESCE(p.display_name,'Player') AS owner_name
                FROM trainer_backend.bazaars b LEFT JOIN trainer_backend.public_profiles p ON p.player_id=b.owner_id
                WHERE (b.listed OR b.owner_id=%s) AND (%s::uuid IS NULL OR b.id>%s)
                AND strpos(lower(b.name || ' ' || COALESCE(p.display_name,'')),lower(%s))>0
                AND (%s::uuid[] IS NULL OR b.id=ANY(%s::uuid[])) ORDER BY b.id LIMIT 25''',
                (actor.player_id, after, after, search, favorites, favorites)).fetchall()
            return {'player_id': actor.player_id, 'items': [self.card(r, actor.player_id) for r in rows[:24]],
                    'next': str(rows[23]['id']) if len(rows)>24 else None,
                    'join_available': False}

    @staticmethod
    def card(row, viewer):
        return {**row, 'owned': row['owner_id']==viewer, 'join_available': False, 'visitors': None}

    def update(self, access, bazaar_id, revision, value):
        value = details(value)
        with self.db.transaction() as conn:
            actor = self.progression.account(conn, access)
            row = conn.execute('SELECT * FROM trainer_backend.bazaars WHERE id=%s AND owner_id=%s FOR UPDATE',
                               (bazaar_id, actor.player_id)).fetchone()
            if not row:
                raise AuthError('bazaar_not_found', 404)
            if any(row[key] != value[key] for key in value):
                if row['revision'] != revision:
                    raise AuthError('bazaar_changed', 409)
                row = conn.execute('''UPDATE trainer_backend.bazaars SET name=%s,description=%s,listed=%s,access=%s,cover=%s,badge=%s,
                    revision=revision+1,updated_at=clock_timestamp() WHERE id=%s RETURNING *''',
                    (value['name'],value['description'],value['listed'],value['access'],value.get('cover',row['cover']),value.get('badge',row['badge']),bazaar_id)).fetchone()
                conn.execute('INSERT INTO trainer_backend.audit_events(id,actor_id,action,resource_id) VALUES(%s,%s,%s,%s)',
                             (uuid4(), actor.player_id, 'inventory.bazaar_updated', bazaar_id))
                publish(conn, CHANGED, uuid4(), row['id'], row['revision'],
                        {'bazaar_id': str(row['id']), 'owner_id': str(actor.player_id)})
            return {'player_id': actor.player_id, 'bazaar': row}

    @staticmethod
    def _owner(conn, actor, bazaar_id, lock='SHARE'):
        # lock is selected by trusted module code, never a request field.
        row=conn.execute('SELECT * FROM trainer_backend.bazaars WHERE id=%s AND owner_id=%s FOR '+lock,
                         (bazaar_id,actor.player_id)).fetchone()
        if not row:raise AuthError('bazaar_not_found',404)
        return row

    def access_settings(self, access, bazaar_id, after=None, target=None):
        with self.db.transaction() as conn:
            actor=self.progression.account(conn,access)
            row=self._owner(conn,actor,bazaar_id)
            rows=conn.execute('''SELECT b.player_id,COALESCE(p.display_name,'Player') AS name
                FROM trainer_backend.bazaar_blocks b LEFT JOIN trainer_backend.public_profiles p ON p.player_id=b.player_id
                WHERE b.bazaar_id=%s AND (%s::uuid IS NULL OR b.player_id>%s) ORDER BY b.player_id LIMIT 101''',
                (bazaar_id,after,after)).fetchall()
            selected=None
            if target:
                person=conn.execute('''SELECT u.id AS player_id,COALESCE(p.display_name,'Player') AS name
                    FROM trainer_backend.players u LEFT JOIN trainer_backend.public_profiles p ON p.player_id=u.id
                    WHERE u.id=%s''',(target,)).fetchone()
                if not person:raise AuthError('profile_not_found',404)
                selected={**person,'blocked':bool(conn.execute('SELECT 1 FROM trainer_backend.bazaar_blocks WHERE bazaar_id=%s AND player_id=%s',(bazaar_id,target)).fetchone())}
            return {'player_id':actor.player_id,'bazaar_license':True,'bazaar':row,'blocks':rows[:100],
                    'next':str(rows[99]['player_id']) if len(rows)>100 else None,'target':selected,'live_moderation':False}

    def block(self, access, bazaar_id, player_id, blocked, revision):
        if type(blocked) is not bool:raise AuthError('invalid_request',422)
        with self.db.transaction() as conn:
            actor=self.progression.account(conn,access)
            row=self._owner(conn,actor,bazaar_id,'UPDATE')
            if player_id==actor.player_id:raise AuthError('bazaar_owner_cannot_be_blocked',409)
            if not conn.execute('SELECT 1 FROM trainer_backend.players WHERE id=%s',(player_id,)).fetchone():
                raise AuthError('profile_not_found',404)
            current=bool(conn.execute('SELECT 1 FROM trainer_backend.bazaar_blocks WHERE bazaar_id=%s AND player_id=%s',(bazaar_id,player_id)).fetchone())
            if current!=blocked:
                if row['revision']!=revision:raise AuthError('bazaar_changed',409)
                if blocked:conn.execute('INSERT INTO trainer_backend.bazaar_blocks(bazaar_id,player_id) VALUES(%s,%s)',(bazaar_id,player_id))
                else:conn.execute('DELETE FROM trainer_backend.bazaar_blocks WHERE bazaar_id=%s AND player_id=%s',(bazaar_id,player_id))
                row=conn.execute('UPDATE trainer_backend.bazaars SET revision=revision+1,updated_at=clock_timestamp() WHERE id=%s RETURNING *',(bazaar_id,)).fetchone()
                conn.execute('INSERT INTO trainer_backend.audit_events(id,actor_id,action,resource_id) VALUES(%s,%s,%s,%s)',
                             (uuid4(),actor.player_id,'inventory.bazaar_blocked' if blocked else 'inventory.bazaar_unblocked',player_id))
                publish(conn,CHANGED,uuid4(),row['id'],row['revision'],{'bazaar_id':str(row['id']),'owner_id':str(actor.player_id)})
            return {'player_id':actor.player_id,'bazaar_license':True,'bazaar':row,'target':{'player_id':player_id,'blocked':blocked},'live_moderation':False}

    def access_policy(self, access, bazaar_id):
        # A current policy read is not admission, a reservation, or a host lease.
        with self.db.transaction() as conn:
            actor=self.progression.account(conn,access)
            row=conn.execute('SELECT * FROM trainer_backend.bazaars WHERE id=%s AND (listed OR owner_id=%s) FOR SHARE',(bazaar_id,actor.player_id)).fetchone()
            if not row:raise AuthError('bazaar_not_found',404)
            owner=row['owner_id']==actor.player_id
            blocked=bool(conn.execute('SELECT 1 FROM trainer_backend.bazaar_blocks WHERE bazaar_id=%s AND player_id=%s',(bazaar_id,actor.player_id)).fetchone())
            reason='owner' if owner else 'blocked' if blocked else 'closed' if row['access']=='closed' else 'open'
            return {'bazaar_id':row['id'],'revision':row['revision'],'policy_allows':reason in ('owner','open'),
                    'reason':reason,'join_available':False}
