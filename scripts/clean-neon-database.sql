-- ============================================================================
-- NEON Database Cleanup Script - Keep Test Users Only
-- ============================================================================
-- WARNING: This script PERMANENTLY DELETES production data
-- Execute only after backing up your database!
-- ============================================================================

-- Step 1: Identify test users (for verification)
DO $$
DECLARE
  test_user_count INT;
BEGIN
  SELECT COUNT(*) INTO test_user_count 
  FROM users 
  WHERE username ILIKE '%test%' OR email ILIKE '%test%' OR email = 'katikraavi@gmail.com';
  
  RAISE NOTICE 'Found % test/admin users to keep', test_user_count;
END $$;

-- Step 2: Delete invites from/to non-test users
DELETE FROM invites 
WHERE sender_id NOT IN (
  SELECT id FROM users 
  WHERE username ILIKE '%test%' OR email ILIKE '%test%' OR email = 'katikraavi@gmail.com'
)
OR receiver_id NOT IN (
  SELECT id FROM users 
  WHERE username ILIKE '%test%' OR email ILIKE '%test%' OR email = 'katikraavi@gmail.com'
);

-- Step 3: Delete messages from non-test users
DELETE FROM messages 
WHERE sender_id NOT IN (
  SELECT id FROM users 
  WHERE username ILIKE '%test%' OR email ILIKE '%test%' OR email = 'katikraavi@gmail.com'
);

-- Step 4: Delete chats involving non-test users
DELETE FROM chats 
WHERE participant_1_id NOT IN (
  SELECT id FROM users 
  WHERE username ILIKE '%test%' OR email ILIKE '%test%' OR email = 'katikraavi@gmail.com'
)
OR participant_2_id NOT IN (
  SELECT id FROM users 
  WHERE username ILIKE '%test%' OR email ILIKE '%test%' OR email = 'katikraavi@gmail.com'
);

-- Step 5: Delete non-test users (cascade will handle related data)
DELETE FROM users 
WHERE username NOT ILIKE '%test%' 
  AND email NOT ILIKE '%test%' 
  AND email != 'katikraavi@gmail.com';

-- Step 6: Verify cleanup
DO $$
DECLARE
  user_count INT;
  chat_count INT;
  message_count INT;
  invite_count INT;
BEGIN
  SELECT COUNT(*) INTO user_count FROM users;
  SELECT COUNT(*) INTO chat_count FROM chats;
  SELECT COUNT(*) INTO message_count FROM messages;
  SELECT COUNT(*) INTO invite_count FROM invites;
  
  RAISE NOTICE '=== CLEANUP SUMMARY ===';
  RAISE NOTICE 'Users remaining: %', user_count;
  RAISE NOTICE 'Chats remaining: %', chat_count;
  RAISE NOTICE 'Messages remaining: %', message_count;
  RAISE NOTICE 'Invites remaining: %', invite_count;
END $$;

-- List remaining users
SELECT id, username, email, created_at FROM users ORDER BY created_at DESC;
