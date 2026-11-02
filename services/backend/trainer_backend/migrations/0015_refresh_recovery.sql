-- SPDX-License-Identifier: GPL-3.0-or-later
-- Only hashes of the caller's recovery proof and successor credential are stored.
ALTER TABLE trainer_backend.refresh_credentials
    ADD COLUMN recovery_hash char(64),
    ADD COLUMN successor_hash char(64),
    ADD CONSTRAINT refresh_recovery_pair CHECK (
        (recovery_hash IS NULL AND successor_hash IS NULL) OR
        (recovery_hash IS NOT NULL AND successor_hash IS NOT NULL AND consumed_at IS NOT NULL)
    );
