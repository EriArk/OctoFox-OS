-- SPDX-License-Identifier: GPL-3.0-or-later
-- Leased sellers and game-neutral listings. No item issuance or save import.
CREATE TABLE trainer_backend.bazaar_sellers (
    rental_id uuid PRIMARY KEY REFERENCES trainer_backend.bazaar_rentals(id),
    species text NOT NULL CHECK(species IN ('Casual_Female','Casual_Male','Chef_Female','Kimono_Female','OldClassy_Male','Wizard','Witch','Bunny','Yeti','Dino','Frog','Birb')),
    revision bigint NOT NULL DEFAULT 1 CHECK(revision>0)
);
CREATE TABLE trainer_backend.bazaar_listings (
    id uuid PRIMARY KEY,
    rental_id uuid NOT NULL REFERENCES trainer_backend.bazaar_rentals(id),
    seller_id uuid NOT NULL REFERENCES trainer_backend.players(id),
    item_id uuid NOT NULL REFERENCES trainer_backend.loot_items(id),
    price bigint NOT NULL CHECK(price BETWEEN 1 AND 2147483647),
    revision bigint NOT NULL DEFAULT 1 CHECK(revision>0),
    state text NOT NULL DEFAULT 'listed' CHECK(state IN ('listed','withdrawn','sold')),
    operation_id uuid NOT NULL,
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    UNIQUE(seller_id,operation_id)
);
CREATE UNIQUE INDEX bazaar_one_listing ON trainer_backend.bazaar_listings(item_id) WHERE state='listed';
CREATE INDEX bazaar_listing_page ON trainer_backend.bazaar_listings(rental_id,id);
CREATE TABLE trainer_backend.bazaar_trades (
    id uuid PRIMARY KEY,
    buyer_id uuid NOT NULL REFERENCES trainer_backend.players(id),
    operation_id uuid NOT NULL,
    kind text NOT NULL CHECK(kind IN ('seller','loot')),
    rental_id uuid REFERENCES trainer_backend.bazaar_rentals(id),
    listing_id uuid REFERENCES trainer_backend.bazaar_listings(id),
    seller_id uuid REFERENCES trainer_backend.players(id),
    item_id uuid REFERENCES trainer_backend.loot_items(id),
    species text,
    offer_revision bigint NOT NULL CHECK(offer_revision>0),
    price bigint NOT NULL CHECK(price BETWEEN 1 AND 2147483647),
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    UNIQUE(buyer_id,operation_id),
    UNIQUE(listing_id),
    UNIQUE(rental_id),
    CHECK((kind='seller' AND rental_id IS NOT NULL AND species IS NOT NULL AND listing_id IS NULL AND seller_id IS NULL AND item_id IS NULL AND price=100)
       OR (kind='loot' AND rental_id IS NULL AND species IS NULL AND listing_id IS NOT NULL AND seller_id IS NOT NULL AND item_id IS NOT NULL AND buyer_id<>seller_id))
);
ALTER TABLE trainer_backend.reward_ledger ADD COLUMN trade_id uuid REFERENCES trainer_backend.bazaar_trades(id);
CREATE UNIQUE INDEX bazaar_trade_ledger ON trainer_backend.reward_ledger(trade_id,source) WHERE trade_id IS NOT NULL;
ALTER TABLE trainer_backend.reward_ledger DROP CONSTRAINT ledger_source_amounts, ADD CONSTRAINT ledger_source_amounts CHECK ((trade_id IS NULL AND (
        (rental_id IS NULL AND (
        (operator_grant_id IS NULL AND (
            (source IN ('ra.achievement','ra.completion') AND sparks>=0 AND ra_id IS NOT NULL AND game_id IS NOT NULL AND purchase_id IS NULL
                AND base_reward_id IS NULL AND support_multiplier IS NULL AND support_receipt_id IS NULL)
            OR (source='shop.purchase' AND sparks<0 AND xp=0 AND base_sparks=0 AND ra_id IS NULL AND game_id IS NULL AND purchase_id IS NOT NULL
                AND base_reward_id IS NULL AND support_multiplier IS NULL AND support_receipt_id IS NULL)
            OR (source='support.topup' AND sparks>0 AND xp=0 AND base_sparks=0 AND ra_id IS NULL AND game_id IS NULL AND purchase_id IS NULL
                AND base_reward_id IS NOT NULL AND support_multiplier IS NOT NULL AND support_multiplier IN (2,3) AND support_receipt_id IS NOT NULL)
        ))
        OR (source='operator.test_grant' AND sparks>0 AND xp=0 AND base_sparks=0 AND ra_id IS NULL AND game_id IS NULL
            AND purchase_id IS NULL AND base_reward_id IS NULL AND support_multiplier IS NULL AND support_receipt_id IS NULL
            AND operator_grant_id IS NOT NULL)
    )) OR
        (rental_id IS NOT NULL AND source IN ('bazaar.rent','bazaar.rent_income')
            AND ((source='bazaar.rent' AND sparks<0) OR (source='bazaar.rent_income' AND sparks>0))
            AND xp=0 AND base_sparks=0 AND ra_id IS NULL AND game_id IS NULL AND purchase_id IS NULL
            AND base_reward_id IS NULL AND support_multiplier IS NULL AND support_receipt_id IS NULL
            AND operator_grant_id IS NULL)
    )) OR
    (trade_id IS NOT NULL AND rental_id IS NULL AND xp=0 AND base_sparks=0
     AND ra_id IS NULL AND game_id IS NULL AND purchase_id IS NULL AND base_reward_id IS NULL
     AND support_multiplier IS NULL AND support_receipt_id IS NULL AND operator_grant_id IS NULL
     AND ((source IN ('bazaar.buy','bazaar.seller') AND sparks<0) OR (source='bazaar.sale' AND sparks>0)))
);

-- Only the existing trigger can bump revisions; runtime cannot forge snapshots.
ALTER FUNCTION trainer_backend.bump_loot_revision() SECURITY DEFINER;

-- Operator binds a published world to a real owned Bazaar and its provisioned places.
-- A client/world name is never authority to choose an owner or mint twelve places.
CREATE TABLE trainer_backend.bazaar_worlds (
    world_key text PRIMARY KEY CHECK(world_key ~ '^[a-z][a-z0-9_-]{0,31}$'),
    bazaar_id uuid NOT NULL UNIQUE REFERENCES trainer_backend.bazaars(id)
);
CREATE TABLE trainer_backend.bazaar_world_places (
    world_key text NOT NULL REFERENCES trainer_backend.bazaar_worlds(world_key),
    slot integer NOT NULL CHECK(slot BETWEEN 1 AND 12),
    place_id uuid NOT NULL UNIQUE REFERENCES trainer_backend.bazaar_places(id),
    PRIMARY KEY(world_key,slot)
);
