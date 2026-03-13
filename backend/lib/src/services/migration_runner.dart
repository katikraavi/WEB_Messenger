import 'package:postgres/postgres.dart';
import 'dart:async';

/// Migration definition encapsulating version, description, and SQL
class Migration {
  final int version;
  final String description;
  final String upSql;
  final String downSql;

  Migration({
    required this.version,
    required this.description,
    required this.upSql,
    required this.downSql,
  });

  @override
  String toString() => 'Migration(v$version: $description)';
}

/// MigrationRunner orchestrates database schema migrations
class MigrationRunner {
  final Connection connection;
  late final List<Migration> _migrations = [];

  MigrationRunner(this.connection);

  /// Initialize migration table if not exists
  Future<void> initialize() async {
    await connection.execute('''
      CREATE TABLE IF NOT EXISTS schema_migrations (
        version BIGINT PRIMARY KEY,
        description VARCHAR(255) NOT NULL,
        executed_at TIMESTAMP DEFAULT NOW()
      )
    ''');
    _setupMigrations();
  }

  /// Register all migrations
  void _setupMigrations() {
    _migrations.clear();
    _migrations.addAll([
      Migration(
        version: 1,
        description: 'Create message_status and invite_status enums',
        upSql: '''
          CREATE TYPE message_status AS ENUM ('sent', 'delivered', 'read');
          CREATE TYPE invite_status AS ENUM ('pending', 'accepted', 'declined');
        ''',
        downSql: '''
          DROP TYPE IF EXISTS invite_status CASCADE;
          DROP TYPE IF EXISTS message_status CASCADE;
        ''',
      ),
      Migration(
        version: 2,
        description: 'Create users table',
        upSql: '''
          CREATE TABLE users (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            email TEXT UNIQUE NOT NULL,
            username TEXT UNIQUE NOT NULL,
            password_hash TEXT NOT NULL,
            email_verified BOOLEAN DEFAULT FALSE,
            profile_picture_url TEXT,
            about_me TEXT,
            created_at TIMESTAMP DEFAULT NOW()
          );
          CREATE INDEX idx_users_email ON users(email);
          CREATE INDEX idx_users_username ON users(username);
        ''',
        downSql: 'DROP TABLE IF EXISTS users CASCADE',
      ),
      Migration(
        version: 3,
        description: 'Create chats table',
        upSql: '''
          CREATE TABLE chats (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            created_at TIMESTAMP DEFAULT NOW(),
            archived_by_users UUID[] DEFAULT ARRAY[]::UUID[]
          );
          CREATE INDEX idx_chats_created_at ON chats(created_at);
        ''',
        downSql: 'DROP TABLE IF EXISTS chats CASCADE',
      ),
      Migration(
        version: 4,
        description: 'Create chat_members table',
        upSql: '''
          CREATE TABLE chat_members (
            user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            chat_id UUID NOT NULL REFERENCES chats(id) ON DELETE CASCADE,
            joined_at TIMESTAMP DEFAULT NOW(),
            left_at TIMESTAMP,
            PRIMARY KEY (user_id, chat_id)
          );
          CREATE INDEX idx_chat_members_user ON chat_members(user_id);
          CREATE INDEX idx_chat_members_chat ON chat_members(chat_id);
        ''',
        downSql: 'DROP TABLE IF EXISTS chat_members CASCADE',
      ),
      Migration(
        version: 5,
        description: 'Create messages table',
        upSql: '''
          CREATE TABLE messages (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            chat_id UUID NOT NULL REFERENCES chats(id) ON DELETE CASCADE,
            sender_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
            encrypted_content TEXT NOT NULL,
            media_url TEXT,
            media_type TEXT,
            status message_status DEFAULT 'sent',
            created_at TIMESTAMP DEFAULT NOW(),
            edited_at TIMESTAMP,
            CHECK (media_url IS NULL OR media_type IS NOT NULL)
          );
          CREATE INDEX idx_messages_chat ON messages(chat_id);
          CREATE INDEX idx_messages_sender ON messages(sender_id);
          CREATE INDEX idx_messages_created_at ON messages(created_at);
        ''',
        downSql: 'DROP TABLE IF EXISTS messages CASCADE',
      ),
      Migration(
        version: 6,
        description: 'Create invites table',
        upSql: '''
          CREATE TABLE invites (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            receiver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            status invite_status DEFAULT 'pending',
            created_at TIMESTAMP DEFAULT NOW(),
            responded_at TIMESTAMP,
            UNIQUE (sender_id, receiver_id, status)
          );
          CREATE INDEX idx_invites_sender ON invites(sender_id);
          CREATE INDEX idx_invites_receiver ON invites(receiver_id);
          CREATE INDEX idx_invites_status ON invites(status);
        ''',
        downSql: 'DROP TABLE IF EXISTS invites CASCADE',
      ),
      Migration(
        version: 7,
        description: 'Create verification_token table for email verification',
        upSql: '''
          CREATE TABLE verification_token (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            token_hash VARCHAR(255) NOT NULL UNIQUE,
            expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
            used_at TIMESTAMP WITH TIME ZONE,
            created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
            CONSTRAINT token_hash_not_empty CHECK (LENGTH(token_hash) > 0),
            CONSTRAINT expires_after_created CHECK (expires_at > created_at),
            CONSTRAINT used_at_after_created CHECK (used_at IS NULL OR used_at >= created_at)
          );
          CREATE UNIQUE INDEX idx_verification_token_hash ON verification_token(token_hash);
          CREATE INDEX idx_verification_token_user_id_created ON verification_token(user_id, created_at DESC);
          CREATE INDEX idx_verification_token_expires_at ON verification_token(expires_at);
          CREATE INDEX idx_verification_token_used_at ON verification_token(used_at);
        ''',
        downSql: 'DROP TABLE IF EXISTS verification_token CASCADE',
      ),
      Migration(
        version: 8,
        description: 'Create password_reset_token table for password recovery',
        upSql: '''
          CREATE TABLE password_reset_token (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            token_hash VARCHAR(255) NOT NULL UNIQUE,
            expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
            used_at TIMESTAMP WITH TIME ZONE,
            created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
            CONSTRAINT token_hash_not_empty CHECK (LENGTH(token_hash) > 0),
            CONSTRAINT expires_after_created CHECK (expires_at > created_at),
            CONSTRAINT used_at_after_created CHECK (used_at IS NULL OR used_at >= created_at)
          );
          CREATE UNIQUE INDEX idx_password_reset_token_hash ON password_reset_token(token_hash);
          CREATE INDEX idx_password_reset_token_user_id_created ON password_reset_token(user_id, created_at DESC);
          CREATE INDEX idx_password_reset_token_expires_at ON password_reset_token(expires_at);
          CREATE INDEX idx_password_reset_token_used_at ON password_reset_token(used_at);
        ''',
        downSql: 'DROP TABLE IF EXISTS password_reset_token CASCADE',
      ),
      Migration(
        version: 9,
        description: 'Create password_reset_attempt table for rate limiting',
        upSql: '''
          CREATE TABLE password_reset_attempt (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            email VARCHAR(255) NOT NULL,
            attempted_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
            CONSTRAINT email_not_empty CHECK (LENGTH(email) > 0)
          );
          CREATE INDEX idx_password_reset_attempt_email_time ON password_reset_attempt(email, attempted_at DESC);
          CREATE INDEX idx_password_reset_attempt_attempted_at ON password_reset_attempt(attempted_at);
        ''',
        downSql: 'DROP TABLE IF EXISTS password_reset_attempt CASCADE',
      ),
      Migration(
        version: 10,
        description: 'Add verified_at column to users table',
        upSql: '''
          ALTER TABLE users ADD COLUMN verified_at TIMESTAMP WITH TIME ZONE;
          CREATE INDEX idx_users_email_verified ON users(email_verified);
          CREATE INDEX idx_users_verified_at ON users(verified_at DESC);
        ''',
        downSql: '''
          DROP INDEX IF EXISTS idx_users_verified_at;
          DROP INDEX IF EXISTS idx_users_email_verified;
          ALTER TABLE users DROP COLUMN verified_at;
        ''',
      ),
      Migration(
        version: 11,
        description: 'Add profile fields to user table',
        upSql: '''
          ALTER TABLE users 
          ADD COLUMN IF NOT EXISTS profile_picture_url TEXT,
          ADD COLUMN IF NOT EXISTS about_me TEXT DEFAULT '',
          ADD COLUMN IF NOT EXISTS is_default_profile_picture BOOLEAN DEFAULT true NOT NULL,
          ADD COLUMN IF NOT EXISTS is_private_profile BOOLEAN DEFAULT false NOT NULL,
          ADD COLUMN IF NOT EXISTS profile_updated_at TIMESTAMP WITH TIME ZONE;
          
          CREATE INDEX IF NOT EXISTS idx_users_is_private_profile ON users(is_private_profile);
          CREATE INDEX IF NOT EXISTS idx_users_profile_updated_at ON users(profile_updated_at DESC);
        ''',
        downSql: '''
          DROP INDEX IF EXISTS idx_users_profile_updated_at;
          DROP INDEX IF EXISTS idx_users_is_private_profile;
          ALTER TABLE users
          DROP COLUMN IF EXISTS profile_picture_url,
          DROP COLUMN IF EXISTS about_me,
          DROP COLUMN IF EXISTS is_default_profile_picture,
          DROP COLUMN IF EXISTS is_private_profile,
          DROP COLUMN IF EXISTS profile_updated_at;
        ''',
      ),
      Migration(
        version: 12,
        description: 'Create profile_image table',
        upSql: '''
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
              FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
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
          
          CREATE INDEX idx_profile_image_user_id ON profile_image(user_id);
          CREATE INDEX idx_profile_image_is_active ON profile_image(is_active);
          CREATE INDEX idx_profile_image_uploaded_at ON profile_image(uploaded_at DESC);
          CREATE INDEX idx_profile_image_user_active ON profile_image(user_id, is_active) WHERE is_active = true;
        ''',
        downSql: '''
          DROP TABLE IF EXISTS profile_image CASCADE;
        ''',
      ),
      Migration(
        version: 13,
        description: 'Add search indexes for user search feature',
        upSql: '''
          CREATE INDEX IF NOT EXISTS idx_user_username_lower ON users(LOWER(username));
          CREATE INDEX IF NOT EXISTS idx_user_email_lower ON users(LOWER(email));
          CREATE INDEX IF NOT EXISTS idx_user_is_verified ON users(email_verified);
        ''',
        downSql: '''
          DROP INDEX IF EXISTS idx_user_is_verified;
          DROP INDEX IF EXISTS idx_user_email_lower;
          DROP INDEX IF EXISTS idx_user_username_lower;
        ''',
      ),
    ]);
  }

  /// Get all migrations ordered by version
  List<Migration> getAllMigrations() => _migrations;

  /// Check which migrations have been applied
  Future<Set<int>> getAppliedMigrations() async {
    try {
      final result = await connection.query(
        'SELECT version FROM schema_migrations ORDER BY version',
      );
      return {for (final row in result) row[0] as int};
    } catch (e) {
      return {};
    }
  }

  /// Get pending migrations that haven't been applied
  Future<List<Migration>> getPendingMigrations() async {
    final applied = await getAppliedMigrations();
    return _migrations.where((m) => !applied.contains(m.version)).toList();
  }

  /// Run all pending migrations
  Future<void> runMigrations() async {
    await initialize();
    final pending = await getPendingMigrations();
    
    for (final migration in pending) {
      try {
        await connection.execute(migration.upSql);
        await connection.execute(
          'INSERT INTO schema_migrations (version, description) VALUES (\$1, \$2)',
          parameters: [migration.version, migration.description],
        );
        print('✓ Applied migration ${migration.version}: ${migration.description}');
      } catch (e) {
        print('✗ Failed migration ${migration.version}: $e');
        rethrow;
      }
    }
  }

  /// Rollback to a specific version
  Future<void> rollbackTo(int targetVersion) async {
    await initialize();
    final applied = await getAppliedMigrations();
    
    for (final version in applied) {
      if (version > targetVersion) {
        final migration = _migrations.firstWhere((m) => m.version == version);
        try {
          await connection.execute(migration.downSql);
          await connection.execute(
            'DELETE FROM schema_migrations WHERE version = \$1',
            parameters: [version],
          );
          print('↻ Rolled back migration ${migration.version}');
        } catch (e) {
          print('✗ Failed rollback ${migration.version}: $e');
          rethrow;
        }
      }
    }
  }

  /// Get detailed status of all migrations
  Future<Map<String, dynamic>> getMigrationStatus() async {
    final applied = await getAppliedMigrations();
    final pending = await getPendingMigrations();
    
    return {
      'total': _migrations.length,
      'applied': applied.length,
      'pending': pending.length,
      'migrations': [
        for (final m in _migrations)
          {
            'version': m.version,
            'description': m.description,
            'status': applied.contains(m.version) ? 'APPLIED' : 'PENDING',
          }
      ],
    };
  }
}
