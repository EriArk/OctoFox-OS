-- SPDX-License-Identifier: GPL-3.0-or-later
CREATE TABLE trainer_backend.festival_rounds (
    id uuid PRIMARY KEY,
    player_id uuid NOT NULL REFERENCES trainer_backend.players(id),
    operation_id uuid NOT NULL,
    game text NOT NULL CHECK(game IN ('gallery','rings','golf_local','golf_online')),
    price integer NOT NULL CHECK(price>0),
    attempts jsonb NOT NULL DEFAULT '[]' CHECK(jsonb_typeof(attempts)='array' AND jsonb_array_length(attempts)<=5),
    complete boolean NOT NULL DEFAULT false,
    prize text CHECK(prize IN ('Peach Bunny','Pond Frog','Honey Bear','Sky Bird','Moon Cat')),
    started_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    UNIQUE(player_id,operation_id)
);
CREATE UNIQUE INDEX festival_unfinished ON trainer_backend.festival_rounds(player_id,game) WHERE NOT complete;
CREATE INDEX festival_recent ON trainer_backend.festival_rounds(player_id,game,started_at DESC);

-- Keep the existing ledger's source-specific checks intact for every earlier operation.
ALTER TABLE trainer_backend.reward_ledger ADD COLUMN festival_id uuid UNIQUE REFERENCES trainer_backend.festival_rounds(id);
DO $$
DECLARE old_rule text;
BEGIN
    SELECT pg_get_expr(conbin,conrelid) INTO STRICT old_rule FROM pg_constraint
        WHERE conrelid='trainer_backend.reward_ledger'::regclass AND conname='ledger_source_amounts';
    ALTER TABLE trainer_backend.reward_ledger DROP CONSTRAINT ledger_source_amounts;
    EXECUTE format('ALTER TABLE trainer_backend.reward_ledger ADD CONSTRAINT ledger_source_amounts CHECK
        ((festival_id IS NULL AND (%s)) OR (festival_id IS NOT NULL AND source=''festival.entry'' AND sparks<0
          AND xp=0 AND base_sparks=0 AND purchase_id IS NULL AND trade_id IS NULL AND rental_id IS NULL
          AND operator_grant_id IS NULL AND ra_id IS NULL AND game_id IS NULL AND base_reward_id IS NULL
          AND support_multiplier IS NULL AND support_receipt_id IS NULL))',old_rule);
END $$;

-- The runtime cannot insert arbitrary collectibles. One paid round has one item ID.
CREATE FUNCTION trainer_backend.award_festival_toy() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,trainer_backend AS $$
BEGIN
    INSERT INTO trainer_backend.loot_items(id,player_id,game_id,adapter_id,payload_version,kind,payload,presentation)
    VALUES(NEW.id,NEW.player_id,'traineros.bazaar','festival.gallery',1,'toy',
        jsonb_build_object('toy',NEW.prize,'round',NEW.id),
        jsonb_build_object('game','Festival Park','title',NEW.prize,'subtitle','Gallery plush','icon','star'));
    RETURN NULL;
END $$;
REVOKE ALL ON FUNCTION trainer_backend.award_festival_toy() FROM PUBLIC;
CREATE TRIGGER festival_toy AFTER UPDATE OF prize ON trainer_backend.festival_rounds
    FOR EACH ROW WHEN (OLD.prize IS NULL AND NEW.prize IS NOT NULL AND NEW.game='gallery')
    EXECUTE FUNCTION trainer_backend.award_festival_toy();
