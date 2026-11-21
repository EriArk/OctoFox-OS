-- SPDX-License-Identifier: GPL-3.0-or-later
-- Permit field samples through the same restricted writer as the other workshop lots.
CREATE OR REPLACE FUNCTION trainer_backend.write_workshop_item(item uuid, owner_id uuid, category text, data jsonb, card jsonb, remaining boolean, creating boolean)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,trainer_backend AS $$
BEGIN
 IF category NOT IN ('blueprint','material','pigment','garment','botanical') THEN RAISE EXCEPTION 'invalid workshop category'; END IF;
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
