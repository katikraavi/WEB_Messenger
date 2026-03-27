import 'package:postgres/postgres.dart';

/// Migration: Create Device Session tables.
Future<void> up(Connection connection) async {
  await connection.execute('''
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
  ''');

  await connection.execute('''
    CREATE INDEX IF NOT EXISTS idx_device_sessions_user
    ON device_sessions(user_id);
  ''');

  print('[✓] Migration executed: 018_create_device_sessions');
}

/// Rollback: Remove Device Session tables.
Future<void> down(Connection connection) async {
  await connection.execute('''
    DROP TABLE IF EXISTS device_sessions CASCADE;
  ''');

  print('[✓] Migration rollback executed: 018_create_device_sessions');
}

/// Migration metadata.
class Migration018 {
  static const String name = '018_create_device_sessions';
  static const int version = 18;
  static const DateTime createdAt = DateTime(2026, 3, 22);
}
