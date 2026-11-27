# SPDX-License-Identifier: GPL-3.0-or-later
"""Trophy definitions belong to the operator. Games read the current player's view."""
import json
from pathlib import Path

import psycopg

from ..commands import CODE


def register(database_url, path):
    raw = Path(path).read_bytes()
    if len(raw) > 8192:
        raise ValueError('trophy_definition_too_large')
    row = json.loads(raw)
    if not isinstance(row, dict) or set(row) != {'game_id','id','title','shape','criterion','ruleset'}:
        raise ValueError('invalid_trophy_definition')
    if any(not isinstance(row[k], str) or not CODE.fullmatch(row[k]) for k in ('game_id','id')):
        raise ValueError('invalid_trophy_id')
    if row['game_id'].startswith('ra.') or not isinstance(row['title'], str) or not 1 <= len(row['title'].strip()) <= 100:
        raise ValueError('invalid_trophy_definition')
    if row['shape'] not in ('cup','medal','plaque') or row['criterion'] not in ('confirmed_win','verified_event'):
        raise ValueError('invalid_trophy_definition')
    ruleset = row['ruleset']
    if row['criterion'] == 'confirmed_win':
        if not isinstance(ruleset, str) or not CODE.fullmatch(ruleset):
            raise ValueError('invalid_trophy_ruleset')
    elif ruleset is not None:
        raise ValueError('invalid_trophy_ruleset')
    fields = (row['title'],row['shape'],row['criterion'],ruleset)
    key = (row['game_id'],row['id'])
    with psycopg.connect(database_url) as conn:
        if ruleset and not conn.execute('SELECT 1 FROM trainer_backend.game_rulesets WHERE id=%s AND game_id=%s',(ruleset,key[0])).fetchone():
            raise ValueError('trophy_ruleset_game_mismatch')
        conn.execute('INSERT INTO trainer_backend.game_trophies VALUES (%s,%s,%s,%s,%s,%s) ON CONFLICT DO NOTHING',key+fields)
        found = conn.execute('SELECT title,shape,criterion,ruleset_id FROM trainer_backend.game_trophies WHERE game_id=%s AND trophy_id=%s',key).fetchone()
        if found != fields:
            raise ValueError('immutable_trophy_conflict')
    return '/'.join(key)


def attest(conn, player, game, trophy, evidence):
    """Called inside a trusted validator's transaction after it verifies the event."""
    key = (game,trophy)
    if not conn.execute("SELECT 1 FROM trainer_backend.game_trophies WHERE game_id=%s AND trophy_id=%s AND criterion='verified_event'",key).fetchone():
        raise ValueError('unregistered_verified_trophy')
    conn.execute('''INSERT INTO trainer_backend.trophy_proofs(player_id,game_id,trophy_id,evidence_id)
        VALUES(%s,%s,%s,%s) ON CONFLICT DO NOTHING''',(player,game,trophy,evidence))


def withdraw(conn, player, game, trophy, evidence):
    conn.execute('''DELETE FROM trainer_backend.trophy_proofs WHERE player_id=%s AND game_id=%s
        AND trophy_id=%s AND evidence_id=%s''',(player,game,trophy,evidence))


def page(service, access, game, after, key, limit):
    with service.db.transaction() as conn:
        player = service.accounts.authenticate(conn,access).player_id
        rows = conn.execute('''
          WITH wins AS (
            SELECT DISTINCT m.ruleset_id FROM trainer_backend.match_participants p
            JOIN trainer_backend.matches m ON m.id=p.match_id AND m.state='confirmed'
            JOIN trainer_backend.result_outcomes o ON o.match_id=m.id AND o.outcome='won'
            WHERE p.player_id=%(player)s AND o.members ? %(member)s
          ), catalogue AS (
            SELECT d.game_id,d.trophy_id,d.title,d.shape,d.criterion,
              CASE WHEN d.criterion='confirmed_win' THEN w.ruleset_id IS NOT NULL
                   ELSE EXISTS(SELECT 1 FROM trainer_backend.trophy_proofs p WHERE p.player_id=%(player)s
                       AND p.game_id=d.game_id AND p.trophy_id=d.trophy_id) END AS earned
            FROM trainer_backend.game_trophies d LEFT JOIN wins w ON w.ruleset_id=d.ruleset_id
            UNION ALL
            SELECT 'ra.'||p.game_id,p.kind,min(p.title)||' · '||
              CASE p.kind WHEN 'beaten' THEN 'Beaten' WHEN 'completed' THEN 'Completed' ELSE 'Hardcore' END,
              CASE p.kind WHEN 'beaten' THEN 'cup' WHEN 'completed' THEN 'plaque' ELSE 'medal' END,
              'retroachievements',true
            FROM trainer_backend.prize_grants p WHERE player_id=%(player)s AND game_id IS NOT NULL
              AND kind IN ('beaten','completed','hardcore') GROUP BY p.game_id,p.kind
          ), scoped AS (
            SELECT game_id||'/'||trophy_id AS key,game_id,trophy_id AS id,title,shape,criterion,earned
            FROM catalogue WHERE CASE WHEN %(game)s::text IS NULL THEN earned ELSE game_id=%(game)s END
          ) SELECT * FROM scoped WHERE key COLLATE "C">%(after)s
              AND (%(key)s::text IS NULL OR key=%(key)s) ORDER BY key COLLATE "C" LIMIT %(limit)s
        ''',dict(player=player,member=str(player),game=game,after=after,key=key,limit=limit+1)).fetchall()
        return {'items':rows[:limit],'next':rows[limit-1]['key'] if len(rows)>limit else None}
