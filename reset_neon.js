#!/usr/bin/env node

const { Client } = require('pg');

const dbUrl = process.env.DATABASE_URL;
if (!dbUrl) {
  console.error('❌ DATABASE_URL environment variable not set');
  process.exit(1);
}

const client = new Client({
  connectionString: dbUrl,
  connectionTimeoutMillis: 10000,
  statement_timeout: 30000,
});

const cleanupSQL = `
-- Drop all data (keep schema)
TRUNCATE TABLE chat_notification_preferences CASCADE;
TRUNCATE TABLE device_sessions CASCADE;
TRUNCATE TABLE media_storage CASCADE;
TRUNCATE TABLE message_delivery_status CASCADE;
TRUNCATE TABLE message_edits CASCADE;
TRUNCATE TABLE messages CASCADE;
TRUNCATE TABLE group_invites CASCADE;
TRUNCATE TABLE group_members CASCADE;
TRUNCATE TABLE group_chats CASCADE;
TRUNCATE TABLE invites CASCADE;
TRUNCATE TABLE chats CASCADE;
TRUNCATE TABLE password_reset_attempt CASCADE;
TRUNCATE TABLE password_reset_token CASCADE;
TRUNCATE TABLE polls CASCADE;
TRUNCATE TABLE poll_options CASCADE;
TRUNCATE TABLE poll_votes CASCADE;
TRUNCATE TABLE profile_image CASCADE;
TRUNCATE TABLE push_device_tokens CASCADE;
TRUNCATE TABLE verification_token CASCADE;
TRUNCATE TABLE users CASCADE;

-- NOTE: We do NOT truncate schema_migrations because the backend relies on
-- migration history to know the database schema is properly initialized.
-- Clearing it breaks backend startup.

-- Create welcome screen users with verified emails
INSERT INTO users (id, email, username, password_hash, profile_picture_url, verified_at, created_at, email_verified, is_default_profile_picture) VALUES
  ('11111111-1111-1111-1111-111111111111', 'alice@example.com', 'alice', '$2b$12$KVZX6D18bAlHAQXmM7PbFOOPrEvEKGJO3/rY5WP1WnMaX6v3NcZ3O', NULL, NOW(), NOW(), true, true),
  ('22222222-2222-2222-2222-222222222222', 'bob@example.com', 'bob', '$2b$12$KVZX6D18bAlHAQXmM7PbFOOPrEvEKGJO3/rY5WP1WnMaX6v3NcZ3O', NULL, NOW(), NOW(), true, true),
  ('33333333-3333-3333-3333-333333333333', 'charlie@example.com', 'charlie', '$2b$12$KVZX6D18bAlHAQXmM7PbFOOPrEvEKGJO3/rY5WP1WnMaX6v3NcZ3O', NULL, NOW(), NOW(), true, true),
  ('44444444-4444-4444-4444-444444444444', 'diane@test.org', 'diane', '$2b$12$KVZX6D18bAlHAQXmM7PbFOOPrEvEKGJO3/rY5WP1WnMaX6v3NcZ3O', NULL, NOW(), NOW(), true, true),
  ('55555555-5555-5555-5555-555555555555', 'testuser1@example.com', 'testuser1', '$2b$12$KVZX6D18bAlHAQXmM7PbFOOPrEvEKGJO3/rY5WP1WnMaX6v3NcZ3O', NULL, NOW(), NOW(), true, true),
  ('66666666-6666-6666-6666-666666666666', 'testuser2@example.com', 'testuser2', '$2b$12$KVZX6D18bAlHAQXmM7PbFOOPrEvEKGJO3/rY5WP1WnMaX6v3NcZ3O', NULL, NOW(), NOW(), true, true);
`;

async function resetDatabase() {
  try {
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('🗑️  RESETTING NEON DATABASE');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('');
    
    console.log('Connecting to database...');
    await client.connect();
    console.log('✅ Connected to Neon');
    console.log('');
    
    console.log('Executing cleanup and user creation...');
    await client.query(cleanupSQL);
    console.log('✅ Database cleanup complete');
    console.log('');
    
    // Verify the cleanup
    const result = await client.query('SELECT COUNT(*) as user_count FROM users');
    console.log(`✅ User count: ${result.rows[0].user_count}`);
    console.log('');
    
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('✅ DATABASE RESET COMPLETE');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('');
    console.log('Welcome Screen Users Created (All Password: "password"):');
    console.log('  1. Alice - alice@example.com');
    console.log('  2. Bob - bob@example.com');
    console.log('  3. Charlie - charlie@example.com');
    console.log('  4. Diane - diane@test.org');
    console.log('  5. TestUser1 - testuser1@example.com');
    console.log('  6. TestUser2 - testuser2@example.com');
    console.log('');
    console.log('Database Status:');
    console.log('  ✅ Zero messages');
    console.log('  ✅ Zero chats/connections');
    console.log('  ✅ Zero invites');
    console.log('  ✅ All users email-verified (ready to use)');
    console.log('');
    console.log('Testers can now:');
    console.log('  1. Login with any welcome user');
    console.log('  2. Send invites to other users (no 409 conflicts!)');
    console.log('  3. Create and test chats from scratch');
    console.log('  4. Test message editing (encryption fix deployed)');
    console.log('');
    console.log('🚀 Ready for fresh testing!');
    console.log('');
    
  } catch (err) {
    console.error('❌ Error during database reset:', err.message);
    process.exit(1);
  } finally {
    await client.end();
  }
}

resetDatabase();
