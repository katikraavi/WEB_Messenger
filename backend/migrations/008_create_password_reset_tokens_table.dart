import 'package:postgres/postgres.dart';

/// Migration: Create PasswordResetToken table for password recovery tokens
Future<void> up(Connection connection) async {
  await connection.execute('''
    CREATE TABLE IF NOT EXISTS password_reset_token (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id UUID NOT NULL REFERENCES "user"(id) ON DELETE CASCADE,
      token_hash VARCHAR(255) NOT NULL UNIQUE,
      expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
      used_at TIMESTAMP WITH TIME ZONE,
      created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
      
      -- Constraints
      CONSTRAINT token_hash_not_empty CHECK (LENGTH(token_hash) > 0),
      CONSTRAINT expires_after_created CHECK (expires_at > created_at),
      CONSTRAINT used_at_after_created CHECK (used_at IS NULL OR used_at >= created_at)
    );
  ''');
  
  -- Create indexes for common queries
  await connection.execute('''
    CREATE UNIQUE INDEX idx_password_reset_token_hash ON password_reset_token(token_hash);
  ''');
  
  await connection.execute('''
    CREATE INDEX idx_password_reset_token_user_id_created ON password_reset_token(user_id, created_at DESC);
  ''');
  
  await connection.execute('''
    CREATE INDEX idx_password_reset_token_expires_at ON password_reset_token(expires_at);
  ''');
  
  await connection.execute('''
    CREATE INDEX idx_password_reset_token_used_at ON password_reset_token(used_at);
  ''');
  
  print('[✓] Table created: password_reset_token');
}

/// Rollback: Drop PasswordResetToken table
Future<void> down(Connection connection) async {
  await connection.execute('''
    DROP TABLE IF EXISTS password_reset_token CASCADE;
  ''');
  
  print('[✓] Table dropped: password_reset_token');
}

/// Migration metadata
class Migration008 {
  static const String name = '008_create_password_reset_tokens_table';
}
