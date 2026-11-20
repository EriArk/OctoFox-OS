-- SPDX-License-Identifier: GPL-3.0-or-later
-- Keep consumed lots as historical identities for Bazaar receipts.
ALTER TABLE trainer_backend.loot_items DROP CONSTRAINT loot_items_state_check,
 ADD CHECK (state IN ('stored','listed') OR (adapter_id='octofox.workshop' AND state='consumed'));
CREATE INDEX workshop_stock ON trainer_backend.loot_items(player_id,kind,(payload->>'sku'),sequence)
 WHERE adapter_id='octofox.workshop' AND state='stored';
CREATE TABLE trainer_backend.workshop_rewards (
 player_id uuid NOT NULL REFERENCES trainer_backend.players(id),
 event text NOT NULL, ordinal bigint NOT NULL,
 PRIMARY KEY(player_id,event), UNIQUE(player_id,ordinal)
);
CREATE TABLE trainer_backend.workshop_palette (
 player_id uuid NOT NULL REFERENCES trainer_backend.players(id), color text NOT NULL,
 PRIMARY KEY(player_id,color)
);
CREATE TABLE trainer_backend.workshop_play (
 player_id uuid PRIMARY KEY REFERENCES trainer_backend.players(id), session_id uuid NOT NULL,
 started_at timestamptz NOT NULL DEFAULT clock_timestamp(), last_seen timestamptz NOT NULL DEFAULT clock_timestamp()
);
-- The runtime retains no INSERT, DELETE or payload-edit rights on other adapters.
CREATE FUNCTION trainer_backend.write_workshop_item(item uuid, owner_id uuid, category text, data jsonb, card jsonb, remaining boolean, creating boolean)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,trainer_backend AS $$
BEGIN
 IF category NOT IN ('blueprint','material','pigment','garment') THEN RAISE EXCEPTION 'invalid workshop category'; END IF;
 IF creating THEN
  INSERT INTO loot_items(id,player_id,game_id,adapter_id,payload_version,kind,payload,presentation)
   VALUES(item,owner_id,'octofox.ship','octofox.workshop',1,category,data,card);
 ELSE
  UPDATE loot_items SET payload=data,presentation=card,state=CASE WHEN remaining THEN 'stored' ELSE 'consumed' END
   WHERE id=item AND player_id=owner_id AND adapter_id='octofox.workshop' AND kind=category AND state='stored';
  IF NOT FOUND THEN RAISE EXCEPTION 'unavailable workshop item'; END IF;
 END IF;
END;
$$;
REVOKE ALL ON FUNCTION trainer_backend.write_workshop_item(uuid,uuid,text,jsonb,jsonb,boolean,boolean) FROM PUBLIC;
ALTER TABLE trainer_backend.prize_grants DROP CONSTRAINT prize_grants_kind_check,
 ADD CHECK(kind IN ('clothing','workshop','outfit_slot','beaten','completed','hardcore'));
