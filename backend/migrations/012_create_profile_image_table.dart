import 'package:postgres/postgres.dart';

/// Migration: Create profile_image table for profile picture uploads
Future<void> up(Connection connection) async {
  await connection.execute('''
    CREATE TABLE IF NOT EXISTS profile_image (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id UUID NOT NULL,
      file_path TEXT NOT NULL,
      file_size_bytes INTEGER NOT NULL,
      original_format VARCHAR(10) NOT NULL,
      stored_format VARCHAR(10) NOT NULL DEFAULT 'jpeg',
      width_px INTEGER NOT NULL,
      height_px INTEGER NOT NULL,
      is_active BOOLEAN DEFAULT false NOT NULL,
      uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
      deleted_at TIMESTAMP WITH TIME ZONE,
      
      CONSTRAINT fk_profile_image_user 
        FOREIGN KEY (user_id) REFERENCES "user"(id) ON DELETE CASCADE,
      CONSTRAINT check_file_size 
        CHECK (file_size_bytes > 0 AND file_size_bytes <= 5242880),
      CONSTRAINT check_original_format 
        CHECK (original_format IN ('jpeg', 'png')),
      CONSTRAINT check_stored_format 
        CHECK (stored_format IN ('jpeg', 'png')),
      CONSTRAINT check_deletion_time 
        CHECK (deleted_at IS NULL OR deleted_at >= uploaded_at),
      CONSTRAINT unique_active_per_user 
        UNIQUE (user_id, is_active) WHERE is_active = true
    );
  ''');

  await connection.execute('''
    CREATE INDEX idx_profile_image_user_id ON profile_image(user_id);
  ''');

  await connection.execute('''
    CREATE INDEX idx_profile_image_is_active ON profile_image(is_active);
  ''');

  await connection.execute('''
    CREATE INDEX idx_profile_image_uploaded_at ON profile_image(uploaded_at DESC);
  ''');

  await connection.execute('''
    CREATE INDEX idx_profile_image_user_active ON profile_image(user_id, is_active) WHERE is_active = true;
  ''');

  print('[✓] Table created: profile_image');
}

/// Rollback: Drop profile_image table
Future<void> down(Connection connection) async {
  await connection.execute('''
    DROP TABLE IF EXISTS profile_image CASCADE;
  ''');

  print('[✓] Table dropped: profile_image');
}
