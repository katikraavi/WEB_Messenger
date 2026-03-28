#!/bin/bash

echo "🔄 Restarting web server on port 5000..."
echo ""

# Kill any existing Python server on port 5000
pkill -f "python3 -m http.server 5000" 2>/dev/null || true

# Build web
echo "🏗️  Building web app..."
cd ~/web-messenger/frontend
flutter build web --release \
	--dart-define=BACKEND_URL=http://localhost:8081 \
	--dart-define=APP_ENV=development \
	--dart-define=ENABLE_TEST_USERS=true \
	--dart-define=BUILD_SHA=local \
	--dart-define=BUILD_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ) > /dev/null 2>&1

# Start server
cd build/web
echo "🌐 Starting web server on port 5000..."
python3 -m http.server 5000 > /dev/null 2>&1 &

echo ""
echo "✅ Web server restarted!"
echo "📍 http://localhost:5000"
echo ""
