# Deployment Guide

This guide covers production deployment for the Mobile Messenger stack.

## Prerequisites

- Docker Engine 24+
- Docker Compose v2+
- Access to a PostgreSQL instance (managed or self-hosted)
- A container registry (GHCR, Docker Hub, or private registry)
- A reverse proxy / ingress with TLS (Nginx, Traefik, cloud LB)

## Production Environment Variables

Create a root `.env` file (or secret manager entries) with these keys:

### Required backend and database keys

- `DATABASE_URL`
- `DATABASE_SSL`
- `DATABASE_HOST`
- `DATABASE_PORT`
- `DATABASE_NAME`
- `DATABASE_USER`
- `DATABASE_PASSWORD`
- `SERVERPOD_ENV`
- `SERVERPOD_PORT`

### Required SMTP keys

- `SMTP_HOST`
- `SMTP_PORT`
- `SMTP_FROM_EMAIL`
- `SMTP_FROM_NAME`
- `SMTP_USER`
- `SMTP_PASSWORD`
- `SMTP_SECURE`

### Optional build metadata keys

- `FRONTEND_BUILD_MODE`
- `FLUTTER_BUILD_NUMBER`
- `FLUTTER_BUILD_NAME`
- `APP_NAME`
- `APP_VERSION`
- `APP_DEBUG`

## Docker Build and Push

Build backend and frontend images, then push to your registry:

```bash
# Backend image
cd backend
docker build -t ghcr.io/<org>/mobile-messenger-backend:<tag> .
docker push ghcr.io/<org>/mobile-messenger-backend:<tag>

# Frontend web image (example if you package web build as a container)
cd ../frontend
docker build -t ghcr.io/<org>/mobile-messenger-frontend:<tag> .
docker push ghcr.io/<org>/mobile-messenger-frontend:<tag>
```

## Example docker-compose.prod.yml

```yaml
services:
  serverpod:
    image: ghcr.io/<org>/mobile-messenger-backend:<tag>
    restart: unless-stopped
    env_file:
      - .env
    ports:
      - "8081:8081"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8081/health"]
      interval: 10s
      timeout: 5s
      retries: 3
      start_period: 10s
```

For Neon or any other managed PostgreSQL provider, do not run the bundled `postgres`
service in production. Point the backend at the managed database instead.

## Neon Example

Use the pooled connection string from Neon as `DATABASE_URL` and force SSL:

```env
DATABASE_URL=postgresql://<user>:<password>@<host>/<database>?sslmode=require
DATABASE_SSL=true
SERVERPOD_ENV=production
SERVERPOD_PORT=8081
```

If your deploy platform does not inject `DATABASE_URL`, also set these individual keys
to the same Neon values:

```env
DATABASE_HOST=<host>
DATABASE_PORT=5432
DATABASE_NAME=<database>
DATABASE_USER=<user>
DATABASE_PASSWORD=<password>
```

## Database Migration Steps (Production)

Always run migrations before routing production traffic to a new backend image.

```bash
cd backend
# Verify migrations in repository
ls migrations/

# Apply against the production DATABASE_URL
DATABASE_URL="postgresql://<user>:<password>@<host>/<database>?sslmode=require" \
DATABASE_SSL=true \
dart run scripts/run_migrations.dart
```

If you run migrations from inside a container, execute them against the same `DATABASE_URL` used by production runtime.

## Deploy and Start

```bash
# Pull latest tagged images
docker compose -f docker-compose.prod.yml pull

# Start or update
docker compose -f docker-compose.prod.yml up -d
```

## Health Check Verification

```bash
curl -f http://localhost:8081/health
```

Expected: HTTP `200` and a healthy payload.

## Rollback Procedure

If a deployment fails, roll back to the previous known-good image tag.

```bash
# 1) Update docker-compose.prod.yml image tags to previous versions
# 2) Redeploy
docker compose -f docker-compose.prod.yml up -d

# 3) Verify health
curl -f http://localhost:8081/health
```

If the issue is migration-related:

- Stop new writes if possible.
- Restore database from latest backup.
- Re-deploy with the previous application version.

## Notes

- Keep `.env` out of version control.
- Store secrets in your deployment platform's secret manager.
- Pin image tags (avoid `latest`) for predictable rollbacks.
- Neon requires TLS. Set `DATABASE_SSL=true` or include `sslmode=require` in `DATABASE_URL`.
