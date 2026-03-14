import 'package:postgres/postgres.dart';

/// Migration: Create password_reset_tokens table
Future<void> up(Connection connection) async {
  await connection.execute('''
    CREATE TABLE IF NOT EXISTS password_reset_tokens (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id UUID NOT NULL REFERENCES "user"(id) ON DELETE CASCADE,
      email VARCHAR(255) NOT NULL,
      token VARCHAR(255) NOT NULL UNIQUE,
      expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
      used_at TIMESTAMP WITH TIME ZONE,
      created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
      
      CONSTRAINT token_not_empty CHECK (LENGTH(token) > 0),
      CONSTRAINT email_not_empty CHECK (LENGTH(email) > 0)
    );
  ''');
  
  // Index for efficient token lookups
  await connection.execute('''
    CREATE INDEX idx_password_reset_token ON password_reset_tokens(token);
  ''');
  
  // Index for expired token cleanup
  await connection.execute('''
    CREATE INDEX idx_password_reset_expires_at ON password_reset_tokens(expires_at);
  ''');
  
  print('[✓] Table created: password_reset_tokens');
}

/// Rollback: Drop password_reset_tokens table
Future<void> down(Connection connection) async {
  await connection.execute('''
    DROP TABLE IF EXISTS password_reset_tokens CASCADE;
  ''');
  
  print('[✓] Table dropped: password_reset_tokens');
}

class Migration007 {
  static const String name = '007_create_password_reset_tokens_table';
  static const int version = 7;
}
