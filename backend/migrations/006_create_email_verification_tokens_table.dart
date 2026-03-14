import 'package:postgres/postgres.dart';

/// Migration: Create email_verification_tokens table
Future<void> up(Connection connection) async {
  await connection.execute('''
    CREATE TABLE IF NOT EXISTS email_verification_tokens (
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
    CREATE INDEX idx_email_verification_token ON email_verification_tokens(token);
  ''');
  
  // Index for expired token cleanup
  await connection.execute('''
    CREATE INDEX idx_email_verification_expires_at ON email_verification_tokens(expires_at);
  ''');
  
  print('[✓] Table created: email_verification_tokens');
}

/// Rollback: Drop email_verification_tokens table
Future<void> down(Connection connection) async {
  await connection.execute('''
    DROP TABLE IF EXISTS email_verification_tokens CASCADE;
  ''');
  
  print('[✓] Table dropped: email_verification_tokens');
}

class Migration006 {
  static const String name = '006_create_email_verification_tokens_table';
  static const int version = 6;
}
