import 'package:serverpod_migration_server/migration_server.dart';

// Migration 015: Add profile indexes
// Creates indexes for optimizing profile queries on user and profile_image tables
class Migration_20260313_015_AddProfileIndexes extends Migration {
  @override
  String get name => '20260313.015_add_profile_indexes';

  @override
  Future<void> up(MigrationConnection connection) async {
    // Index for searching users by username (case-insensitive)
    await connection.executeSql('''
      CREATE INDEX idx_users_username_lower ON "public"."users"(LOWER(username));
    ''');

    // Index for quick profile lookups by user ID with active images
    await connection.executeSql('''
      CREATE INDEX idx_profile_image_active ON "public"."profile_image"(user_id) 
      WHERE deleted_at IS NULL;
    ''');

    // Index for finding most recent uploaded profile images per user
    await connection.executeSql('''
      CREATE INDEX idx_profile_image_recent ON "public"."profile_image"(user_id, uploaded_at DESC)
      WHERE deleted_at IS NULL;
    ''');

    // Index for pruning old soft-deleted images
    await connection.executeSql('''
      CREATE INDEX idx_profile_image_deleted ON "public"."profile_image"(deleted_at)
      WHERE deleted_at IS NOT NULL;
    ''');

    // Index for finding users by profile update timestamp (for sync operations)
    await connection.executeSql('''
      CREATE INDEX idx_users_profile_updated ON "public"."users"(profile_updated_at DESC)
      WHERE profile_updated_at IS NOT NULL;
    ''');
  }

  @override
  Future<void> down(MigrationConnection connection) async {
    // Drop all created indexes
    await connection.executeSql('''
      DROP INDEX IF EXISTS idx_users_profile_updated;
      DROP INDEX IF EXISTS idx_profile_image_deleted;
      DROP INDEX IF EXISTS idx_profile_image_recent;
      DROP INDEX IF EXISTS idx_profile_image_active;
      DROP INDEX IF EXISTS idx_users_username_lower;
    ''');
  }
}
