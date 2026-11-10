# SPDX-License-Identifier: GPL-3.0-or-later
"""Persistent catalogue/owner settings. No realtime membership or host authority."""
from uuid import UUID, uuid4
from ..accounts.provider import AuthError
from ..events import EventSpec, publish


def details(value):
    if not isinstance(value, dict) or set(value) != {'name', 'description', 'listed', 'access'}:
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
    row = conn.execute('''INSERT INTO trainer_backend.bazaars(id,owner_id,name,description,listed,access)
        VALUES(%s,%s,%s,%s,%s,%s) RETURNING *''',
        (uuid4(), owner, value['name'], value['description'], value['listed'], value['access'])).fetchone()
    publish(conn, CHANGED, uuid4(), row['id'], row['revision'], {'bazaar_id': str(row['id']), 'owner_id': str(owner)})
    return row


class Bazaars:
    def __init__(self, progression):
        self.progression, self.db = progression, progression.db

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
                row = conn.execute('''UPDATE trainer_backend.bazaars SET name=%s,description=%s,listed=%s,access=%s,
                    revision=revision+1,updated_at=clock_timestamp() WHERE id=%s RETURNING *''',
                    (value['name'],value['description'],value['listed'],value['access'],bazaar_id)).fetchone()
                conn.execute('INSERT INTO trainer_backend.audit_events(id,actor_id,action,resource_id) VALUES(%s,%s,%s,%s)',
                             (uuid4(), actor.player_id, 'inventory.bazaar_updated', bazaar_id))
                publish(conn, CHANGED, uuid4(), row['id'], row['revision'],
                        {'bazaar_id': str(row['id']), 'owner_id': str(actor.player_id)})
            return {'player_id': actor.player_id, 'bazaar': row}
