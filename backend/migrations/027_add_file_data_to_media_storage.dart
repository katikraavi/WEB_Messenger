/// Migration 027: Add file_data column to media_storage table
/// 
/// Upgrades media storage to store file content in database instead of filesystem.
/// This ensures media persists on Render between container restarts.

const migrationName = '027_add_file_data_to_media_storage';

const migrationSql = '''
-- file_data column already added in migration 016
SELECT 1;
''';

const rollbackSql = '''
-- No changes to rollback - file_data column is part of migration 016
SELECT 1;
''';
