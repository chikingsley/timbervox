DROP INDEX IF EXISTS idx_api_credentials_installation_id;
DROP INDEX IF EXISTS idx_api_credentials_source_status;
DROP INDEX IF EXISTS idx_app_installations_user_id;
DROP INDEX IF EXISTS idx_app_installations_status;
DROP INDEX IF EXISTS idx_license_activations_license_id;
DROP INDEX IF EXISTS idx_license_activations_user_id;
DROP INDEX IF EXISTS idx_license_activations_status;
DROP INDEX IF EXISTS idx_license_keys_user_id;
DROP INDEX IF EXISTS idx_license_keys_email;
DROP INDEX IF EXISTS idx_license_keys_status;
DROP INDEX IF EXISTS idx_users_external_identity;

ALTER TABLE api_credentials DROP COLUMN installation_id;
ALTER TABLE api_credentials DROP COLUMN source;
ALTER TABLE api_credentials DROP COLUMN entitlement_id;
ALTER TABLE api_credentials DROP COLUMN verified_at;
ALTER TABLE api_credentials DROP COLUMN activation_id;
ALTER TABLE api_credentials DROP COLUMN expires_at;
ALTER TABLE users DROP COLUMN identity_provider;
ALTER TABLE users DROP COLUMN external_id_hash;

DROP TABLE IF EXISTS license_activations;
DROP TABLE IF EXISTS license_keys;
DROP TABLE IF EXISTS app_installations;
