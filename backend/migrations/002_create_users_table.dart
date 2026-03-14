import 'package:postgres/postgres.dart';

/// Migration: Create Users table with authentication and profile fields
Future<void> up(Connection connection) async {
  await connection.execute('''
    CREATE TABLE IF NOT EXISTS "users" (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      email VARCHAR(255) NOT NULL UNIQUE,
      username VARCHAR(50) NOT NULL UNIQUE,
      password_hash VARCHAR(255) NOT NULL,
      email_verified BOOLEAN NOT NULL DEFAULT false,
      profile_picture_url TEXT,
      about_me TEXT,
      is_private_profile BOOLEAN NOT NULL DEFAULT false,
      profile_updated_at TIMESTAMP WITH TIME ZONE,
      created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
      last_password_changed TIMESTAMP WITH TIME ZONE,
      last_login_at TIMESTAMP WITH TIME ZONE,
      verified_at TIMESTAMP WITH TIME ZONE,
      
      -- Constraints
      CONSTRAINT email_format CHECK (email LIKE '%@%.%'),
      CONSTRAINT email_not_empty CHECK (LENGTH(email) > 0),
      CONSTRAINT username_not_empty CHECK (LENGTH(username) > 0)
    );
  ''');
  
  // Create indexes for common queries
  await connection.execute('''
    CREATE UNIQUE INDEX idx_users_email ON "users"(email);
  ''');
  
  await connection.execute('''
    CREATE UNIQUE INDEX idx_users_username ON "users"(username);
  ''');
  
  await connection.execute('''
    CREATE INDEX idx_users_created_at ON "users"(created_at DESC);
  ''');
  
  print('[✓] Table created: users');
}

/// Rollback: Drop Users table
Future<void> down(Connection connection) async {
  await connection.execute('''
    DROP TABLE IF EXISTS "users" CASCADE;
  ''');
  
  print('[✓] Table dropped: users');
}

/// Migration metadata
class Migration002 {
  static const String name = '002_create_users_table';
  static const int version = 2;
  static const DateTime createdAt = DateTime(2026, 3, 10);
}
