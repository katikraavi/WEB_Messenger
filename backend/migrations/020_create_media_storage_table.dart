/// Migration 020: Create media_storage table for persistent media storage
/// 
/// Stores media files as BLOBs in database instead of ephemeral filesystem
/// This ensures media persists on Render between container restarts

const migrationName = '020_create_media_storage_table';

const migrationSql = '''
-- Create media_storage table to store file chunks in database
CREATE TABLE IF NOT EXISTS media_storage (
  id UUID PRIMARY KEY,
  uploader_id UUID NOT NULL,
  file_name TEXT NOT NULL,
  mime_type TEXT ,
  file_size_bytes BIGINT NOT NULL,
  file_data BYTEA NOT NULL, -- Binary file data stored in database
  original_name TEXT,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Create index for fast lookups
CREATE INDEX IF NOT EXISTS media_storage_uploader_id ON media_storage (uploader_id);
CREATE INDEX IF NOT EXISTS media_storage_created_at ON media_storage (created_at);

-- Comment for documentation
COMMENT ON TABLE media_storage IS 'Stores media files as BLOBs for persistent storage on Render';
COMMENT ON COLUMN media_storage.file_data IS 'Binary file content - enables persistence across container restarts';
''';

const rollbackSql = '''
-- Drop media_storage table
DROP TABLE IF EXISTS media_storage CASCADE;
''';
