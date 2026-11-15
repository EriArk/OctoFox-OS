-- SPDX-License-Identifier: GPL-3.0-or-later
-- Private game collectibles, separate from shop licenses / wardrobe rights.
-- Runtime can only read these tables. Custody writes need a later recoverable
-- save-transfer protocol; no mint/import HTTP route is introduced here.
CREATE TABLE trainer_backend.loot_revisions (
    player_id uuid PRIMARY KEY REFERENCES trainer_backend.players(id),
    revision bigint NOT NULL CHECK(revision>0)
);
CREATE TABLE trainer_backend.loot_items (
    sequence bigint GENERATED ALWAYS AS IDENTITY UNIQUE,
    id uuid PRIMARY KEY,
    player_id uuid NOT NULL REFERENCES trainer_backend.players(id),
    game_id varchar(64) NOT NULL CHECK(game_id ~ '^[a-z0-9][a-z0-9._-]{0,63}$'),
    adapter_id varchar(64) NOT NULL CHECK(adapter_id ~ '^[a-z0-9][a-z0-9._-]{0,63}$'),
    payload_version integer NOT NULL CHECK(payload_version>0),
    kind varchar(64) NOT NULL CHECK(kind ~ '^[a-z0-9][a-z0-9._-]{0,63}$'),
    payload jsonb NOT NULL CHECK(jsonb_typeof(payload)='object' AND octet_length(payload::text)<=65536),
    presentation jsonb NOT NULL CHECK(jsonb_typeof(presentation)='object' AND octet_length(presentation::text)<=8192),
    state text NOT NULL DEFAULT 'stored' CHECK(state IN ('stored','listed')),
    received_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE INDEX loot_owner_order ON trainer_backend.loot_items(player_id,sequence DESC);
-- A page chain must never combine two ownership revisions, including equal-count
-- replacements. The trigger also covers future privileged custody transactions.
CREATE FUNCTION trainer_backend.bump_loot_revision() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog,trainer_backend AS $$
BEGIN
    IF TG_OP IN ('UPDATE','DELETE') THEN
        INSERT INTO trainer_backend.loot_revisions VALUES(OLD.player_id,1)
        ON CONFLICT(player_id) DO UPDATE SET revision=loot_revisions.revision+1;
    END IF;
    IF TG_OP='INSERT' OR (TG_OP='UPDATE' AND NEW.player_id<>OLD.player_id) THEN
        INSERT INTO trainer_backend.loot_revisions VALUES(NEW.player_id,1)
        ON CONFLICT(player_id) DO UPDATE SET revision=loot_revisions.revision+1;
    END IF;
    RETURN NULL;
END;
$$;
REVOKE ALL ON FUNCTION trainer_backend.bump_loot_revision() FROM PUBLIC;
CREATE TRIGGER loot_revision AFTER INSERT OR UPDATE OR DELETE ON trainer_backend.loot_items
FOR EACH ROW EXECUTE FUNCTION trainer_backend.bump_loot_revision();
