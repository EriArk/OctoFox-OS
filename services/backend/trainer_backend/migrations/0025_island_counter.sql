-- SPDX-License-Identifier: GPL-3.0-or-later
ALTER TABLE trainer_backend.bazaar_listings ADD COLUMN initial_price bigint;
UPDATE trainer_backend.bazaar_listings SET initial_price=price;
ALTER TABLE trainer_backend.bazaar_listings ADD CHECK(initial_price BETWEEN 1 AND 2147483647);
-- Old application versions can still insert listings; preserve their first ask.
CREATE FUNCTION trainer_backend.bazaar_initial_ask() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN NEW.initial_price:=NEW.price; RETURN NEW; END $$;
CREATE TRIGGER initial_ask BEFORE INSERT ON trainer_backend.bazaar_listings
FOR EACH ROW EXECUTE FUNCTION trainer_backend.bazaar_initial_ask();
ALTER TABLE trainer_backend.bazaar_listings ALTER COLUMN initial_price SET NOT NULL;

CREATE TABLE trainer_backend.bazaar_visitors (
    bazaar_id uuid NOT NULL REFERENCES trainer_backend.bazaars(id),
    player_id uuid NOT NULL REFERENCES trainer_backend.players(id),
    visit_id uuid NOT NULL,
    arrived timestamptz NOT NULL DEFAULT clock_timestamp(),
    seen timestamptz NOT NULL DEFAULT clock_timestamp(),
    PRIMARY KEY(bazaar_id,player_id)
);
CREATE TABLE trainer_backend.bazaar_peer_offers (
    bazaar_id uuid NOT NULL REFERENCES trainer_backend.bazaars(id),
    host_visit uuid NOT NULL, guest_visit uuid NOT NULL,
    code varchar(160) NOT NULL,
    PRIMARY KEY(bazaar_id,host_visit,guest_visit)
);
