#!/bin/bash

set -e

echo "Starting Web Messenger..."
echo ""

# Start backend in background
echo "Starting backend (Docker)..."
docker compose up -d > /dev/null 2>&1
echo "Backend running on http://localhost:8081"

# Build and serve web
echo "Building web app..."
cd frontend
flutter build web --release \
--dart-define=BACKEND_URL=http://localhost:8081 \
--dart-define=APP_ENV=development \
--dart-define=ENABLE_TEST_USERS=true \
--dart-define=BUILD_SHA=local \
--dart-define=BUILD_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ) > /dev/null 2>&1
cd build/web

echo "Starting web server..."
python3 -m http.server 5000 > /dev/null 2>&1 &

echo ""
echo "========================================"
echo "All systems ready"
echo "========================================"
echo ""
echo "Open in browser:"
echo "  http://localhost:5000"
echo ""
echo "Services:"
echo "  Frontend:  http://localhost:5000"
echo "  Backend:   http://localhost:8081"
echo ""
