-- SPDX-License-Identifier: GPL-3.0-or-later
ALTER TABLE trainer_backend.bazaars
    ADD COLUMN cover text NOT NULL DEFAULT 'market' CHECK(cover IN ('market','grove','harbor')),
    ADD COLUMN badge text NOT NULL DEFAULT 'shop' CHECK(badge IN ('shop','community','companion','trophy','guide'));
CREATE TABLE trainer_backend.bazaar_blocks (
    bazaar_id uuid NOT NULL REFERENCES trainer_backend.bazaars(id),
    player_id uuid NOT NULL REFERENCES trainer_backend.players(id),
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    PRIMARY KEY(bazaar_id,player_id)
);
