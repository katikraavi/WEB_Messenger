#!/usr/bin/env bash
set -euo pipefail

if [[ ! -f .env.oracle ]]; then
  echo "Missing .env.oracle in repository root."
  echo "Create it from template: cp oracle.env.example .env.oracle"
  exit 1
fi

echo "Deploying web-messenger to Oracle VM (direct services, no Docker build)..."

# Stop any existing services
echo "Stopping existing services..."
pkill -f "dart run bin/server.dart" || true
pkill -f "nginx" || true
sleep 2

# Create app directories
mkdir -p /opt/web-messenger/{backend,frontend}

# Deploy backend
echo "Deploying backend..."
cp -r backend/* /opt/web-messenger/backend/
cd /opt/web-messenger/backend
dart pub get --offline || dart pub get

# Deploy frontend
echo "Deploying frontend..."
cp -r frontend/build/web/* /opt/web-messenger/frontend/

# Setup nginx
echo "Configuring nginx..."
cp nginx.conf /etc/nginx/conf.d/default.conf

# Start backend
echo "Starting backend (Dart server on :8081)..."
cd /opt/web-messenger/backend
export $(grep -v '^#' /root/.env.oracle | xargs)
nohup dart run bin/server.dart > /var/log/web-messenger-backend.log 2>&1 &
BACKEND_PID=$!
echo "Backend PID: $BACKEND_PID"

# Wait for backend to be ready
sleep 3

# Start nginx
echo "Starting nginx (reverse proxy on :80)..."
nginx -g "daemon off;" &
NGINX_PID=$!
echo "Nginx PID: $NGINX_PID"

echo "Deployment complete!"
echo ""
echo "Status:"
echo "  Backend: http://localhost:8081/health"
echo "  Frontend: http://localhost/health"
echo ""
echo "Logs:"
echo "  Backend: tail -f /var/log/web-messenger-backend.log"
echo "  Nginx: journalctl -u nginx -f"
echo ""

# Keep script running
wait
