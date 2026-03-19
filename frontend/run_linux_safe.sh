#!/bin/bash
# Run Flutter Linux app with software rendering fallbacks.
# Helps avoid EGL/MESA driver warnings on some Linux setups.

set -e

cd "$(dirname "$0")"

export LIBGL_ALWAYS_SOFTWARE=1
export GSK_RENDERER=cairo
export GDK_BACKEND=x11

echo "Running Flutter with software rendering compatibility mode..."
flutter run -d linux
