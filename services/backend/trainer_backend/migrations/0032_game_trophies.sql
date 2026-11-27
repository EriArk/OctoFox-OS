-- SPDX-License-Identifier: GPL-3.0-or-later
CREATE TABLE trainer_backend.game_trophies (
    game_id text NOT NULL, trophy_id text NOT NULL, title text NOT NULL,
    shape text NOT NULL CHECK (shape IN ('cup','medal','plaque')),
    criterion text NOT NULL CHECK (criterion IN ('confirmed_win','verified_event')),
    ruleset_id text REFERENCES trainer_backend.game_rulesets(id),
    PRIMARY KEY(game_id,trophy_id),
    CHECK ((criterion='confirmed_win') = (ruleset_id IS NOT NULL))
);
CREATE TABLE trainer_backend.trophy_proofs (
    player_id uuid NOT NULL REFERENCES trainer_backend.players(id),
    game_id text NOT NULL, trophy_id text NOT NULL, evidence_id uuid NOT NULL,
    earned_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    PRIMARY KEY (player_id,game_id,trophy_id,evidence_id),
    FOREIGN KEY (game_id,trophy_id) REFERENCES trainer_backend.game_trophies
);
