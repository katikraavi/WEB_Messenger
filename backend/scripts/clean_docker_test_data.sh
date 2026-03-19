#!/bin/bash

# Clean test data from Docker database
# Removes all testuser accounts but keeps seeded test data (alice, bob, charlie, diane)

CONTAINER_NAME="${1:-messenger-postgres}"

if ! docker ps | grep -q "$CONTAINER_NAME"; then
    echo "[ERROR] Container '$CONTAINER_NAME' not found or not running"
    exit 1
fi

echo "[INFO] Cleaning test accounts from database in Docker container: $CONTAINER_NAME"

docker exec -t "$CONTAINER_NAME" psql -U messenger_user -d messenger_db << 'EOF'
\echo '[INFO] Removing testuser accounts...'

DELETE FROM "users" 
WHERE email LIKE 'testuser%' 
OR username LIKE 'testuser%'
OR email LIKE 'test%@%' 
OR username LIKE 'test%';

\echo '[✓] Test accounts removed'

\echo ''
\echo '[INFO] Remaining users in database:'
SELECT username, email FROM "users" ORDER BY created_at;

EOF

echo "[✓] Cleanup complete"
