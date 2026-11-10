-- SPDX-License-Identifier: GPL-3.0-or-later
ALTER TABLE trainer_backend.shop_offers DROP CONSTRAINT shop_offers_purpose_check;
ALTER TABLE trainer_backend.shop_offers DROP CONSTRAINT shop_offer_purpose;
ALTER TABLE trainer_backend.shop_offers ADD CONSTRAINT shop_offers_purpose_check
    CHECK(purpose IN ('profile_scene','outfit_slot','bazaar_space','bazaar_stall'));
ALTER TABLE trainer_backend.shop_offers ADD CONSTRAINT shop_offer_purpose CHECK (
    (purpose='profile_scene' AND appearance IS NOT NULL AND slot_number IS NULL)
    OR (purpose='outfit_slot' AND appearance IS NULL AND slot_number BETWEEN 1 AND 64 AND slot_number IS NOT NULL)
    OR (purpose='bazaar_space' AND appearance IS NULL AND slot_number IS NULL AND id='bazaar.personal')
    OR (purpose='bazaar_stall' AND appearance IS NULL AND slot_number IS NULL AND id='bazaar.stall'));
INSERT INTO trainer_backend.shop_offers(id,revision,publisher,application,title,description,appearance,price,purpose)
VALUES('bazaar.stall',1,'TrainerOS','traineros','Trading place',
    'One permanent trading place in your personal bazaar. Set its weekly rent separately.',NULL,500,'bazaar_stall');
-- Repeatable paid instances; other permanent licenses keep the original uniqueness.
ALTER TABLE trainer_backend.purchases DROP CONSTRAINT purchases_player_id_offer_id_key;
CREATE UNIQUE INDEX purchases_single_license ON trainer_backend.purchases(player_id,offer_id) WHERE offer_id<>'bazaar.stall';
ALTER TABLE trainer_backend.bazaar_places ADD COLUMN purchase_id uuid UNIQUE REFERENCES trainer_backend.purchases(id);
-- Runtime still cannot insert arbitrary places. Only a paid receipt can provision one.
CREATE FUNCTION trainer_backend.provision_bazaar_stall(receipt uuid) RETURNS SETOF trainer_backend.bazaar_places
LANGUAGE sql SECURITY DEFINER SET search_path=pg_catalog,trainer_backend AS $$
    INSERT INTO trainer_backend.bazaar_places(id,bazaar_id,name,purchase_id)
    SELECT p.id,b.id,'Trading place ' || (SELECT count(*)+1 FROM trainer_backend.bazaar_places WHERE bazaar_id=b.id),p.id
    FROM trainer_backend.purchases p JOIN trainer_backend.bazaars b ON b.owner_id=p.player_id
    WHERE p.id=receipt AND p.offer_id='bazaar.stall'
    ON CONFLICT(purchase_id) DO NOTHING RETURNING *;
$$;
REVOKE ALL ON FUNCTION trainer_backend.provision_bazaar_stall(uuid) FROM PUBLIC;
