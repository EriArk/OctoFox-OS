-- SPDX-License-Identifier: GPL-3.0-or-later
-- Provisioning belongs to the future stall purchase path. Runtime cannot mint places.
CREATE TABLE trainer_backend.bazaar_places (
    id uuid PRIMARY KEY,
    bazaar_id uuid NOT NULL REFERENCES trainer_backend.bazaars(id),
    name varchar(48) NOT NULL CHECK(length(trim(name))>0),
    weekly_price bigint CHECK(weekly_price BETWEEN 1 AND 2147483647),
    revision bigint NOT NULL DEFAULT 1 CHECK(revision>0)
);
CREATE INDEX bazaar_place_directory ON trainer_backend.bazaar_places(bazaar_id,id);
CREATE TABLE trainer_backend.bazaar_rentals (
    id uuid PRIMARY KEY,
    place_id uuid NOT NULL REFERENCES trainer_backend.bazaar_places(id),
    tenant_id uuid NOT NULL REFERENCES trainer_backend.players(id),
    owner_id uuid NOT NULL REFERENCES trainer_backend.players(id),
    operation_id uuid NOT NULL,
    offer_revision bigint NOT NULL CHECK(offer_revision>0),
    price bigint NOT NULL CHECK(price BETWEEN 1 AND 2147483647),
    started_at timestamptz NOT NULL,
    expires_at timestamptz NOT NULL,
    CHECK(tenant_id<>owner_id),
    CHECK(expires_at=started_at+interval '168 hours'),
    UNIQUE(tenant_id,operation_id),
    UNIQUE(place_id,offer_revision)
);
CREATE INDEX bazaar_rental_occupancy ON trainer_backend.bazaar_rentals(place_id,expires_at DESC);
ALTER TABLE trainer_backend.reward_ledger ADD COLUMN rental_id uuid REFERENCES trainer_backend.bazaar_rentals(id);
CREATE UNIQUE INDEX rental_ledger_pair ON trainer_backend.reward_ledger(rental_id,source) WHERE rental_id IS NOT NULL;
ALTER TABLE trainer_backend.reward_ledger DROP CONSTRAINT ledger_source_amounts,
    ADD CONSTRAINT ledger_source_amounts CHECK (
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
    );
