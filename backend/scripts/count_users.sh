#!/bin/bash
export PGPASSWORD=messenger_password
psql -h localhost -U messenger_user -d messenger_db -c "SELECT COUNT(*) FROM \"users\";" 2>&1 | grep -v "^$"
