#!/bin/bash

# Build & Start Backend Only
# This script starts the backend services without the frontend.
# Useful for development when you only want the backend/database/etc running.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "════════════════════════════════════════════════════════════════"
echo "  Starting Backend Only (Backend-First Development)"
echo "════════════════════════════════════════════════════════════════"

echo ""
echo "🚀 Starting services: PostgreSQL, Backend, Mailhog..."
docker compose up

# Note: Keeps running in foreground; Ctrl+C to stop
