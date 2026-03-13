import 'package:postgres/postgres.dart';

/// Migration: Create Messages table with encryption support and status tracking
Future<void> up(Connection connection) async {
  await connection.execute('''
    CREATE TABLE IF NOT EXISTS message (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      chat_id UUID NOT NULL,
      sender_id UUID NOT NULL,
      encrypted_content TEXT NOT NULL,
      media_url TEXT,
      media_type VARCHAR(20),
      status message_status NOT NULL DEFAULT 'sent',
      created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
      edited_at TIMESTAMP WITH TIME ZONE,
      
      CONSTRAINT fk_message_chat FOREIGN KEY (chat_id) 
        REFERENCES chat(id) ON DELETE CASCADE,
      CONSTRAINT fk_message_sender FOREIGN KEY (sender_id) 
        REFERENCES "user"(id) ON DELETE RESTRICT,
      
      CONSTRAINT valid_status CHECK (status IN ('sent', 'delivered', 'read')),
      CONSTRAINT edited_after_created CHECK (edited_at IS NULL OR edited_at >= created_at)
    );
  ''');
  
  await connection.execute('''
    CREATE INDEX idx_message_chat_created ON message(chat_id, created_at DESC);
  ''');
  
  await connection.execute('''
    CREATE INDEX idx_message_sender_id ON message(sender_id);
  ''');
  
  await connection.execute('''
    CREATE INDEX idx_message_status ON message(status);
  ''');
  
  await connection.execute('''
    CREATE INDEX idx_message_created_at ON message(created_at DESC);
  ''');
  
  print('[✓] Table created: message');
}

/// Rollback: Drop Messages table
Future<void> down(Connection connection) async {
  await connection.execute('''
    DROP TABLE IF EXISTS message CASCADE;
  ''');
  
  print('[✓] Table dropped: message');
}

/// Migration metadata
class Migration005 {
  static const String name = '005_create_messages_table';
  static const int version = 5;
  static const DateTime createdAt = DateTime(2026, 3, 10);
}
