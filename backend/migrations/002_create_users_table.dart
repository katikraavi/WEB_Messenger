import 'package:postgres/postgres.dart';

/// Migration: Create Users table with authentication and profile fields
Future<void> up(Connection connection) async {
  await connection.execute('''
    CREATE TABLE IF NOT EXISTS "user" (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      email VARCHAR(255) NOT NULL UNIQUE,
      username VARCHAR(50) NOT NULL UNIQUE,
      password_hash VARCHAR(255) NOT NULL,
      email_verified BOOLEAN NOT NULL DEFAULT false,
      profile_picture_url TEXT,
      about_me TEXT,
      created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
      
      -- Constraints
      CONSTRAINT email_format CHECK (email LIKE '%@%.%'),
      CONSTRAINT email_not_empty CHECK (LENGTH(email) > 0),
      CONSTRAINT username_not_empty CHECK (LENGTH(username) > 0)
    );
  ''');
  
  // Create indexes for common queries
  await connection.execute('''
    CREATE UNIQUE INDEX idx_user_email ON "user"(email);
  ''');
  
  await connection.execute('''
    CREATE UNIQUE INDEX idx_user_username ON "user"(username);
  ''');
  
  await connection.execute('''
    CREATE INDEX idx_user_created_at ON "user"(created_at DESC);
  ''');
  
  print('[✓] Table created: user');
}

/// Rollback: Drop Users table
Future<void> down(Connection connection) async {
  await connection.execute('''
    DROP TABLE IF EXISTS "user" CASCADE;
  ''');
  
  print('[✓] Table dropped: user');
}

/// Migration metadata
class Migration002 {
  static const String name = '002_create_users_table';
  static const int version = 2;
  static const DateTime createdAt = DateTime(2026, 3, 10);
}
