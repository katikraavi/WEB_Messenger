import 'package:postgres/postgres.dart';

/// Migration: Create ChatMembers junction table for membership tracking
Future<void> up(Connection connection) async {
  await connection.execute('''
    CREATE TABLE IF NOT EXISTS chat_member (
      user_id UUID NOT NULL,
      chat_id UUID NOT NULL,
      joined_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
      left_at TIMESTAMP WITH TIME ZONE,
      
      PRIMARY KEY (user_id, chat_id),
      
      CONSTRAINT fk_chat_member_user FOREIGN KEY (user_id) 
        REFERENCES "user"(id) ON DELETE CASCADE,
      CONSTRAINT fk_chat_member_chat FOREIGN KEY (chat_id) 
        REFERENCES chat(id) ON DELETE CASCADE,
      
      CONSTRAINT left_after_joined CHECK (left_at IS NULL OR left_at > joined_at)
    );
  ''');
  
  await connection.execute('''
    CREATE INDEX idx_chat_member_user_id ON chat_member(user_id);
  ''');
  
  await connection.execute('''
    CREATE INDEX idx_chat_member_chat_id ON chat_member(chat_id);
  ''');
  
  await connection.execute('''
    CREATE INDEX idx_chat_member_joined_at ON chat_member(chat_id, joined_at DESC);
  ''');
  
  print('[✓] Table created: chat_member');
}

/// Rollback: Drop ChatMembers table
Future<void> down(Connection connection) async {
  await connection.execute('''
    DROP TABLE IF EXISTS chat_member CASCADE;
  ''');
  
  print('[✓] Table dropped: chat_member');
}

/// Migration metadata
class Migration004 {
  static const String name = '004_create_chat_members_table';
  static const int version = 4;
  static const DateTime createdAt = DateTime(2026, 3, 10);
}
