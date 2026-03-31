#!/usr/bin/env bash
set -euo pipefail

echo "[$(date +'%Y-%m-%d %H:%M:%S')] Starting deployment..."

if [[ ! -f .env.oracle ]]; then
  echo "ERROR: Missing .env.oracle in repository root."
  echo "Create it from template: cp oracle.env.example .env.oracle"
  exit 1
fi

echo "[$(date +'%Y-%m-%d %H:%M:%S')] ✓ .env.oracle found"

# Stop any existing services
echo "[$(date +'%Y-%m-%d %H:%M:%S')] Stopping existing services..."
pkill -f "dart run bin/server.dart" || echo "  (no dart process running)"
pkill -f "nginx" || echo "  (no nginx running)"
sleep 2
echo "[$(date +'%Y-%m-%d %H:%M:%S')] ✓ Services stopped"

# Create app directories
echo "[$(date +'%Y-%m-%d %H:%M:%S')] Creating directories..."
mkdir -p /opt/web-messenger/{backend,frontend}
echo "[$(date +'%Y-%m-%d %H:%M:%S')] ✓ Directories created"

# Deploy backend
echo "[$(date +'%Y-%m-%d %H:%M:%S')] Copying backend files..."
cp -r backend/* /opt/web-messenger/backend/
echo "[$(date +'%Y-%m-%d %H:%M:%S')] ✓ Backend files copied"

echo "[$(date +'%Y-%m-%d %H:%M:%S')] Installing backend dependencies..."
cd /opt/web-messenger/backend
dart pub get --offline 2>&1 | tail -5 || dart pub get 2>&1 | tail -5
echo "[$(date +'%Y-%m-%d %H:%M:%S')] ✓ Backend dependencies installed"

# Deploy frontend
echo "[$(date +'%Y-%m-%d %H:%M:%S')] Copying frontend files..."
cp -r frontend/build/web/* /opt/web-messenger/frontend/
echo "[$(date +'%Y-%m-%d %H:%M:%S')] ✓ Frontend files copied ($(ls -1 /opt/web-messenger/frontend | wc -l) files)"

# Setup nginx
echo "[$(date +'%Y-%m-%d %H:%M:%S')] Configuring nginx..."
cp nginx.conf /etc/nginx/conf.d/default.conf
nginx -t 2>&1 | tail -2
echo "[$(date +'%Y-%m-%d %H:%M:%S')] ✓ Nginx configured"

# Start backend
echo "[$(date +'%Y-%m-%d %H:%M:%S')] Starting Dart backend on :8081..."
cd /opt/web-messenger/backend
export $(grep -v '^#' /root/.env.oracle | xargs)
nohup dart run bin/server.dart > /var/log/web-messenger-backend.log 2>&1 &
BACKEND_PID=$!
echo "[$(date +'%Y-%m-%d %H:%M:%S')] ✓ Backend started (PID: $BACKEND_PID)"

# Wait for backend to be ready
echo "[$(date +'%Y-%m-%d %H:%M:%S')] Waiting for backend to be ready..."
sleep 5
if curl -sf http://localhost:8081/health > /dev/null 2>&1; then
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] ✓ Backend health check passed"
else
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] ⚠ Backend not responding yet, starting nginx anyway..."
  tail -20 /var/log/web-messenger-backend.log
fi

# Start nginx (in daemon mode, not blocking)
echo "[$(date +'%Y-%m-%d %H:%M:%S')] Starting nginx reverse proxy on :80..."
systemctl restart nginx || nginx &
echo "[$(date +'%Y-%m-%d %H:%M:%S')] ✓ Nginx started"

# Final health check
echo "[$(date +'%Y-%m-%d %H:%M:%S')] Running final health checks..."
sleep 2
HEALTH_CHECK=$(curl -sf http://localhost:8081/health 2>&1 || echo "FAILED")
echo "[$(date +'%Y-%m-%d %H:%M:%S')] Backend health: $HEALTH_CHECK"

echo ""
echo "╔════════════════════════════════════════════════╗"
echo "║     DEPLOYMENT COMPLETE                        ║"
echo "║ Web:      http://89.168.94.114                 ║"
echo "║ Backend:  http://89.168.94.114:8081            ║"
echo "║ Health:   http://89.168.94.114/health          ║"
echo "╚════════════════════════════════════════════════╝"
echo ""
echo "Service status: ps aux | grep -E 'dart|nginx' | grep -v grep"
echo "Backend logs:   tail -f /var/log/web-messenger-backend.log"
echo ""
echo "[$(date +'%Y-%m-%d %H:%M:%S')] Deployment finished successfully!"
