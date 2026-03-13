import 'package:postgres/postgres.dart';

/// Migration: Create Chats table with per-user archival support
Future<void> up(Connection connection) async {
  await connection.execute('''
    CREATE TABLE IF NOT EXISTS chat (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
      archived_by_users UUID[] NOT NULL DEFAULT '{}'::UUID[],
      
      CONSTRAINT archived_users_not_null CHECK (archived_by_users IS NOT NULL)
    );
  ''');
  
  // Create indexes for common queries
  await connection.execute('''
    CREATE INDEX idx_chat_created_at ON chat(created_at DESC);
  ''');
  
  print('[✓] Table created: chat');
}

/// Rollback: Drop Chats table
Future<void> down(Connection connection) async {
  await connection.execute('''
    DROP TABLE IF EXISTS chat CASCADE;
  ''');
  
  print('[✓] Table dropped: chat');
}

/// Migration metadata
class Migration003 {
  static const String name = '003_create_chats_table';
  static const int version = 3;
  static const DateTime createdAt = DateTime(2026, 3, 10);
}
