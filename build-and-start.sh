#!/bin/bash

# Build & Start Everything (including frontend)
# This script builds both backend and frontend Docker images, then starts all services.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "════════════════════════════════════════════════════════════════"
echo "  Building & Starting Complete Stack"
echo "════════════════════════════════════════════════════════════════"

echo ""
echo "1️⃣  Starting backend services (postgres, mailhog, backend)..."
docker compose up -d

echo ""
echo "⏳ Waiting for backend health check..."
for i in {1..30}; do
    if docker compose exec -T serverpod curl -f http://localhost:8081/health > /dev/null 2>&1; then
        echo "✅ Backend is healthy"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "❌ Backend failed to start after 30 seconds"
        exit 1
    fi
    echo "   Attempt $i/30..."
    sleep 1
done

echo ""
echo "2️⃣  Building frontend service..."
docker compose -f docker-compose.yml -f docker-compose.frontend.yml build frontend

echo ""
echo "3️⃣  Starting frontend service..."
docker compose -f docker-compose.yml -f docker-compose.frontend.yml up -d frontend

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✅ All services are running!"
echo ""
echo "Backend:  http://localhost:8081"
echo "Frontend: http://localhost:5000"
echo "Mailhog:  http://localhost:8025"
echo ""
echo "Logs:"
echo "  docker compose logs -f serverpod      # Backend logs"
echo "  docker compose logs -f frontend       # Frontend logs (nginx)"
echo ""
echo "Stop everything: docker compose down"
echo "=="============"=="=="=="=="=="=="=="=="=="=="=="=="=="=="=="=="
