ALTER TABLE users ADD COLUMN identity_provider TEXT;
ALTER TABLE users ADD COLUMN external_id_hash TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS idx_users_external_identity
  ON users(identity_provider, external_id_hash);

CREATE TABLE IF NOT EXISTS app_installations (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id),
  installation_hash TEXT NOT NULL,
  device_name TEXT,
  app_version TEXT,
  status TEXT NOT NULL,
  created_at TEXT NOT NULL,
  last_seen_at TEXT NOT NULL,
  revoked_at TEXT,
  UNIQUE(user_id, installation_hash)
);

CREATE INDEX IF NOT EXISTS idx_app_installations_user_id
  ON app_installations(user_id);
CREATE INDEX IF NOT EXISTS idx_app_installations_status
  ON app_installations(status);

ALTER TABLE api_credentials
  ADD COLUMN installation_id TEXT REFERENCES app_installations(id);
ALTER TABLE api_credentials ADD COLUMN source TEXT;
ALTER TABLE api_credentials ADD COLUMN entitlement_id TEXT;
ALTER TABLE api_credentials ADD COLUMN verified_at TEXT;

CREATE INDEX IF NOT EXISTS idx_api_credentials_installation_id
  ON api_credentials(installation_id);
CREATE INDEX IF NOT EXISTS idx_api_credentials_source_status
  ON api_credentials(source, status);
