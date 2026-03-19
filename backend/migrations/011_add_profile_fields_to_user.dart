import 'package:postgres/postgres.dart';

/// Migration: Add profile fields to user table
Future<void> up(Connection connection) async {
  await connection.execute('''
    ALTER TABLE "users" 
    ADD COLUMN IF NOT EXISTS profile_picture_url TEXT,
    ADD COLUMN IF NOT EXISTS about_me TEXT DEFAULT '',
    ADD COLUMN IF NOT EXISTS is_default_profile_picture BOOLEAN DEFAULT true NOT NULL,
    ADD COLUMN IF NOT EXISTS is_private_profile BOOLEAN DEFAULT false NOT NULL,
    ADD COLUMN IF NOT EXISTS profile_updated_at TIMESTAMP WITH TIME ZONE;
  ''');

  await connection.execute('''
    CREATE INDEX IF NOT EXISTS idx_user_is_private_profile ON "users"(is_private_profile);
  ''');

  await connection.execute('''
    CREATE INDEX IF NOT EXISTS idx_user_profile_updated_at ON "users"(profile_updated_at DESC);
  ''');

  print('[✓] Columns added to user table: profile_picture_url, about_me, is_default_profile_picture, is_private_profile, profile_updated_at');
}

/// Rollback: Remove profile fields from user table
Future<void> down(Connection connection) async {
  await connection.execute('''
    DROP INDEX IF EXISTS idx_user_profile_updated_at;
  ''');

  await connection.execute('''
    DROP INDEX IF EXISTS idx_user_is_private_profile;
  ''');

  await connection.execute('''
    ALTER TABLE "users"
    DROP COLUMN IF EXISTS profile_picture_url,
    DROP COLUMN IF EXISTS about_me,
    DROP COLUMN IF EXISTS is_default_profile_picture,
    DROP COLUMN IF EXISTS is_private_profile,
    DROP COLUMN IF EXISTS profile_updated_at;
  ''');

  print('[✓] Profile columns removed from user table');
}
