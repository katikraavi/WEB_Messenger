# Endpoint Configuration & Mapping

This document defines all endpoints used in Web Messenger and how they map between local development, staging, and production environments.

## Architecture Overview

```
Frontend (Flutter Web)
    ↓
API Client (dynamic URL detection)
    ↓
Backend (Dart/Serverpod)
    ↓
PostgreSQL Database
```

## Endpoint Mapping Reference

### Core Services

| Service | Local | Staging (Render) | Production (Oracle) | Purpose |
|---------|-------|------------------|-------------------|---------|
| Backend API | `http://localhost:8081` | `https://web-messenger-backend.onrender.com` | `https://api.messenger.prod` | Serverpod backend |
| Frontend | `http://localhost:8080` | `https://web-messenger-frontend.onrender.com` | `https://messenger.prod` | Flutter Web app |
| Database | `localhost:5432` | Managed (render.com) | Oracle Cloud managed | PostgreSQL |

### Health & Status Endpoints

| Endpoint | Method | Local URL | Purpose | Expected Response |
|----------|--------|-----------|---------|-------------------|
| Health Check | GET | `/health` | Backend liveness | `200 OK` |
| API Status | GET | `/api/v1` | API availability | `200 OK` |
| Migrations | GET | `/migrations` | DB migration status | `200 OK` or migration list |
| Version | GET | `/version` | Backend version info | `200 OK` with version |

### Authentication Endpoints

| Endpoint | Method | Local URL | Purpose |
|----------|--------|-----------|---------|
| Register | POST | `/auth/register` | User registration |
| Login | POST | `/auth/login` | User authentication |
| Logout | POST | `/auth/logout` | End session |
| Refresh Token | POST | `/auth/refresh` | Token renewal |
| Verify Email | GET | `/auth/verify/:token` | Email verification |
| Reset Password | POST | `/auth/reset-password` | Password reset |

### Chat Endpoints

| Endpoint | Method | Local URL | Purpose |
|----------|--------|-----------|---------|
| List Chats | GET | `/api/v1/chats` | Get user's chats |
| Create Chat | POST | `/api/v1/chats` | Create new chat |
| Get Chat | GET | `/api/v1/chats/:id` | Get chat details |
| Send Message | POST | `/api/v1/chats/:id/messages` | Send message |
| List Messages | GET | `/api/v1/chats/:id/messages` | Get messages |
| Search | GET | `/api/v1/search` | Global search |

### WebSocket (Real-time)

| Endpoint | Local URL | Purpose |
|----------|-----------|---------|
| WebSocket | `/ws` | Real-time message delivery |
| Subscribe | `ws://localhost:8081/ws?token=<jwt>` | Connect to live updates |

## Environment-Specific Configuration

### Local Development (.env)

```bash
# Backend
SERVERPOD_PORT=8081
SERVERPOD_ENV=development
SERVERPOD_PROTOCOL=http

# Database
DATABASE_URL=postgres://messenger_user:messenger_password@postgres:5432/messenger_db
DATABASE_HOST=postgres
DATABASE_PORT=5432
DATABASE_NAME=messenger_db
DATABASE_USER=messenger_user
DATABASE_PASSWORD=messenger_password

# Security
ENCRYPTION_MASTER_KEY=a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6a7b8c9d0e1f2

# Email (optional for local)
RESEND_API_KEY=
RESEND_FROM_EMAIL=noreply@local.messenger

# Features
VERBOSE_BACKEND_LOGS=false
```

### Production (.env.oracle)

```bash
# Backend
SERVERPOD_PORT=8081
SERVERPOD_ENV=production
SERVERPOD_PROTOCOL=https

# Database  
DATABASE_URL=<oracle-cloud-rds-url>
DATABASE_HOST=<oracle-host>
DATABASE_PORT=5432
DATABASE_NAME=messenger_db
DATABASE_USER=<oracle-user>
DATABASE_PASSWORD=<oracle-password-from-vault>

# Security
ENCRYPTION_MASTER_KEY=<from-vault-production-key>

# Email
RESEND_API_KEY=<from-vault>
RESEND_FROM_EMAIL=noreply@messenger

# Features
VERBOSE_BACKEND_LOGS=false
```

## Frontend URL Resolution Logic

The frontend uses this logic to determine the backend URL:

```
1. If environment variable BACKEND_URL is set
   → Use BACKEND_URL

2. If running on web (Flutter web):
   → If current host is localhost/127.0.0.1
     → Use http://localhost:8081
   → If current host is *.onrender.com
     → Use https://web-messenger-backend.onrender.com
   → Otherwise use same-origin (current protocol + authority)

3. If running on mobile (Android/iOS):
   → Use https://web-messenger-backend.onrender.com

4. Default fallback:
   → https://web-messenger-backend.onrender.com
```

## Cross-Environment Testing

### Test Matrix

Before deployment, verify these combinations:

| Local Frontend | Backend URL | Expected | Test Command |
|---|---|---|---|
| `localhost:8080` | `localhost:8081` | ✓ Works | `./scripts/verify-deployment.sh local` |
| Production FE | `production-api` | ✓ Works | `./scripts/verify-deployment.sh production` |
| Web (same origin) | Auto-resolved | ✓ Works | Browser network tab verify |

### Verification Commands

```bash
# Test local endpoints
curl -i http://localhost:8081/health

# Test staging
curl -i https://web-messenger-backend.onrender.com/health

# Test production
curl -i https://api.messenger.prod/health

# Test with auth header (if needed)
curl -H "Authorization: Bearer <token>" \
  http://localhost:8081/api/v1/chats
```

## CORS Configuration

| Environment | Origins Allowed | Credentials |
|---|---|---|
| Local | `http://localhost:*`, `http://127.0.0.1:*` | true |
| Staging | `https://*.onrender.com` | true |
| Production | `https://messenger.prod` | true |

## WebSocket Configuration

| Environment | WSS URL | Port | Notes |
|---|---|---|---|
| Local | `ws://localhost:8081/ws` | 8081 | HTTP only |
| Staging | `wss://web-messenger-backend.onrender.com/ws` | 443 | Secure, proxied |
| Production | `wss://api.messenger.prod/ws` | 443 | Secure, managed |

## Database Connection Management

### Connection Pool Settings

| Environment | Max Connections | Timeout | Retry Logic |
|---|---|---|---|
| Local | 10 | 5s | 3 retries, 1s delay |
| Production | 50 | 10s | 5 retries, 2s exponential |

### Migration Paths

Migrations are applied automatically on startup:

```
Backend Start
  ↓
Read migrations/ directory
  ↓
Execute new migrations against DATABASE_URL
  ↓
Log results to stdout
  ↓
Continue with server initialization
```

## Configuration Parity Checklist

Before deploying, ensure parity:

- [ ] Database version matches (PostgreSQL 13+)
- [ ] Encryption key format is identical (64-char hex)
- [ ] Port configuration matches deployment target
- [ ] CORS origins are correctly configured
- [ ] Email service credentials are valid
- [ ] SSL/TLS certificates are valid (production)
- [ ] Network routing allows backend ↔ frontend communication
- [ ] Firewall rules permit required ports

## Debugging Endpoint Issues

### Backend unreachable from frontend

```bash
# Check backend is running
docker-compose logs messenger-backend | tail -20

# Verify port is listening
netstat -tuln | grep 8081
or
lsof -i :8081

# Test directly
curl -v http://localhost:8081/health

# Check CORS headers
curl -i -H "Origin: http://localhost:8080" http://localhost:8081/api/v1
```

### Database connection failed

```bash
# Check PostgreSQL is running
docker-compose logs messenger-postgres | tail -20

# Test connection directly
docker exec messenger-postgres \
  psql -U messenger_user -d messenger_db -c "SELECT 1;"

# Verify DATABASE_URL format
cat .env | grep DATABASE_URL
```

### WebSocket connection refused

```bash
# Check backend WebSocket endpoint
curl -i -N -H "Connection: Upgrade" \
  -H "Upgrade: websocket" \
  http://localhost:8081/ws

# View WebSocket logs
docker-compose logs messenger-backend | grep -i websocket
```

## Related Files

- `.github/copilot-instructions.md` — Quick start guide
- `.github/instructions/deployment.instructions.md` — Detailed deployment
- `scripts/verify-deployment.sh` — Automated verification
- `scripts/validate-env.sh` — Environment variable validation
- `.env.example` — Local development template
- `oracle.env.example` — Oracle Cloud template
- `docker-compose.yml` — Local service definitions
- `docker-compose.oracle.yml` — Oracle production definitions
- `Dockerfile` — Backend container image
- `DEPLOYMENT.md` — Deployment procedures
- `ORACLE_DEPLOYMENT.md` — Oracle-specific procedures
