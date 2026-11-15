-- Existing players keep their names and completed setup.
ALTER TABLE trainer_backend.login_attempts ADD COLUMN flow text NOT NULL DEFAULT 'oauth' CHECK(flow IN ('oauth','social'));
ALTER TABLE trainer_backend.public_profiles ADD COLUMN needs_name boolean NOT NULL DEFAULT false;
ALTER TABLE trainer_backend.public_profiles ADD COLUMN needs_avatar boolean NOT NULL DEFAULT false;
ALTER TABLE trainer_backend.login_attempts ADD COLUMN claimed_session_id uuid REFERENCES trainer_backend.device_sessions(id);
