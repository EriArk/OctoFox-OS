-- SPDX-License-Identifier: GPL-3.0-or-later
CREATE TABLE trainer_backend.workshop_prints (
    id uuid PRIMARY KEY,
    player_id uuid NOT NULL REFERENCES trainer_backend.players(id),
    sku text NOT NULL,
    started_at timestamptz NOT NULL DEFAULT statement_timestamp(),
    ready_at timestamptz NOT NULL,
    item_id uuid UNIQUE REFERENCES trainer_backend.loot_items(id),
    CHECK (ready_at - started_at BETWEEN interval '1 hour' AND interval '24 hours')
);
CREATE INDEX workshop_pending_prints ON trainer_backend.workshop_prints(player_id, sku, ready_at)
    WHERE item_id IS NULL;
