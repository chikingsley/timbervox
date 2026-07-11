ALTER TABLE uploads ADD COLUMN owner_user_id TEXT REFERENCES users(id);
ALTER TABLE uploads ADD COLUMN credential_id TEXT REFERENCES api_credentials(id);

CREATE INDEX IF NOT EXISTS idx_uploads_owner_created
  ON uploads(owner_user_id, created_at);

ALTER TABLE jobs ADD COLUMN owner_user_id TEXT REFERENCES users(id);
ALTER TABLE jobs ADD COLUMN credential_id TEXT REFERENCES api_credentials(id);

CREATE INDEX IF NOT EXISTS idx_jobs_owner_created
  ON jobs(owner_user_id, created_at);

ALTER TABLE realtime_sessions ADD COLUMN owner_user_id TEXT REFERENCES users(id);
ALTER TABLE realtime_sessions ADD COLUMN credential_id TEXT REFERENCES api_credentials(id);

CREATE INDEX IF NOT EXISTS idx_realtime_sessions_owner_created
  ON realtime_sessions(owner_user_id, created_at);
