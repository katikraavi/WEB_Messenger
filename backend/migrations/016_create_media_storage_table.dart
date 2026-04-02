import 'package:postgres/postgres.dart';

/// Migration: Create Media Storage table for tracking uploaded files
Future<void> up(Connection connection) async {
  // Drop if exists to ensure fresh schema with file_data (not file_path)
  await connection.execute('''
    DROP TABLE IF EXISTS media_storage CASCADE;
  ''');
  
  await connection.execute('''
    CREATE TABLE IF NOT EXISTS media_storage (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      uploader_id UUID NOT NULL,
      file_name VARCHAR(255) NOT NULL,
      mime_type VARCHAR(100),
      file_size_bytes INT NOT NULL,
      file_data BYTEA NOT NULL,
      original_name TEXT,
      created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
      
      CONSTRAINT fk_media_uploader FOREIGN KEY (uploader_id) 
        REFERENCES "user"(id) ON DELETE CASCADE,
      CONSTRAINT valid_file_size CHECK (file_size_bytes > 0 AND file_size_bytes <= 52428800)
    );
  ''');
  
  await connection.execute('''
    CREATE INDEX idx_media_uploader_created ON media_storage(uploader_id, created_at DESC);
  ''');
  
  await connection.execute('''
    CREATE INDEX idx_media_created_at ON media_storage(created_at DESC);
  ''');
  
  print('[✓] Table created: media_storage');
}

/// Rollback: Drop Media Storage table
Future<void> down(Connection connection) async {
  await connection.execute('''
    DROP TABLE IF EXISTS media_storage CASCADE;
  ''');
  
  print('[✓] Table dropped: media_storage');
}

/// Migration metadata
class Migration016 {
  static const String name = '016_create_media_storage_table';
  static const int version = 16;
  static const DateTime createdAt = DateTime(2026, 3, 16);
}
