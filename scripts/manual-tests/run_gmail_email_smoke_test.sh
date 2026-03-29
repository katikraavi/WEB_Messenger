#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")"

health_url="${BACKEND_HEALTH_URL:-https://web-messenger-backend.onrender.com/health}"

echo "Starting backend with Docker Compose"
docker compose up -d --build serverpod

echo "Waiting for backend health at $health_url"
for _ in $(seq 1 30); do
  if curl --fail --silent --show-error "$health_url" >/dev/null; then
    break
  fi
  sleep 2
done

if ! curl --fail --silent --show-error "$health_url" >/dev/null; then
  echo "Backend did not become healthy in time."
  exit 1
fi

cd ../../frontend
./run_live_email_smoke_test.sh "$@"