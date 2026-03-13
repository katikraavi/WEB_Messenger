import 'package:postgres/postgres.dart';

/// Migration: Create Invites table for friend/connection requests
Future<void> up(Connection connection) async {
  await connection.execute('''
    CREATE TABLE IF NOT EXISTS invite (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      sender_id UUID NOT NULL,
      receiver_id UUID NOT NULL,
      status invite_status NOT NULL DEFAULT 'pending',
      created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
      responded_at TIMESTAMP WITH TIME ZONE,
      
      CONSTRAINT fk_invite_sender FOREIGN KEY (sender_id) 
        REFERENCES "user"(id) ON DELETE CASCADE,
      CONSTRAINT fk_invite_receiver FOREIGN KEY (receiver_id) 
        REFERENCES "user"(id) ON DELETE CASCADE,
      
      CONSTRAINT sender_not_receiver CHECK (sender_id != receiver_id),
      CONSTRAINT responded_after_created CHECK (responded_at IS NULL OR responded_at >= created_at),
      CONSTRAINT valid_invite_status CHECK (status IN ('pending', 'accepted', 'declined'))
    );
  ''');
  
  await connection.execute('''
    CREATE INDEX idx_invite_receiver_status ON invite(receiver_id, status);
  ''');
  
  await connection.execute('''
    CREATE INDEX idx_invite_sender_created ON invite(sender_id, created_at DESC);
  ''');
  
  await connection.execute('''
    CREATE UNIQUE INDEX idx_invite_pending_unique 
      ON invite(sender_id, receiver_id) 
      WHERE status = 'pending';
  ''');
  
  print('[✓] Table created: invite');
}

/// Rollback: Drop Invites table
Future<void> down(Connection connection) async {
  await connection.execute('''
    DROP TABLE IF EXISTS invite CASCADE;
  ''');
  
  print('[✓] Table dropped: invite');
}

/// Migration metadata
class Migration006 {
  static const String name = '006_create_invites_table';
  static const int version = 6;
  static const DateTime createdAt = DateTime(2026, 3, 10);
}
