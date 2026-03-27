import 'package:postgres/postgres.dart';

/// Migration: Create Group Chat tables.
Future<void> up(Connection connection) async {
  await connection.execute('''
    CREATE TABLE IF NOT EXISTS group_chats (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      name TEXT NOT NULL,
      created_by UUID REFERENCES users(id) ON DELETE SET NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      is_public BOOLEAN NOT NULL DEFAULT false
    );
  ''');

  await connection.execute('''
    CREATE TABLE IF NOT EXISTS group_members (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      group_id UUID NOT NULL REFERENCES group_chats(id) ON DELETE CASCADE,
      user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      role TEXT NOT NULL DEFAULT 'member',
      joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      UNIQUE (group_id, user_id)
    );
  ''');

  await connection.execute('''
    CREATE TABLE IF NOT EXISTS group_invites (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      group_id UUID NOT NULL REFERENCES group_chats(id) ON DELETE CASCADE,
      sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      receiver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      status TEXT NOT NULL DEFAULT 'pending',
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      UNIQUE (group_id, receiver_id)
    );
  ''');

  await connection.execute('''
    CREATE INDEX IF NOT EXISTS idx_group_members_user
    ON group_members(user_id);
  ''');

  await connection.execute('''
    CREATE INDEX IF NOT EXISTS idx_group_invites_receiver
    ON group_invites(receiver_id, status);
  ''');

  print('[✓] Migration executed: 017_create_group_chats');
}

/// Rollback: Remove Group Chat tables.
Future<void> down(Connection connection) async {
  await connection.execute('''
    DROP TABLE IF EXISTS group_invites CASCADE;
  ''');

  await connection.execute('''
    DROP TABLE IF EXISTS group_members CASCADE;
  ''');

  await connection.execute('''
    DROP TABLE IF EXISTS group_chats CASCADE;
  ''');

  print('[✓] Migration rollback executed: 017_create_group_chats');
}

/// Migration metadata.
class Migration017 {
  static const String name = '017_create_group_chats';
  static const int version = 17;
  static const DateTime createdAt = DateTime(2026, 3, 22);
}
