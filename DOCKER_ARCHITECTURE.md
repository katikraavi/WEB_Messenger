# Docker Compose Architecture — Separated Frontend and Backend

## Overview

The Docker Compose setup has been refactored to **separate the frontend build from the backend**, allowing the backend to start independently even if the frontend has compilation errors.

### Key Changes

- **`docker-compose.yml`** — Backend-only services (PostgreSQL, Serverpod, Mailhog)
- **`docker-compose.frontend.yml`** — Optional frontend service (requires backend to be running)
- **Build Scripts** — Helper scripts for building and starting services

---

## Quick Start Options

### 1. **Backend Only** (Fastest for development)

```bash
./start-backend-only.sh
# OR
docker compose up
```

- **Starts:** PostgreSQL, Backend (Serverpod), Mailhog
- **Available:** http://localhost:8081 (Backend API)
- **Use when:** Frontend has compilation errors, focusing on backend development

### 2. **Backend + Frontend Together** (Full stack)

```bash
./build-and-start.sh
```

- **Builds and starts everything:**
  1. Backend services first (postgres, backend, mailhog)
  2. Waits for backend health check
  3. Builds frontend Docker image
  4. Starts frontend (nginx)

- **Available:**
  - Backend: http://localhost:8081
  - Frontend: http://localhost:5000
  - Mailhog: http://localhost:8025

### 3. **Build Frontend Locally, Then Use Docker** (Recommended for debugging)

```bash
# Build Flutter web locally
./build-frontend.sh

# Start backend
docker compose up -d

# Add frontend to running stack
docker compose -f docker-compose.yml -f docker-compose.frontend.yml up -d frontend
```

- Faster iteration on frontend
- Can debug the web build output locally (`frontend/build/web`)
- Frontend serves from pre-built assets via nginx

---

## Service Architecture

```
┌─────────────────────────────────────────────────┐
│ docker-compose.yml (Backend Stack)              │
├─────────────────────────────────────────────────┤
│ • postgres:5432           (PostgreSQL database) │
│ • serverpod:8081          (Dart backend)        │
│ • mailhog:1025 + :8025    (Email testing)       │
│                                                  │
│ Health: serverpod checks back-end API           │
└─────────────────────────────────────────────────┘
                         ↓
           (Optional — add frontend)
                         ↓
┌─────────────────────────────────────────────────┐
│ docker-compose.frontend.yml                     │
├─────────────────────────────────────────────────┤
│ • frontend:80/5000  (nginx + Flutter web)       │
│                                                  │
│ Depends on: serverpod running                   │
└─────────────────────────────────────────────────┘
```

---

## Common Commands

### Start backend only
```bash
docker compose up
```

### Start backend in background
```bash
docker compose up -d
```

### Add frontend (after backend is running)
```bash
docker compose -f docker-compose.yml -f docker-compose.frontend.yml up frontend
```

### View logs
```bash
# Backend only
docker compose logs -f serverpod

# Frontend only (after added)
docker compose logs -f frontend

# All services
docker compose logs -f
```

### Stop everything
```bash
docker compose down
```

### Stop specific service
```bash
docker compose stop frontend
```

### Rebuild backend
```bash
docker compose build serverpod
docker compose up -d serverpod
```

### Rebuild frontend
```bash
docker compose -f docker-compose.yml -f docker-compose.frontend.yml build frontend
docker compose -f docker-compose.yml -f docker-compose.frontend.yml up -d frontend
```

---

## Troubleshooting

### Frontend won't build: "No Flutter found"

The Docker container needs the Flutter SDK. Two options:

**Option A: Build locally first**
```bash
./build-frontend.sh        # Pre-build locally
docker compose up -d       # Start backend
docker compose -f docker-compose.yml -f docker-compose.frontend.yml up -d frontend
```

**Option B: Use the full build script**
```bash
./build-and-start.sh  # Handles everything automatically
```

### Backend starts but frontend container exits

Check frontend logs and ensure backend is healthy:
```bash
docker compose logs frontend
docker compose logs serverpod  # Check backend health
```

The frontend depends on the serverpod health check passing.

### Port already in use

Services use:
- **5432** — PostgreSQL
- **5000** — Frontend (nginx)
- **8081** — Backend (Serverpod)
- **1025** — Mailhog SMTP
- **8025** — Mailhog Web UI

Change ports in `docker-compose.yml` if needed, e.g.:
```yaml
ports:
  - "5001:80"  # Change 5000 to 5001
```

---

## For CI/CD

Use the full build script in your pipeline:
```bash
./build-and-start.sh
```

Or compose commands directly:
```bash
# Build backend
docker compose build

# Start everything
docker compose -f docker-compose.yml -f docker-compose.frontend.yml up -d

# Wait for health
docker compose exec -T serverpod curl http://localhost:8081/health

# Run tests, etc.
```

---

## Development Workflow

### When frontend has build errors

```bash
# 1. Backend is already running
docker compose up

# 2. Fix frontend code
# (edit files in ./frontend/lib)

# 3. Rebuild frontend locally
./build-frontend.sh  

# 4. Restart frontend container
docker compose -f docker-compose.yml -f docker-compose.frontend.yml restart frontend
```

### When backend has errors

```bash
# 1. Fix backend code
# (edit files in ./backend)

# 2. Rebuild and restart
docker compose build serverpod
docker compose up -d serverpod

# 3. Check logs
docker compose logs -f serverpod
```

---

## File Reference

| File | Purpose |
|------|---------|
| `docker-compose.yml` | Backend services (main file) |
| `docker-compose.frontend.yml` | Frontend service (compose override) |
| `./build-frontend.sh` | Build Flutter web locally |
| `./build-and-start.sh` | Build & start everything |
| `./start-backend-only.sh` | Start backend only |
| `./frontend/Dockerfile` | Frontend multi-stage build (Flutter → nginx) |
| `./backend/Dockerfile` | Backend services build |

---

## Next Steps

1. **Fix the frontend compilation error:**
   - See `lib/features/chats/providers/websocket_provider.dart:74`
   - Type mismatch: Stream return type missing `username` field

2. **Once fixed, build:**
   ```bash
   ./build-frontend.sh
   ```

3. **Start complete stack:**
   ```bash
   ./build-and-start.sh
   ```

---

*Last updated: March 26, 2026*
