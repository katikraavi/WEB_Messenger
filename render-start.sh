#!/bin/bash
set -e

echo "[Render] Starting Web Messenger..."
echo "[Render] Environment: $SERVERPOD_ENV"
echo "[Render] Port: ${SERVERPOD_PORT:-8080}"

cd /app/backend

# Start backend with all env vars
echo "[Render] Starting Dart backend..."
dart run bin/server.dart &
BACKEND_PID=$!
echo "[Render] Backend PID: $BACKEND_PID"

# Wait for backend
sleep 3

# Start nginx
echo "[Render] Starting nginx..."
nginx -g "daemon off;"
