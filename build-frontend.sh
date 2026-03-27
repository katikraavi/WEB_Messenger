#!/bin/bash

# Build Flutter Web Frontend
# This script builds the Flutter web app locally before Docker.
# It allows the backend to start independently without waiting for frontend build.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRONTEND_DIR="$SCRIPT_DIR/frontend"

echo "════════════════════════════════════════════════════════════════"
echo "  Building Flutter Web Frontend"
echo "════════════════════════════════════════════════════════════════"

cd "$FRONTEND_DIR"

# Check if flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter is not installed. Please install Flutter first."
    echo "   Visit: https://flutter.dev/docs/get-started/install"
    exit 1
fi

echo ""
echo "📦 Getting dependencies..."
flutter pub get

echo ""
echo "🔨 Building web release..."
flutter build web --release

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✅ Frontend build completed successfully!"
echo "   Build output: $FRONTEND_DIR/build/web"
echo ""
echo "Next steps:"
echo "  • Run: docker compose up"
echo "  • Frontend will be served at: http://localhost:5000"
echo "====════════════════════════════════════════════════════════════="
