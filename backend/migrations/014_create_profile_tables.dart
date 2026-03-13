import 'package:serverpod_migration_server/migration_server.dart';

// Migration 014: Create profile tables
// Adds profile fields to users table and creates profile_image table
class Migration_20260313_014_CreateProfileTables extends Migration {
  @override
  String get name => '20260313.014_create_profile_tables';

  @override
  Future<void> up(MigrationConnection connection) async {
    // Add profile fields to users table
    await connection.executeSql('''
      ALTER TABLE "public"."users"
      ADD COLUMN "profile_picture_url" text,
      ADD COLUMN "about_me" text DEFAULT '',
      ADD COLUMN "is_private_profile" boolean DEFAULT false,
      ADD COLUMN "profile_updated_at" timestamp DEFAULT CURRENT_TIMESTAMP;
    ''');

    // Create profile_image table for tracking uploaded images
    await connection.executeSql('''
      CREATE TABLE "public"."profile_image" (
        "id" bigserial PRIMARY KEY,
        "image_id" uuid DEFAULT gen_random_uuid(),
        "user_id" uuid NOT NULL REFERENCES "public"."users"("id") ON DELETE CASCADE,
        "image_url" text NOT NULL,
        "file_size" integer NOT NULL,
        "format" text NOT NULL,
        "uploaded_at" timestamp DEFAULT CURRENT_TIMESTAMP,
        "deleted_at" timestamp
      );
    ''');

    // Create indexes for profile queries
    await connection.executeSql('''
      CREATE INDEX idx_profile_image_user_id ON "public"."profile_image"("user_id");
      CREATE INDEX idx_profile_image_uploaded_at ON "public"."profile_image"("uploaded_at");
    ''');
  }

  @override
  Future<void> down(MigrationConnection connection) async {
    // Drop indexes
    await connection.executeSql('''
      DROP INDEX IF EXISTS idx_profile_image_uploaded_at;
      DROP INDEX IF EXISTS idx_profile_image_user_id;
    ''');

    // Drop profile_image table
    await connection.executeSql('''
      DROP TABLE IF EXISTS "public"."profile_image";
    ''');

    // Remove profile fields from users table
    await connection.executeSql('''
      ALTER TABLE "public"."users"
      DROP COLUMN IF EXISTS "profile_updated_at",
      DROP COLUMN IF EXISTS "is_private_profile",
      DROP COLUMN IF EXISTS "about_me",
      DROP COLUMN IF EXISTS "profile_picture_url";
    ''');
  }
}
