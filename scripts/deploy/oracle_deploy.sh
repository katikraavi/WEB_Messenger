#!/usr/bin/env bash
set -euo pipefail

if [[ ! -f .env.oracle ]]; then
  echo "Missing .env.oracle in repository root."
  echo "Create it from template: cp oracle.env.example .env.oracle"
  exit 1
fi

echo "Building and starting web-messenger on Oracle VM..."

DOMAIN_VALUE="$(grep -E '^DOMAIN=' .env.oracle | head -n1 | cut -d'=' -f2- | tr -d '[:space:]')"

if [[ -n "${DOMAIN_VALUE}" && "${DOMAIN_VALUE}" != "YOUR_DOMAIN" ]]; then
  echo "DOMAIN is set to ${DOMAIN_VALUE} -> enabling HTTPS with Caddy"
  docker compose --env-file .env.oracle \
    -f docker-compose.oracle.yml \
    -f docker-compose.oracle.https.yml \
    up -d --build
else
  echo "DOMAIN not set -> deploying HTTP-only stack"
  docker compose --env-file .env.oracle -f docker-compose.oracle.yml up -d --build
fi

echo "Deployment started. Current status:"
if [[ -n "${DOMAIN_VALUE}" && "${DOMAIN_VALUE}" != "YOUR_DOMAIN" ]]; then
  docker compose --env-file .env.oracle \
    -f docker-compose.oracle.yml \
    -f docker-compose.oracle.https.yml \
    ps
else
  docker compose --env-file .env.oracle -f docker-compose.oracle.yml ps
fi

echo "Health check (may need ~30s on first start):"
set +e
curl -fsS http://localhost/health && echo
set -e

echo "Done."
