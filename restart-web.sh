#!/bin/bash

echo "🔄 Restarting web server on port 5000..."
echo ""

# Kill any existing Python server on port 5000
pkill -f "python3 -m http.server 5000" 2>/dev/null || true

# Build web
echo "🏗️  Building web app..."
cd ~/web-messenger/frontend
flutter build web --release > /dev/null 2>&1

# Start server
cd build/web
echo "🌐 Starting web server on port 5000..."
python3 -m http.server 5000 > /dev/null 2>&1 &

echo ""
echo "✅ Web server restarted!"
echo "📍 http://localhost:5000"
echo ""
