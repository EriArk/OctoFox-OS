-- SPDX-License-Identifier: GPL-3.0-or-later
-- Ship catches have stable instance IDs across device retries and subsequent sales.
CREATE FUNCTION trainer_backend.store_shore_fish(item uuid, owner_id uuid, data jsonb, card jsonb)
RETURNS boolean LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog,trainer_backend AS $$
 INSERT INTO loot_items(id,player_id,game_id,adapter_id,payload_version,kind,payload,presentation)
 VALUES(item,owner_id,'octofox.ship','octofox.fishing',1,'fish',data,card) ON CONFLICT(id) DO NOTHING RETURNING true
$$;
REVOKE ALL ON FUNCTION trainer_backend.store_shore_fish(uuid,uuid,jsonb,jsonb) FROM PUBLIC;
CREATE INDEX loot_fish_origin_time ON trainer_backend.loot_items((payload->>'angler'),received_at)
 WHERE adapter_id='octofox.fishing';

-- An account fish stays in inventory while displayed. Listing it clears the display.
CREATE TABLE trainer_backend.fish_display (
 item_id uuid PRIMARY KEY REFERENCES trainer_backend.loot_items(id),
 player_id uuid NOT NULL REFERENCES trainer_backend.players(id)
);
CREATE INDEX fish_display_owner ON trainer_backend.fish_display(player_id);
CREATE FUNCTION trainer_backend.unmount_fish() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,trainer_backend AS $$
BEGIN
 DELETE FROM fish_display WHERE item_id=NEW.id;
 RETURN NULL;
END;
$$;
REVOKE ALL ON FUNCTION trainer_backend.unmount_fish() FROM PUBLIC;
CREATE TRIGGER unmount_fish AFTER UPDATE OF player_id,state ON trainer_backend.loot_items
 FOR EACH ROW WHEN (NEW.adapter_id='octofox.fishing' AND
 (NEW.state<>'stored' OR NEW.player_id<>OLD.player_id)) EXECUTE FUNCTION trainer_backend.unmount_fish();
