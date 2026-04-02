#!/bin/bash

# Build & Start Backend Only
# This script starts the backend services without the frontend.
# Useful for development when you only want the backend/database running.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==============================================================="
echo "  Starting Backend Only"
echo "==============================================================="

echo ""
echo "Starting services: PostgreSQL and Backend..."
docker compose up

# Note: Keeps running in foreground; Ctrl+C to stop
