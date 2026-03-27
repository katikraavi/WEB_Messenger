#!/bin/bash

set -e

echo "🚀 Starting Web Messenger..."
echo ""

# Start backend in background
echo "📦 Starting backend (Docker)..."
docker compose up -d > /dev/null 2>&1
echo "✅ Backend running on http://localhost:8081"

# Build and serve web
echo "🏗️  Building web app..."
cd frontend
flutter build web --release > /dev/null 2>&1
cd build/web

echo "🌐 Starting web server..."
python3 -m http.server 5000 > /dev/null 2>&1 &

echo ""
echo "════════════════════════════════════════"
echo "✅ All systems ready!"
echo "════════════════════════════════════════"
echo ""
echo "📍 Open in Windows Chrome:"
echo "   http://localhost:5000"
echo ""
echo "🔧 Services:"
echo "   Frontend:  http://localhost:5000"
echo "   Backend:   http://localhost:8081"
echo "   Mailhog:   http://localhost:1025"
echo ""
