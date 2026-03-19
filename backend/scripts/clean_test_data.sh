#!/bin/bash

# Clean test data from database
# Automatically detects Docker or local database connection

# Check if Docker backend container is running
if docker ps 2>/dev/null | grep -q "messenger-postgres"; then
    echo "[INFO] Docker database detected, using Docker cleanup..."
    exec bash "$(dirname "$0")/clean_docker_test_data.sh" "$@"
fi

# Otherwise use local database connection
set -e

DB_HOST="${DATABASE_HOST:-localhost}"
DB_PORT="${DATABASE_PORT:-5432}"
DB_NAME="${DATABASE_NAME:-messenger_db}"
DB_USER="${DATABASE_USER:-messenger_user}"
DB_PASSWORD="${DATABASE_PASSWORD:-messenger_password}"

echo "[INFO] Connecting to database: $DB_NAME on $DB_HOST:$DB_PORT"

# Export password to avoid prompt
export PGPASSWORD="$DB_PASSWORD"

# Delete ALL test users (seeded + manual test accounts)
psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" << 'EOF'
\echo '[INFO] Cleaning test data...'

DELETE FROM "users" 
WHERE email IN ('alice@example.com', 'bob@example.com', 'charlie@example.com', 'diane@test.org')
OR username IN ('alice', 'bob', 'charlie', 'diane')
OR email LIKE 'testuser%@%'
OR username LIKE 'testuser%'
OR email LIKE 'test%@%'
OR username LIKE 'test%';

\echo '[✓] All test accounts removed'

-- Show remaining users count
SELECT COUNT(*) as remaining_users FROM "users";

EOF

echo "[✓] Test data cleanup complete"

