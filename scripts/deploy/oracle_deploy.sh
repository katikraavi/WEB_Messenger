#!/usr/bin/env bash
set -euo pipefail

if [[ ! -f .env.oracle ]]; then
  echo "Missing .env.oracle in repository root."
  echo "Create it from template: cp oracle.env.example .env.oracle"
  exit 1
fi

echo "Building and starting web-messenger on Oracle VM..."
docker compose --env-file .env.oracle -f docker-compose.oracle.yml up -d --build

echo "Deployment started. Current status:"
docker compose --env-file .env.oracle -f docker-compose.oracle.yml ps

echo "Health check (may need ~30s on first start):"
set +e
curl -fsS http://localhost/health && echo
set -e

echo "Done."
