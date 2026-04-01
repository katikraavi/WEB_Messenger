import 'package:postgres/postgres.dart';
import 'dart:async';

// Alias for cleaner code
typedef Connection = PostgreSQLConnection;

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
          DO \$\$ BEGIN
            IF NOT EXISTS (SELECT FROM pg_type WHERE typname = 'message_status') THEN
              CREATE TYPE message_status AS ENUM ('sent', 'delivered', 'read');
            END IF;
          END \$\$;
          
          DO \$\$ BEGIN
            IF NOT EXISTS (SELECT FROM pg_type WHERE typname = 'invite_status') THEN
              CREATE TYPE invite_status AS ENUM ('pending', 'accepted', 'declined');
            END IF;
          END \$\$;
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
          CREATE TABLE IF NOT EXISTS "users" (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            email TEXT UNIQUE NOT NULL,
            username TEXT UNIQUE NOT NULL,
            password_hash TEXT NOT NULL,
            email_verified BOOLEAN DEFAULT FALSE,
            profile_picture_url TEXT,
            about_me TEXT,
            is_private_profile BOOLEAN DEFAULT FALSE,
            profile_updated_at TIMESTAMP,
            last_password_changed TIMESTAMP,
            last_login_at TIMESTAMP,
            verified_at TIMESTAMP,
            created_at TIMESTAMP DEFAULT NOW()
          );
          CREATE INDEX IF NOT EXISTS idx_users_email ON "users"(email);
          CREATE INDEX IF NOT EXISTS idx_users_username ON "users"(username);
          CREATE INDEX IF NOT EXISTS idx_users_created_at ON "users"(created_at DESC);
        ''',
        downSql: 'DROP TABLE IF EXISTS "users" CASCADE',
      ),
      Migration(
        version: 3,
        description: 'Create chats table',
        upSql: '''
          CREATE TABLE IF NOT EXISTS chats (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            created_at TIMESTAMP DEFAULT NOW(),
            archived_by_users UUID[] DEFAULT ARRAY[]::UUID[]
          );
          CREATE INDEX IF NOT EXISTS idx_chats_created_at ON chats(created_at);
        ''',
        downSql: 'DROP TABLE IF EXISTS chats CASCADE',
      ),
      Migration(
        version: 4,
        description: 'Create chat_members table',
        upSql: '''
          CREATE TABLE IF NOT EXISTS chat_members (
            user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            chat_id UUID NOT NULL REFERENCES chats(id) ON DELETE CASCADE,
            joined_at TIMESTAMP DEFAULT NOW(),
            left_at TIMESTAMP,
            PRIMARY KEY (user_id, chat_id)
          );
          CREATE INDEX IF NOT EXISTS idx_chat_members_user ON chat_members(user_id);
          CREATE INDEX IF NOT EXISTS idx_chat_members_chat ON chat_members(chat_id);
        ''',
        downSql: 'DROP TABLE IF EXISTS chat_members CASCADE',
      ),
      Migration(
        version: 5,
        description: 'Create messages table',
        upSql: '''
          CREATE TABLE IF NOT EXISTS messages (
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
          CREATE INDEX IF NOT EXISTS idx_messages_chat ON messages(chat_id);
          CREATE INDEX IF NOT EXISTS idx_messages_sender ON messages(sender_id);
          CREATE INDEX IF NOT EXISTS idx_messages_created_at ON messages(created_at);
        ''',
        downSql: 'DROP TABLE IF EXISTS messages CASCADE',
      ),
      Migration(
        version: 6,
        description: 'Create invites table',
        upSql: '''
          CREATE TABLE IF NOT EXISTS invites (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            receiver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            status invite_status DEFAULT 'pending',
            created_at TIMESTAMP DEFAULT NOW(),
            responded_at TIMESTAMP,
            UNIQUE (sender_id, receiver_id, status)
          );
          CREATE INDEX IF NOT EXISTS idx_invites_sender ON invites(sender_id);
          CREATE INDEX IF NOT EXISTS idx_invites_receiver ON invites(receiver_id);
          CREATE INDEX IF NOT EXISTS idx_invites_status ON invites(status);
        ''',
        downSql: 'DROP TABLE IF EXISTS invites CASCADE',
      ),
      Migration(
        version: 7,
        description: 'Create verification_token table for email verification',
        upSql: '''
          CREATE TABLE IF NOT EXISTS verification_token (
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
          CREATE UNIQUE INDEX IF NOT EXISTS idx_verification_token_hash ON verification_token(token_hash);
          CREATE INDEX IF NOT EXISTS idx_verification_token_user_id_created ON verification_token(user_id, created_at DESC);
          CREATE INDEX IF NOT EXISTS idx_verification_token_expires_at ON verification_token(expires_at);
          CREATE INDEX IF NOT EXISTS idx_verification_token_used_at ON verification_token(used_at);
        ''',
        downSql: 'DROP TABLE IF EXISTS verification_token CASCADE',
      ),
      Migration(
        version: 8,
        description: 'Create password_reset_token table for password recovery',
        upSql: '''
          CREATE TABLE IF NOT EXISTS password_reset_token (
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
          CREATE UNIQUE INDEX IF NOT EXISTS idx_password_reset_token_hash ON password_reset_token(token_hash);
          CREATE INDEX IF NOT EXISTS idx_password_reset_token_user_id_created ON password_reset_token(user_id, created_at DESC);
          CREATE INDEX IF NOT EXISTS idx_password_reset_token_expires_at ON password_reset_token(expires_at);
          CREATE INDEX IF NOT EXISTS idx_password_reset_token_used_at ON password_reset_token(used_at);
        ''',
        downSql: 'DROP TABLE IF EXISTS password_reset_token CASCADE',
      ),
      Migration(
        version: 9,
        description: 'Create password_reset_attempt table for rate limiting',
        upSql: '''
          CREATE TABLE IF NOT EXISTS password_reset_attempt (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            email VARCHAR(255) NOT NULL,
            attempted_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
            CONSTRAINT email_not_empty CHECK (LENGTH(email) > 0)
          );
          CREATE INDEX IF NOT EXISTS idx_password_reset_attempt_email_time ON password_reset_attempt(email, attempted_at DESC);
          CREATE INDEX IF NOT EXISTS idx_password_reset_attempt_attempted_at ON password_reset_attempt(attempted_at);
        ''',
        downSql: 'DROP TABLE IF EXISTS password_reset_attempt CASCADE',
      ),
      Migration(
        version: 10,
        description: 'Add verified_at column to users table',
        upSql: '''
          -- verified_at column already added in migration 2
          -- Just ensure indexes exist
          CREATE INDEX IF NOT EXISTS idx_users_email_verified ON users(email_verified);
          CREATE INDEX IF NOT EXISTS idx_users_verified_at ON users(verified_at DESC);
        ''',
        downSql: '''
          DROP INDEX IF EXISTS idx_users_verified_at;
          DROP INDEX IF EXISTS idx_users_email_verified;
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
              CHECK (deleted_at IS NULL OR deleted_at >= uploaded_at)
          );
          
          CREATE UNIQUE INDEX IF NOT EXISTS idx_profile_image_user_active_unique ON profile_image(user_id, is_active) WHERE is_active = true;
          CREATE INDEX IF NOT EXISTS idx_profile_image_user_id ON profile_image(user_id);
          CREATE INDEX IF NOT EXISTS idx_profile_image_is_active ON profile_image(is_active);
          CREATE INDEX IF NOT EXISTS idx_profile_image_uploaded_at ON profile_image(uploaded_at DESC);
          CREATE INDEX IF NOT EXISTS idx_profile_image_user_active ON profile_image(user_id, is_active) WHERE is_active = true;
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
      Migration(
        version: 14,
        description: '019-chat-list: Recreate chats and messages tables with proper schema',
        upSql: '''
          -- Drop existing chat_members table if it exists
          DROP TABLE IF EXISTS chat_members CASCADE;
          
          -- Drop existing chats and messages tables
          DROP TABLE IF EXISTS messages CASCADE;
          DROP TABLE IF EXISTS chats CASCADE;
          
          -- Create chats table with participant-based design and per-user archive support
          CREATE TABLE IF NOT EXISTS chats (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            participant_1_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            participant_2_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            is_participant_1_archived BOOLEAN NOT NULL DEFAULT FALSE,
            is_participant_2_archived BOOLEAN NOT NULL DEFAULT FALSE,
            created_at TIMESTAMP NOT NULL DEFAULT NOW(),
            updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
            
            -- Constraint: enforce 1:1 relationships (no duplicates)
            UNIQUE(participant_1_id, participant_2_id),
            
            -- Constraint: prevent self-chat
            CHECK(participant_1_id <> participant_2_id)
          );
          
          -- Index for efficient list query (find all active chats for user sorted by recency)
          CREATE INDEX IF NOT EXISTS idx_chats_participant_1_active 
          ON chats(participant_1_id, updated_at DESC) 
          WHERE is_participant_1_archived = FALSE;
          
          -- Separate index for participant 2
          CREATE INDEX IF NOT EXISTS idx_chats_participant_2_active 
          ON chats(participant_2_id, updated_at DESC) 
          WHERE is_participant_2_archived = FALSE;
          
          -- Create messages table with encrypted content (end-to-end encrypted)
          CREATE TABLE IF NOT EXISTS messages (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            chat_id UUID NOT NULL REFERENCES chats(id) ON DELETE CASCADE,
            sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            
            -- Base64-encoded ChaCha20-Poly1305 encrypted message content
            -- Never store plaintext in database
            encrypted_content TEXT NOT NULL,
            
            created_at TIMESTAMP NOT NULL DEFAULT NOW()
          );
          
          -- Index for efficient message history fetch (chat + timestamp for pagination)
          CREATE INDEX IF NOT EXISTS idx_messages_chat_created 
          ON messages(chat_id, created_at DESC);
          
          -- Index for user's sent messages (for filtering/analytics)
          CREATE INDEX IF NOT EXISTS idx_messages_sender 
          ON messages(sender_id, created_at DESC);
        ''',
        downSql: '''
          DROP TABLE IF EXISTS messages CASCADE;
          DROP TABLE IF EXISTS chats CASCADE;
        ''',
      ),
      Migration(
        version: 15,
        description: '020-messaging: Update messages table with status tracking and soft-delete',
        upSql: '''
          -- Add missing columns to messages table for full messaging support
          ALTER TABLE messages
          ADD COLUMN IF NOT EXISTS recipient_id UUID,
          ADD COLUMN IF NOT EXISTS status VARCHAR(20) NOT NULL DEFAULT 'sent',
          ADD COLUMN IF NOT EXISTS edited_at TIMESTAMP,
          ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP,
          ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN NOT NULL DEFAULT FALSE;
          
          -- Add foreign key constraint for recipient (nullable for backwards compatibility)
          DO \$\$ BEGIN
            ALTER TABLE messages
            ADD CONSTRAINT fk_messages_recipient FOREIGN KEY (recipient_id) 
              REFERENCES users(id) ON DELETE CASCADE;
          EXCEPTION WHEN duplicate_object THEN NULL; END \$\$;
          
          -- Add index for recipient status queries (find unread messages for a user)
          CREATE INDEX IF NOT EXISTS idx_messages_recipient_status 
          ON messages(recipient_id, status, created_at DESC) WHERE recipient_id IS NOT NULL;
          
          -- Add index for efficient soft-delete filtering
          CREATE INDEX IF NOT EXISTS idx_messages_is_deleted 
          ON messages(is_deleted);
          
          -- Add constraint to ensure edited_at is after created_at
          DO \$\$ BEGIN
            ALTER TABLE messages
            ADD CONSTRAINT check_edited_after_created 
              CHECK (edited_at IS NULL OR edited_at >= created_at);
          EXCEPTION WHEN duplicate_object THEN NULL; END \$\$;
          
          -- Add constraint to ensure deleted_at is after created_at
          DO \$\$ BEGIN
            ALTER TABLE messages
            ADD CONSTRAINT check_deleted_after_created 
              CHECK (deleted_at IS NULL OR deleted_at >= created_at);
          EXCEPTION WHEN duplicate_object THEN NULL; END \$\$;
        ''',
        downSql: '''
          -- Remove new columns and constraints from messages table
          ALTER TABLE messages
          DROP CONSTRAINT IF EXISTS check_deleted_after_created,
          DROP CONSTRAINT IF EXISTS check_edited_after_created,
          DROP CONSTRAINT IF EXISTS fk_messages_recipient,
          DROP COLUMN IF EXISTS recipient_id,
          DROP COLUMN IF EXISTS status,
          DROP COLUMN IF EXISTS edited_at,
          DROP COLUMN IF EXISTS deleted_at,
          DROP COLUMN IF EXISTS is_deleted;
          
          DROP INDEX IF EXISTS idx_messages_is_deleted;
          DROP INDEX IF EXISTS idx_messages_recipient_status;
        ''',
      ),
      Migration(
        version: 16,
        description: '020-messaging: Create message_delivery_status table for per-recipient delivery tracking',
        upSql: '''
          -- Create message_delivery_status table to track delivery/read status per recipient
          -- Named message_delivery_status to avoid conflict with message_status ENUM type from migration 1
          CREATE TABLE IF NOT EXISTS message_delivery_status (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            message_id UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
            recipient_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            status VARCHAR(20) NOT NULL DEFAULT 'sent',
            delivered_at TIMESTAMP,
            read_at TIMESTAMP,
            updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
            
            -- Unique constraint: one status record per message-recipient pair
            UNIQUE (message_id, recipient_id)
          );
          
          -- Index for finding unread messages for a user
          CREATE INDEX IF NOT EXISTS idx_message_delivery_status_recipient_unread 
          ON message_delivery_status(recipient_id, status, updated_at DESC) 
          WHERE status != 'read';
          
          -- Index for message status lookup by message
          CREATE INDEX IF NOT EXISTS idx_message_delivery_status_message 
          ON message_delivery_status(message_id);
          
          -- Index for recipient queries
          CREATE INDEX IF NOT EXISTS idx_message_delivery_status_recipient 
          ON message_delivery_status(recipient_id, updated_at DESC);
        ''',
        downSql: '''
          DROP TABLE IF EXISTS message_delivery_status CASCADE;
        ''',
      ),
      Migration(
        version: 17,
        description: '020-messaging: Create message_edits table for audit trail and edit history',
        upSql: '''
          -- Create message_edits table to maintain immutable audit trail of message edits
          CREATE TABLE IF NOT EXISTS message_edits (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            message_id UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
            edit_number INTEGER NOT NULL CHECK (edit_number >= 1),
            previous_content TEXT NOT NULL,  -- Encrypted, just like messages.encrypted_content
            edited_at TIMESTAMP NOT NULL DEFAULT NOW(),
            edited_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
            
            -- Constraint: unique per message and edit number (no duplicates)
            UNIQUE (message_id, edit_number)
          );
          
          -- Index for retrieving edit history for a message
          CREATE INDEX IF NOT EXISTS idx_message_edits_message 
          ON message_edits(message_id, edit_number DESC);
          
          -- Index for user's edits
          CREATE INDEX IF NOT EXISTS idx_message_edits_edited_by 
          ON message_edits(edited_by, edited_at DESC);
        ''',
        downSql: '''
          DROP TABLE IF EXISTS message_edits CASCADE;
        ''',
      ),
      Migration(
        version: 18,
        description: '010-media-messaging: Create media_storage table for uploaded files',
        upSql: '''
          CREATE TABLE IF NOT EXISTS media_storage (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            uploader_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            file_name VARCHAR(255) NOT NULL,
            mime_type VARCHAR(100),
            file_size_bytes INTEGER NOT NULL,
            file_path TEXT NOT NULL,
            original_name TEXT,
            created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
            
            CONSTRAINT fk_media_uploader FOREIGN KEY (uploader_id) 
              REFERENCES users(id) ON DELETE CASCADE,
            CONSTRAINT valid_file_size CHECK (file_size_bytes > 0 AND file_size_bytes <= 52428800)
          );
          
          CREATE INDEX IF NOT EXISTS idx_media_uploader_created 
          ON media_storage(uploader_id, created_at DESC);
          
          CREATE INDEX IF NOT EXISTS idx_media_created_at 
          ON media_storage(created_at DESC);
        ''',
        downSql: '''
          DROP TABLE IF EXISTS media_storage CASCADE;
        ''',
      ),
      Migration(
        version: 19,
        description: '010-media-messaging: Add media_url and media_type columns back to messages table',
        upSql: '''
          ALTER TABLE messages
          ADD COLUMN IF NOT EXISTS media_url TEXT,
          ADD COLUMN IF NOT EXISTS media_type TEXT;

          ALTER TABLE messages
          DROP CONSTRAINT IF EXISTS messages_media_consistency_check;

          ALTER TABLE messages
          ADD CONSTRAINT messages_media_consistency_check
          CHECK (media_url IS NULL OR media_type IS NOT NULL);
        ''',
        downSql: '''
          ALTER TABLE messages
          DROP CONSTRAINT IF EXISTS messages_media_consistency_check,
          DROP COLUMN IF EXISTS media_url,
          DROP COLUMN IF EXISTS media_type;
        ''',
      ),
      Migration(
        version: 20,
        description: '010-media-messaging: Raise media_storage size limit to 50MB',
        upSql: '''
          ALTER TABLE media_storage
          DROP CONSTRAINT IF EXISTS valid_file_size;

          ALTER TABLE media_storage
          ADD CONSTRAINT valid_file_size
          CHECK (file_size_bytes > 0 AND file_size_bytes <= 52428800);
        ''',
        downSql: '''
          ALTER TABLE media_storage
          DROP CONSTRAINT IF EXISTS valid_file_size;

          ALTER TABLE media_storage
          ADD CONSTRAINT valid_file_size
          CHECK (file_size_bytes > 0 AND file_size_bytes <= 20971520);
        ''',
      ),
      Migration(
        version: 21,
        description: 'Add notification device tokens and per-chat mute preferences',
        upSql: '''
          CREATE TABLE IF NOT EXISTS push_device_tokens (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            device_token TEXT NOT NULL UNIQUE,
            platform VARCHAR(50),
            created_at TIMESTAMP NOT NULL DEFAULT NOW(),
            updated_at TIMESTAMP NOT NULL DEFAULT NOW()
          );

          CREATE INDEX IF NOT EXISTS idx_push_device_tokens_user_id
          ON push_device_tokens(user_id);

          CREATE TABLE IF NOT EXISTS chat_notification_preferences (
            chat_id UUID NOT NULL REFERENCES chats(id) ON DELETE CASCADE,
            user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            is_muted BOOLEAN NOT NULL DEFAULT FALSE,
            updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
            PRIMARY KEY (chat_id, user_id)
          );

          CREATE INDEX IF NOT EXISTS idx_chat_notification_preferences_user_muted
          ON chat_notification_preferences(user_id, is_muted, updated_at DESC);
        ''',
        downSql: '''
          DROP TABLE IF EXISTS chat_notification_preferences CASCADE;
          DROP TABLE IF EXISTS push_device_tokens CASCADE;
        ''',
      ),
      Migration(
        version: 22,
        description: 'Add device_sessions table for selective logout',
        upSql: '''
          CREATE TABLE IF NOT EXISTS device_sessions (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            device_id TEXT NOT NULL,
            device_name TEXT,
            token_hash TEXT NOT NULL,
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            UNIQUE (user_id, device_id)
          );

          CREATE INDEX IF NOT EXISTS idx_device_sessions_user
          ON device_sessions(user_id);
        ''',
        downSql: '''
          DROP TABLE IF EXISTS device_sessions CASCADE;
        ''',
      ),
      Migration(
        version: 23,
        description: 'Create group_chats, group_members, group_invites tables',
        upSql: '''
          CREATE TABLE IF NOT EXISTS group_chats (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            name TEXT NOT NULL,
            created_by UUID REFERENCES users(id) ON DELETE SET NULL,
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            is_public BOOLEAN NOT NULL DEFAULT false
          );

          CREATE TABLE IF NOT EXISTS group_members (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            group_id UUID NOT NULL REFERENCES group_chats(id) ON DELETE CASCADE,
            user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            role TEXT NOT NULL DEFAULT 'member',
            joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            UNIQUE (group_id, user_id)
          );

          CREATE TABLE IF NOT EXISTS group_invites (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            group_id UUID NOT NULL REFERENCES group_chats(id) ON DELETE CASCADE,
            sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            receiver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            status TEXT NOT NULL DEFAULT 'pending',
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            UNIQUE (group_id, receiver_id)
          );

          CREATE INDEX IF NOT EXISTS idx_group_members_user
          ON group_members(user_id);

          CREATE INDEX IF NOT EXISTS idx_group_invites_receiver
          ON group_invites(receiver_id, status);
        ''',
        downSql: '''
          DROP TABLE IF EXISTS group_invites CASCADE;
          DROP TABLE IF EXISTS group_members CASCADE;
          DROP TABLE IF EXISTS group_chats CASCADE;
        ''',
      ),
      Migration(
        version: 24,
        description: 'Allow messages.chat_id to reference direct or group threads',
        upSql: '''
          ALTER TABLE messages
          DROP CONSTRAINT IF EXISTS messages_chat_id_fkey;
        ''',
        downSql: '''
          ALTER TABLE messages
          DROP CONSTRAINT IF EXISTS messages_chat_id_fkey;
          
          DO \\$\\$ BEGIN
            ALTER TABLE messages
            ADD CONSTRAINT messages_chat_id_fkey
            FOREIGN KEY (chat_id) REFERENCES chats(id) ON DELETE CASCADE;
          EXCEPTION WHEN duplicate_object THEN NULL; END \\$\\$;
        ''',
      ),
      Migration(
        version: 25,
        description: 'Create Poll tables for group chat polling feature',
        upSql: '''
          CREATE TABLE IF NOT EXISTS polls (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            group_id UUID NOT NULL REFERENCES group_chats(id) ON DELETE CASCADE,
            created_by UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            question TEXT NOT NULL,
            is_anonymous BOOLEAN NOT NULL DEFAULT false,
            is_closed BOOLEAN NOT NULL DEFAULT false,
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            closes_at TIMESTAMPTZ
          );

          CREATE TABLE IF NOT EXISTS poll_options (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            poll_id UUID NOT NULL REFERENCES polls(id) ON DELETE CASCADE,
            text TEXT NOT NULL,
            position SMALLINT NOT NULL
          );

          CREATE TABLE IF NOT EXISTS poll_votes (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            poll_id UUID NOT NULL REFERENCES polls(id) ON DELETE CASCADE,
            option_id UUID NOT NULL REFERENCES poll_options(id) ON DELETE CASCADE,
            user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            voted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            UNIQUE (poll_id, user_id)
          );

          CREATE INDEX IF NOT EXISTS idx_polls_group ON polls(group_id);
          CREATE INDEX IF NOT EXISTS idx_poll_votes_poll ON poll_votes(poll_id);
        ''',
        downSql: '''
          DROP TABLE IF EXISTS poll_votes CASCADE;
          DROP TABLE IF EXISTS poll_options CASCADE;
          DROP TABLE IF EXISTS polls CASCADE;
        ''',
      ),
      Migration(
        version: 26,
        description: 'Add archive support for group chats',
        upSql: '''
          ALTER TABLE group_members
          ADD COLUMN IF NOT EXISTS is_archived BOOLEAN NOT NULL DEFAULT false;
        ''',
        downSql: '''
          ALTER TABLE group_members
          DROP COLUMN IF EXISTS is_archived;
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
          'INSERT INTO schema_migrations (version, description) VALUES (@version, @description)',
          substitutionValues: {'version': migration.version, 'description': migration.description},
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
            'DELETE FROM schema_migrations WHERE version = @version',
            substitutionValues: {'version': version},
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
