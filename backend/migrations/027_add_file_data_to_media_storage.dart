/// Migration 027: Add file_data column to media_storage table
/// 
/// Upgrades media storage to store file content in database instead of filesystem.
/// This ensures media persists on Render between container restarts.

const migrationName = '027_add_file_data_to_media_storage';

const migrationSql = '''
-- Add file_data column to media_storage if it doesn't exist
ALTER TABLE IF EXISTS media_storage
ADD COLUMN IF NOT EXISTS file_data BYTEA;

-- Comment for documentation
COMMENT ON COLUMN media_storage.file_data IS 'Binary file content - enables persistence across container restarts on Render';
''';

const rollbackSql = '''
-- Remove file_data column
ALTER TABLE IF EXISTS media_storage
DROP COLUMN IF EXISTS file_data;
''';
