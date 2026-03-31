---
description: "Use when: checking deployment, verifying endpoints work, ensuring local matches production, starting app, Docker issues. Includes endpoint mapping, environment setup, and rapid verification workflows."
applyTo: "DEPLOYMENT.md,ORACLE_DEPLOYMENT.md,RENDER_REDEPLOY.md,docker-compose*.yml,.env*"
---

# Deployment & Verification Guide

## Quick Verification

Before deploying, always run:

```bash
chmod +x scripts/verify-deployment.sh
./scripts/verify-deployment.sh       # Full check
./scripts/verify-deployment.sh local # Local only
./scripts/verify-deployment.sh compare # Config parity
```

## Endpoint Mapping

### Local Development
- **Backend**: `http://localhost:8081`
- **Frontend**: `http://localhost:8080` (or via `flutter run`)
- **Database**: `localhost:5432` (PostgreSQL)
- **Health check**: `GET http://localhost:8081/health`

### Production (Oracle Cloud)
- **Backend**: `https://api-prod.messenger.internal` (CONFIGURE IN .env.oracle)
- **Frontend**: `https://messenger.prod` (CONFIGURE IN deployment config)
- **Database**: Managed by Oracle Cloud
- **Health check**: `GET https://api-prod.messenger.internal/health`

### Staging (Render)
- **Backend**: `https://web-messenger-backend.onrender.com`
- **Frontend**: `https://web-messenger-frontend.onrender.com` (if deployed)

## Pre-Deployment Checklist

- [ ] All Docker services running: `docker-compose ps`
- [ ] Backend health: `curl http://localhost:8081/health`
- [ ] Database connected: `docker-compose logs messenger-postgres | grep "listening"`
- [ ] Migrations applied: Check backend logs for migration status
- [ ] Environment variables set: `.env` file configured
- [ ] Frontend can reach backend: Check Network tab in browser DevTools
- [ ] No error logs: `docker-compose logs | grep -i error`

## Environment Variables

### Local (.env)
```bash
DATABASE_URL=postgres://messenger_user:messenger_password@postgres:5432/messenger_db
SERVERPOD_ENV=development
ENCRYPTION_MASTER_KEY=a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6a7b8c9d0e1f2
RESEND_API_KEY=  # Leave empty for local testing
SMTP_FROM_EMAIL=noreply@local.messenger
```

### Production (.env.oracle)
```bash
DATABASE_URL=<oracle-cloud-postgres-url>
SERVERPOD_ENV=production
ENCRYPTION_MASTER_KEY=<secure-key-from-vault>
RESEND_API_KEY=<your-resend-key>
SMTP_FROM_EMAIL=noreply@messenger
```

## Running Locally

```bash
# Start all services
./start.sh

# Or manually with docker-compose
docker-compose up -d

# View logs
docker-compose logs -f messenger-backend

# Stop services
docker-compose down
```

## Testing Endpoints

### Health Check
```bash
curl http://localhost:8081/health
```

### API Status
```bash
curl -i http://localhost:8081/api/v1
```

### Database Status
```bash
curl http://localhost:8081/migrations
```

### With Authentication (if needed)
```bash
curl -H "Authorization: Bearer <token>" http://localhost:8081/api/protected
```

## Troubleshooting

### Backend won't start
1. Check database is running: `docker-compose logs messenger-postgres`
2. Check port 8081 is free: `lsof -i :8081`
3. Review backend logs: `docker-compose logs messenger-backend`

### Database connection failed
1. Verify PostgreSQL container: `docker-compose ps messenger-postgres`
2. Check DATABASE_URL in `.env`
3. Test connection: `docker exec messenger-postgres psql -U messenger_user -d messenger_db`

### Frontend can't reach backend
1. Check backend is running: `curl http://localhost:8081/health`
2. Verify BACKEND_URL in frontend config
3. Check browser CORS errors in DevTools
4. If using Docker network, verify container DNS resolution

### Port conflicts
```bash
# Find what's using port 8081
lsof -i :8081

# Use different ports if needed
docker-compose -f docker-compose.yml -p custom_name up
```

## Deployment Workflow

1. **Verify locally**: `./scripts/verify-deployment.sh local`
2. **Check parity**: `./scripts/verify-deployment.sh compare`
3. **Build artifacts**: See [DEPLOYMENT.md](./DEPLOYMENT.md) or [ORACLE_DEPLOYMENT.md](./ORACLE_DEPLOYMENT.md)
4. **Verify production**: `./scripts/verify-deployment.sh production`
5. **Monitor after deploy**: Check logs for errors

## Configuration Files

| File | Purpose | Visibility |
|------|---------|-----------|
| `.env` | Local development variables | Sensitive (gitignored) |
| `.env.oracle` | Oracle Cloud production vars | Sensitive (gitignored) |
| `.env.example` | Template for .env | Public (committed) |
| `docker-compose.yml` | Local compose setup | Public |
| `docker-compose.oracle.yml` | Oracle Cloud setup | Public |
| `docker-compose.prod.yml` | Generic production setup | Public |
| `oracle.env.example` | Template for .env.oracle | Public |

## Notes for Developers

- **Always** run verification before pushing to main
- **Always** test locally before deploying to production
- **Never** commit .env files — use .env.example template
- **Always** check endpoint URLs match between local and target environment
- **Always** review deployment documentation before deploying
