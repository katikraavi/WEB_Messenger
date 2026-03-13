import 'package:postgres/postgres.dart';

/// Migration: Create VerificationToken table for email verification tokens
Future<void> up(Connection connection) async {
  await connection.execute('''
    CREATE TABLE IF NOT EXISTS verification_token (
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
    CREATE UNIQUE INDEX idx_verification_token_hash ON verification_token(token_hash);
  ''');
  
  await connection.execute('''
    CREATE INDEX idx_verification_token_user_id_created ON verification_token(user_id, created_at DESC);
  ''');
  
  await connection.execute('''
    CREATE INDEX idx_verification_token_expires_at ON verification_token(expires_at);
  ''');
  
  await connection.execute('''
    CREATE INDEX idx_verification_token_used_at ON verification_token(used_at);
  ''');
  
  print('[✓] Table created: verification_token');
}

/// Rollback: Drop VerificationToken table
Future<void> down(Connection connection) async {
  await connection.execute('''
    DROP TABLE IF EXISTS verification_token CASCADE;
  ''');
  
  print('[✓] Table dropped: verification_token');
}

/// Migration metadata
class Migration007 {
  static const String name = '007_create_verification_tokens_table';
}
