#!/bin/bash
# Run Flutter web app from WSL2, opening in Windows Chrome.
#
# Flutter's -d chrome debug-port handshake doesn't work from WSL2 because
# Chrome (a Windows process) can't connect back to the WSL2 debug socket.
# Instead we use -d web-server (just serves files) and open Chrome ourselves
# via cmd.exe, which the Windows host handles natively.

set -e

cd "$(dirname "$0")"

PORT=5000
URL="http://localhost:$PORT"

echo "Starting Flutter web dev server on $URL ..."
echo "(hot-reload is active — press 'r' to reload, 'R' to restart)"
echo ""

# Open Chrome via Windows cmd.exe ~10 s after starting, giving Flutter time
# to compile. Runs in background so the main shell stays interactive.
(sleep 10 && cmd.exe /c start "" "$URL" 2>/dev/null) &

# Start Flutter web server in the foreground — keeps hot-reload/interactive terminal
flutter run -d web-server \
  --web-hostname 0.0.0.0 \
  --web-port "$PORT"
