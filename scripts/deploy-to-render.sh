#!/usr/bin/env bash

set -euo pipefail

echo "Render redeploy helper"
echo ""

if ! command -v openssl >/dev/null 2>&1; then
	echo "openssl is required to generate an ENCRYPTION_MASTER_KEY"
	exit 1
fi

ENCRYPTION_KEY="$(openssl rand -hex 32)"

cat <<EOF
Use the runbook in RENDER_REDEPLOY.md for exact steps.

Suggested environment values:
SERVERPOD_ENV=production
SERVERPOD_PORT=8081
DATABASE_SSL=true
ENCRYPTION_MASTER_KEY=$ENCRYPTION_KEY
SMTP_PORT=587
SMTP_FROM_NAME=Mobile Messenger
SMTP_SECURE=false
VERBOSE_BACKEND_LOGS=false

After deploy, run:
./scripts/deploy/render_post_deploy_check.sh https://YOUR-RENDER-URL.onrender.com
EOF
