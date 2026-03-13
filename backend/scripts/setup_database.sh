#!/bin/bash

# Database Migration Setup Script
# Creates all table schemas via psql
# Usage: ./setup_database.sh [host] [port] [username] [password] [database]

set -e

# Default PostgreSQL connection parameters
PGHOST="${1:-localhost}"
PGPORT="${2:-5432}"
PGUSER="${3:-messenger_user}"
PGPASSWORD="${4:-messenger_password}"
PGDATABASE="${5:-messenger_db}"

echo "╔════════════════════════════════════════════════════════════╗"
echo "║ Messenger Database Migration Setup                        ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "[INFO] Connecting to PostgreSQL:"
echo "       Host: $PGHOST"
echo "       Port: $PGPORT"
echo "       User: $PGUSER"
echo "       Database: $PGDATABASE"
echo ""

export PGPASSWORD

# Verify connection
if ! psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" -c "SELECT 1" > /dev/null 2>&1; then
  echo "❌ Failed to connect to PostgreSQL"
  echo ""
  echo "Troubleshooting:"
  echo "  1. Ensure PostgreSQL is running"
  echo "  2. Check connection parameters"
  echo "  3. If using Docker: verify docker-compose is running"
  echo ""
  echo "For Docker: docker exec messenger-postgres psql -U messenger_user -c '\\l'"
  exit 1
fi

echo "[✓] Database connection successful"
echo ""

# Function to run a migration
run_migration() {
  local version=$1
  local description=$2
  local sql=$3
  
  echo "[INFO] Migration $version: $description"
  
  # Execute SQL via psql
  psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" << EOMIG
BEGIN TRANSACTION;

CREATE TABLE IF NOT EXISTS schema_migrations (
  version BIGINT PRIMARY KEY,
  description VARCHAR(255) NOT NULL,
  executed_at TIMESTAMP DEFAULT NOW()
);

DO \$\$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM schema_migrations WHERE version = $version) THEN
    $sql
    INSERT INTO schema_migrations (version, description) VALUES ($version, '$description');
    RAISE NOTICE 'Migration % applied', $version;
  ELSE
    RAISE NOTICE 'Migration % already applied', $version;
  END IF;
END
\$\$;

COMMIT;
EOMIG

  if [ $? -eq 0 ]; then
    echo "  ✓ Migration $version completed"
  else
    echo "  ✗ Migration $version failed"
    exit 1
  fi
  echo ""
}

# ============================================================
# Migration 001: Create ENUM types
# ============================================================
run_migration 1 "Create message_status and invite_status enums" "
CREATE TYPE message_status AS ENUM ('sent', 'delivered', 'read');
CREATE TYPE invite_status AS ENUM ('pending', 'accepted', 'declined');
"

# ============================================================
# Migration 002: Create users table
# ============================================================
run_migration 2 "Create users table" "
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT UNIQUE NOT NULL,
  username TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  email_verified BOOLEAN DEFAULT FALSE,
  profile_picture_url TEXT,
  about_me TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_username ON users(username);
"

# ============================================================
# Migration 003: Create chats table
# ============================================================
run_migration 3 "Create chats table" "
CREATE TABLE chats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at TIMESTAMP DEFAULT NOW(),
  archived_by_users UUID[] DEFAULT ARRAY[]::UUID[]
);
CREATE INDEX idx_chats_created_at ON chats(created_at);
"

# ============================================================
# Migration 004: Create chat_members table
# ============================================================
run_migration 4 "Create chat_members table" "
CREATE TABLE chat_members (
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  chat_id UUID NOT NULL REFERENCES chats(id) ON DELETE CASCADE,
  joined_at TIMESTAMP DEFAULT NOW(),
  left_at TIMESTAMP,
  PRIMARY KEY (user_id, chat_id)
);
CREATE INDEX idx_chat_members_user ON chat_members(user_id);
CREATE INDEX idx_chat_members_chat ON chat_members(chat_id);
"

# ============================================================
# Migration 005: Create messages table
# ============================================================
run_migration 5 "Create messages table" "
CREATE TABLE messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  chat_id UUID NOT NULL REFERENCES chats(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  encrypted_content TEXT NOT NULL,
  media_url TEXT,
  media_type TEXT,
  status message_status DEFAULT 'sent',
  created_at TIMESTAMP DEFAULT NOW(),
  edited_at TIMESTAMP,
  CHECK (media_url IS NULL OR media_type IS NOT NULL)
);
CREATE INDEX idx_messages_chat ON messages(chat_id);
CREATE INDEX idx_messages_sender ON messages(sender_id);
CREATE INDEX idx_messages_created_at ON messages(created_at);
"

# ============================================================
# Migration 006: Create invites table
# ============================================================
run_migration 6 "Create invites table" "
CREATE TABLE invites (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  receiver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status invite_status DEFAULT 'pending',
  created_at TIMESTAMP DEFAULT NOW(),
  responded_at TIMESTAMP,
  UNIQUE (sender_id, receiver_id, status)
);
CREATE INDEX idx_invites_sender ON invites(sender_id);
CREATE INDEX idx_invites_receiver ON invites(receiver_id);
CREATE INDEX idx_invites_status ON invites(status);
"

echo "╔════════════════════════════════════════════════════════════╗"
echo "║ ✅ All Migrations Completed Successfully!                 ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Database schema ready with:"
echo "  • 5 tables (users, chats, chat_members, messages, invites)"
echo "  • 2 ENUM types (message_status, invite_status)"
echo "  • Proper indexes and constraints"
echo ""
echo "Next steps:"
echo "  1. Verify tables: psql -h $PGHOST -U $PGUSER -d $PGDATABASE -c '\\dt'"
echo "  2. Run tests: cd ~/mobile-messenger/backend && dart test"
echo "  3. Start backend: dart run lib/server.dart"
echo ""

exit 0
