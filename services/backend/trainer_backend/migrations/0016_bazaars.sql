-- SPDX-License-Identifier: GPL-3.0-or-later
-- A persistent owned place; its owner is not the ephemeral peer hosting it.
ALTER TABLE trainer_backend.shop_offers DROP CONSTRAINT shop_offers_purpose_check;
ALTER TABLE trainer_backend.shop_offers DROP CONSTRAINT shop_offer_purpose;
ALTER TABLE trainer_backend.shop_offers ADD CONSTRAINT shop_offers_purpose_check
    CHECK(purpose IN ('profile_scene','outfit_slot','bazaar_space'));
ALTER TABLE trainer_backend.shop_offers ADD CONSTRAINT shop_offer_purpose CHECK (
    (purpose='profile_scene' AND appearance IS NOT NULL AND slot_number IS NULL)
    OR (purpose='outfit_slot' AND appearance IS NULL AND slot_number BETWEEN 1 AND 64 AND slot_number IS NOT NULL)
    OR (purpose='bazaar_space' AND appearance IS NULL AND slot_number IS NULL AND id='bazaar.personal'));
ALTER TABLE trainer_backend.purchases ADD COLUMN details jsonb NOT NULL DEFAULT '{}' CHECK(jsonb_typeof(details)='object');
INSERT INTO trainer_backend.shop_offers(id,revision,publisher,application,title,description,appearance,price,purpose)
VALUES('bazaar.personal',1,'TrainerOS','traineros','Personal Bazaar',
    'One permanent personal bazaar. Ownership is independent of its current peer host.',NULL,5000,'bazaar_space');
CREATE TABLE trainer_backend.bazaars (
    id uuid PRIMARY KEY,
    owner_id uuid NOT NULL UNIQUE REFERENCES trainer_backend.players(id),
    offer_id varchar(64) NOT NULL DEFAULT 'bazaar.personal' CHECK(offer_id='bazaar.personal'),
    name varchar(48) NOT NULL CHECK(length(btrim(name))>0),
    description varchar(280) NOT NULL DEFAULT '',
    listed boolean NOT NULL DEFAULT true,
    access text NOT NULL DEFAULT 'open' CHECK(access IN ('open','closed')),
    revision bigint NOT NULL DEFAULT 1 CHECK(revision>0),
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    FOREIGN KEY(owner_id,offer_id) REFERENCES trainer_backend.owned_items(player_id,offer_id)
);
CREATE INDEX bazaars_directory ON trainer_backend.bazaars(id) WHERE listed;
