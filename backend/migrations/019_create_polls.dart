import 'package:postgres/postgres.dart';

/// Migration: Create Poll tables.
Future<void> up(Connection connection) async {
  await connection.execute('''
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
  ''');

  await connection.execute('''
    CREATE TABLE IF NOT EXISTS poll_options (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      poll_id UUID NOT NULL REFERENCES polls(id) ON DELETE CASCADE,
      text TEXT NOT NULL,
      position SMALLINT NOT NULL
    );
  ''');

  await connection.execute('''
    CREATE TABLE IF NOT EXISTS poll_votes (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      poll_id UUID NOT NULL REFERENCES polls(id) ON DELETE CASCADE,
      option_id UUID NOT NULL REFERENCES poll_options(id) ON DELETE CASCADE,
      user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      voted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      UNIQUE (poll_id, user_id)
    );
  ''');

  await connection.execute('''
    CREATE INDEX IF NOT EXISTS idx_polls_group
    ON polls(group_id);
  ''');

  await connection.execute('''
    CREATE INDEX IF NOT EXISTS idx_poll_votes_poll
    ON poll_votes(poll_id);
  ''');

  print('[✓] Migration executed: 019_create_polls');
}

/// Rollback: Remove Poll tables.
Future<void> down(Connection connection) async {
  await connection.execute('''
    DROP TABLE IF EXISTS poll_votes CASCADE;
  ''');

  await connection.execute('''
    DROP TABLE IF EXISTS poll_options CASCADE;
  ''');

  await connection.execute('''
    DROP TABLE IF EXISTS polls CASCADE;
  ''');

  print('[✓] Migration rollback executed: 019_create_polls');
}

/// Migration metadata.
class Migration019 {
  static const String name = '019_create_polls';
  static const int version = 19;
  static const DateTime createdAt = DateTime(2026, 3, 22);
}
