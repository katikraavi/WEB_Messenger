#!/bin/bash
# Flutter run workaround for Android v1 embedding false positive
# This script rebuilds and installs the app on the Android emulator

set -e

cd "$(dirname "$0")"

DEVICE="${1:-emulator-5554}"
BUILD_MODE="${2:-debug}"

echo "� Getting dependencies..."
flutter pub get

echo "🔨 Building APK for $BUILD_MODE..."
./android/gradlew -p android app:assemble${BUILD_MODE^}

APK_PATH="./build/app/outputs/apk/$BUILD_MODE/app-$BUILD_MODE.apk"

if [ ! -f "$APK_PATH" ]; then
    echo "❌ APK not found at $APK_PATH"
    exit 1
fi

echo "📥 Installing APK on $DEVICE..."
adb install -r "$APK_PATH"

echo "🚀 Launching app..."
adb shell am start -n com.messenger.frontend/.MainActivity

echo "📊 Showing logs..."
flutter logs 2>/dev/null || adb logcat flutter:V *:S
