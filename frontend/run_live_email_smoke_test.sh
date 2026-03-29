#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")"

backend_url="${BACKEND_URL:-https://web-messenger-backend.onrender.com}"
health_url="${BACKEND_HEALTH_URL:-$backend_url/health}"

echo "Checking backend health at $health_url"
if ! curl --fail --silent --show-error "$health_url" >/dev/null; then
  echo "Backend is not reachable."
  echo "Start it first from the repository root, for example:"
  echo "  docker compose up -d --build serverpod"
  exit 1
fi

echo "Running live email UI smoke test"
RUN_LIVE_EMAIL_UI_TESTS=true flutter test integration_test/live_email_ui_flow_test.dart "$@"