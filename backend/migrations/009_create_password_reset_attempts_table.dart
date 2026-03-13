import 'package:postgres/postgres.dart';

/// Migration: Create PasswordResetAttempt table for rate limiting password resets
Future<void> up(Connection connection) async {
  await connection.execute('''
    CREATE TABLE IF NOT EXISTS password_reset_attempt (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      email VARCHAR(255) NOT NULL,
      attempted_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
      
      -- Constraints
      CONSTRAINT email_not_empty CHECK (LENGTH(email) > 0)
    );
  ''');
  
  -- Create indexes for rate limiting queries
  await connection.execute('''
    CREATE COMPOSITE INDEX idx_password_reset_attempt_email_time 
    ON password_reset_attempt(email, attempted_at DESC);
  ''');
  
  await connection.execute('''
    CREATE INDEX idx_password_reset_attempt_attempted_at ON password_reset_attempt(attempted_at);
  ''');
  
  print('[✓] Table created: password_reset_attempt');
}

/// Rollback: Drop PasswordResetAttempt table
Future<void> down(Connection connection) async {
  await connection.execute('''
    DROP TABLE IF EXISTS password_reset_attempt CASCADE;
  ''');
  
  print('[✓] Table dropped: password_reset_attempt');
}

/// Migration metadata
class Migration009 {
  static const String name = '009_create_password_reset_attempts_table';
}
