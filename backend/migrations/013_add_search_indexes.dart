import 'package:postgres/postgres.dart';

/// Migration: Add search indexes for user search feature
Future<void> up(Connection connection) async {
  // Create case-insensitive index on username for fast search
  await connection.execute('''
    CREATE INDEX IF NOT EXISTS idx_user_username_lower ON "user"(LOWER(username));
  ''');

  // Create case-insensitive index on email for fast search
  await connection.execute('''
    CREATE INDEX IF NOT EXISTS idx_user_email_lower ON "user"(LOWER(email));
  ''');

  // Create index on is_verified to filter verified users during search
  await connection.execute('''
    CREATE INDEX IF NOT EXISTS idx_user_is_verified ON "user"(is_verified);
  ''');

  print('[✓] Search indexes created: idx_user_username_lower, idx_user_email_lower, idx_user_is_verified');
}

/// Rollback: Remove search indexes from user table
Future<void> down(Connection connection) async {
  await connection.execute('''
    DROP INDEX IF EXISTS idx_user_username_lower;
  ''');

  await connection.execute('''
    DROP INDEX IF EXISTS idx_user_email_lower;
  ''');

  await connection.execute('''
    DROP INDEX IF EXISTS idx_user_is_verified;
  ''');

  print('[✓] Search indexes removed from user table');
}
