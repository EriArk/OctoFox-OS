-- SPDX-License-Identifier: GPL-3.0-or-later
-- Hardware modules are tradable until fitted.
CREATE OR REPLACE FUNCTION trainer_backend.write_workshop_item(item uuid, owner_id uuid, category text, data jsonb, card jsonb, remaining boolean, creating boolean)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,trainer_backend AS $$
BEGIN
 IF category NOT IN ('blueprint','material','pigment','garment','botanical','ore','upgrade') THEN RAISE EXCEPTION 'invalid workshop category'; END IF;
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

-- Preserve all existing ledger constraints while adding a purchase linked to the physical item.
ALTER TABLE trainer_backend.reward_ledger ADD COLUMN supply_item uuid UNIQUE REFERENCES trainer_backend.loot_items(id);
DO $$
DECLARE previous_rule text;
BEGIN
 SELECT pg_get_expr(conbin,conrelid) INTO STRICT previous_rule FROM pg_constraint
 WHERE conrelid='trainer_backend.reward_ledger'::regclass AND conname='ledger_source_amounts';
 ALTER TABLE trainer_backend.reward_ledger DROP CONSTRAINT ledger_source_amounts;
 EXECUTE format('ALTER TABLE trainer_backend.reward_ledger ADD CONSTRAINT ledger_source_amounts CHECK
   ((supply_item IS NULL AND (%s)) OR (supply_item IS NOT NULL AND source=''shop.purchase''
   AND sparks<0 AND xp=0 AND base_sparks=0 AND ra_id IS NULL AND game_id IS NULL AND purchase_id IS NULL
   AND operator_grant_id IS NULL AND base_reward_id IS NULL AND support_receipt_id IS NULL
   AND support_multiplier IS NULL AND rental_id IS NULL AND trade_id IS NULL))', previous_rule);
END;
$$;
