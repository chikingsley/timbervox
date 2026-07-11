ALTER TABLE uploads ADD COLUMN declared_size_bytes INTEGER;
ALTER TABLE uploads ADD COLUMN upload_strategy TEXT;
ALTER TABLE uploads ADD COLUMN multipart_upload_id TEXT;

CREATE INDEX IF NOT EXISTS idx_uploads_strategy_created
  ON uploads(upload_strategy, created_at);
