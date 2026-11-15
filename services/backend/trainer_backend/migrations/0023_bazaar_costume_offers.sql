-- SPDX-License-Identifier: GPL-3.0-or-later
-- Alpha prices approved by the owner. Assets/equip are not deliverable yet.
-- These are distinct from free wardrobe garments and paid saved-outfit slots.
ALTER TABLE trainer_backend.shop_offers DROP CONSTRAINT shop_offers_purpose_check;
ALTER TABLE trainer_backend.shop_offers DROP CONSTRAINT shop_offer_purpose;
ALTER TABLE trainer_backend.shop_offers ADD CONSTRAINT shop_offers_purpose_check
    CHECK(purpose IN ('profile_scene','outfit_slot','bazaar_space','bazaar_stall','avatar_costume'));
ALTER TABLE trainer_backend.shop_offers ADD CONSTRAINT shop_offer_purpose CHECK (
    (purpose='profile_scene' AND appearance IS NOT NULL AND slot_number IS NULL)
    OR (purpose='outfit_slot' AND appearance IS NULL AND slot_number BETWEEN 1 AND 64 AND slot_number IS NOT NULL)
    OR (purpose='bazaar_space' AND appearance IS NULL AND slot_number IS NULL AND id='bazaar.personal')
    OR (purpose='bazaar_stall' AND appearance IS NULL AND slot_number IS NULL AND id='bazaar.stall')
    OR (purpose='avatar_costume' AND appearance IS NULL AND slot_number IS NULL));
INSERT INTO trainer_backend.shop_offers(id,revision,publisher,application,title,description,appearance,price,purpose,available) VALUES
('costume.traveller',1,'TrainerOS','traineros','Traveller','A new fantasy travelling outfit for the TrainerOS avatar.',NULL,50,'avatar_costume',false),
('costume.mage',1,'TrainerOS','traineros','Mage','A new fantasy mage outfit for the TrainerOS avatar.',NULL,50,'avatar_costume',false),
('costume.merchant',1,'TrainerOS','traineros','Merchant','A new fantasy merchant outfit for the TrainerOS avatar.',NULL,50,'avatar_costume',false);
