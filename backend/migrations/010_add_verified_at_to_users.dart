import 'package:postgres/postgres.dart';

/// Migration: Add verified_at timestamp column to Users table for email verification audit trail
Future<void> up(Connection connection) async {
  await connection.execute('''
    ALTER TABLE "user" 
    ADD COLUMN verified_at TIMESTAMP WITH TIME ZONE;
  ''');
  
  -- Create indexes for verification queries
  await connection.execute('''
    CREATE INDEX idx_user_email_verified ON "user"(email_verified);
  ''');
  
  await connection.execute('''
    CREATE INDEX idx_user_verified_at ON "user"(verified_at DESC);
  ''');
  
  print('[✓] Column added to user table: verified_at');
  print('[✓] Indexes created for email verification');
}

/// Rollback: Remove verified_at column from Users table
Future<void> down(Connection connection) async {
  await connection.execute('''
    DROP INDEX IF EXISTS idx_user_verified_at;
  ''');
  
  await connection.execute('''
    DROP INDEX IF EXISTS idx_user_email_verified;
  ''');
  
  await connection.execute('''
    ALTER TABLE "user" DROP COLUMN verified_at;
  ''');
  
  print('[✓] Column removed from user table: verified_at');
}

/// Migration metadata
class Migration010 {
  static const String name = '010_add_verified_at_to_users';
}
