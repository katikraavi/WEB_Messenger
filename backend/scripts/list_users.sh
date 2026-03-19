#!/bin/bash

# Check what emails and usernames are already registered
# Useful for debugging registration issues

set -e

DB_HOST="${DATABASE_HOST:-localhost}"
DB_PORT="${DATABASE_PORT:-5432}"
DB_NAME="${DATABASE_NAME:-messenger_db}"
DB_USER="${DATABASE_USER:-messenger_user}"
DB_PASSWORD="${DATABASE_PASSWORD:-messenger_password}"

export PGPASSWORD="$DB_PASSWORD"

echo "[INFO] Registered accounts in database:"
echo ""

psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -c "SELECT id, username, email, created_at FROM \"users\" ORDER BY created_at DESC;"

echo ""
echo "[INFO] Total users: $(psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM \"users\";")"
