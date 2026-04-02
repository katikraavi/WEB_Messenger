---
name: "Web Messenger Deployment Verification"
description: "Guides for starting the app locally, verifying endpoints work correctly, and ensuring production config matches local setup before deployment."
---

# Web Messenger: Deployment & Verification

## 🚀 Quick Start

Start the app locally with verified endpoints:

```bash
# 1. Validate your environment
./scripts/validate-env.sh

# 2. Start all services
./scripts/start.sh

# 3. Run full verification
./scripts/verify-deployment.sh

# 4. Check specific environment
./scripts/verify-deployment.sh local       # Local only
./scripts/verify-deployment.sh compare     # Config parity check
./scripts/verify-deployment.sh production  # Production endpoints
```

## 📋 Verification Workflow

### Before Local Testing
1. **Validate environment**: `./scripts/validate-env.sh`
   - Checks all required variables are set
   - Validates encryption key format
   - Confirms database config

2. **Verify Docker setup**: `docker-compose ps`
   - PostgreSQL running
   - Backend container ready
   - Network connectivity

3. **Start services**: `./scripts/verify-deployment.sh local`
   - Database health check
   - Backend responds to health endpoint
   - No critical errors in logs

### Before Production Deployment
1. **Full local verification**: `./scripts/verify-deployment.sh all`
   - All local endpoints passing
   - Environment variables configured
   - Config parity check (local vs prod)

2. **Compare environments**: `./scripts/verify-deployment.sh compare`
   - Review `.env` vs `.env.oracle`
   - Check docker-compose.yml differences
   - Ensure migration consistency

3. **Production readiness**: `./scripts/verify-deployment.sh production`
   - Production backend responding
   - Endpoints match deployer documentation
   - All systems online

## 🔌 Endpoint Reference

| Endpoint | Local | Purpose |
|----------|-------|---------|
| Health | `http://localhost:8081/health` | Backend alive check |
| API | `http://localhost:8081/api/v1` | API base path |
| Migrations | `http://localhost:8081/migrations` | DB migration status |

## ⚙️ Environment Management

```bash
# Local development (.env)
./scripts/validate-env.sh

# Production (.env.oracle)
./scripts/validate-env.sh .env.oracle

# Create from template if missing
cp .env.example .env
# Then: nano .env  (configure values)
```

## 🛠️ Available Scripts

| Script | Purpose |
|--------|---------|
| `./scripts/verify-deployment.sh` | Full deployment verification |
| `./scripts/validate-env.sh` | Check environment variables |
| `./scripts/start.sh` | Start all local services |
| `docker-compose ps` | View service status |
| `docker-compose logs -f` | Stream all service logs |

## 📚 Related Documentation

- [DEPLOYMENT.md](./DEPLOYMENT.md) — Full deployment guide
- [ORACLE_DEPLOYMENT.md](./ORACLE_DEPLOYMENT.md) — Oracle Cloud deployment
- [RENDER_REDEPLOY.md](./RENDER_REDEPLOY.md) — Render.com deployment
- `.github/instructions/deployment.instructions.md` — Detailed reference

## 💡 Developer Tips

**Always verify before pushing**
```bash
./scripts/verify-deployment.sh local && git push
```

**Check specific environment**
```bash
# Just local
./scripts/verify-deployment.sh local

# Just production
./scripts/verify-deployment.sh production
```

**Debug endpoint issues**
```bash
# Check if service is running
docker-compose ps

# View logs
docker-compose logs messenger-backend

# Test endpoint manually
curl -v http://localhost:8081/health
```

**Reset everything**
```bash
docker-compose down -v  # Remove volumes too
./scripts/start.sh     # Fresh start
./scripts/verify-deployment.sh
```

## ❓ Troubleshooting

| Issue | Solution |
|-------|----------|
| "Connection refused" | Run `./scripts/start.sh` to start services |
| "Port already in use" | Kill process on port 8081: `lsof -i :8081` |
| "Database error" | Check `.env` DATABASE_* vars, run `docker-compose logs messenger-postgres` |
| "Endpoints don't match" | Compare `.env` vs `.env.oracle`, see deployment docs |

## 🎯 Pre-Deployment Checklist

- [ ] `./scripts/validate-env.sh` passes
- [ ] `./scripts/verify-deployment.sh local` shows all ✓
- [ ] No errors in `docker-compose logs`
- [ ] Config parity confirmed: `./scripts/verify-deployment.sh compare`
- [ ] Production endpoints reachable (if deploying now)
- [ ] Code committed and pushed to main

**Then**→  Deploy with confidence! 🚀
