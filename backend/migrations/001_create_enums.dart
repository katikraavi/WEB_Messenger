/// Migration 001: Create ENUM Types
/// 
/// Creates the message_status and invite_status ENUM types required by Message and Invite tables.
/// 
/// Enums:
/// - message_status: 'sent', 'delivered', 'read'
/// - invite_status: 'pending', 'accepted', 'declined'

const migrationName = '001_create_enums';

const migrationSql = '''
-- Create message_status ENUM type for Message table
DO \$\$ BEGIN
  IF NOT EXISTS (SELECT FROM pg_type WHERE typname = 'message_status') THEN
    CREATE TYPE message_status AS ENUM ('sent', 'delivered', 'read');
  END IF;
END \$\$;

-- Create invite_status ENUM type for Invite table
DO \$\$ BEGIN
  IF NOT EXISTS (SELECT FROM pg_type WHERE typname = 'invite_status') THEN
    CREATE TYPE invite_status AS ENUM ('pending', 'accepted', 'declined');
  END IF;
END \$\$;

-- Verify types created
SELECT typname FROM pg_type WHERE typname IN ('message_status', 'invite_status');
''';

const rollbackSql = '''
-- Drop ENUM types if they exist
DROP TYPE IF EXISTS message_status CASCADE;
DROP TYPE IF EXISTS invite_status CASCADE;
''';
