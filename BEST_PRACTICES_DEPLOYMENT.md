# Best Practices Implementation Summary

This document outlines the deployment verification best practices implemented for the Web Messenger application.

## Implemented Components

### 1. **Deployment Verifier Agent** (.github/agents/verify-deployment.agent.md)
Custom VS Code agent that specializes in pre-deployment verification.

**When to use**: 
- `@verify-deployment Check if backend is running`
- `@verify-deployment Verify all endpoints work`
- `@verify-deployment Compare local vs Oracle Cloud endpoints`

**Capabilities**:
- Docker Compose service health checks
- API endpoint testing with curl
- Environment variable validation
- Configuration parity checking
- Comprehensive pass/fail reporting

---

### 2. **Verification Scripts**

#### verify-deployment.sh
Comprehensive deployment verification with multiple modes:

```bash
./scripts/verify-deployment.sh                  # Full check (all tests)
./scripts/verify-deployment.sh local            # Only local services
./scripts/verify-deployment.sh production       # Only production endpoints
./scripts/verify-deployment.sh compare          # Configuration parity only
```

**Features**:
- ✓ Environment validation
- ✓ Docker service status
- ✓ Backend health checks
- ✓ Database connectivity
- ✓ Frontend responsiveness
- ✓ Environment variable checks
- ✓ Config parity verification
- ✓ Color-coded output with summaries

#### validate-env.sh
Environment variable validation tailored to your infrastructure:

```bash
./scripts/validate-env.sh              # Check .env
./scripts/validate-env.sh .env.oracle  # Check Oracle config
```

**Features**:
- ✓ Required variable enforcement
- ✓ Recommended variable checks
- ✓ Encryption key validation (64-char hex)
- ✓ Database URL format verification
- ✓ Email configuration audit
- ✓ Sensitive value masking

---

### 3. **Documentation Files**

#### ENDPOINT_MAPPING.md
Complete reference for all endpoints across environments:

- Local development endpoints
- Staging (Render) endpoints
- Production (Oracle Cloud) endpoints
- WebSocket configuration
- Health/status endpoints
- Authentication flows
- Chat/message endpoints
- URL resolution logic for frontend
- CORS and security configuration
- Debugging procedures

#### .github/instructions/deployment.instructions.md
File-specific instructions that appear when working with:
- `DEPLOYMENT.md`
- `ORACLE_DEPLOYMENT.md`
- `RENDER_REDEPLOY.md`
- `docker-compose*.yml`
- `.env*` files

**Provides**:
- Quick verification commands
- Endpoint mapping tables
- Environment variable templates
- Pre-deployment checklist
- Troubleshooting guide

#### .github/copilot-instructions.md
Workspace-level instructions for all developers:
- Quick start workflow
- Verification workflow before testing and deployment
- Available scripts and their purposes
- Troubleshooting reference

---

### 4. **Custom Agent**

#### verify-deployment.agent.md
Specialized subagent for deployment verification:

**Personality**: Deployment verification specialist
**Tools**: Terminal + file inspection
**Focus**: Pre-deployment validation
**Restrictions**: Read-only (no modifications)

Automatically invoked when you ask about:
- Running the app locally
- Checking endpoints
- Comparing environments
- Docker health
- Production readiness

---

## Verification Workflow

### Before Local Testing
```
1. Validate environment variables
   → ./scripts/validate-env.sh

2. Start services
   → ./scripts/start.sh

3. Verify local deployment
   → ./scripts/verify-deployment.sh local

4. Check production endpoints (if migrating)
   → ./scripts/verify-deployment.sh production
```

### Before Production Deployment
```
1. Full local verification
   → ./scripts/verify-deployment.sh all

2. Compare configurations
   → ./scripts/verify-deployment.sh compare

3. Production endpoint check
   → ./scripts/verify-deployment.sh production

4. Review checklist
   → See .github/copilot-instructions.md
```

---

## Key Endpoints

| Target | Health URL | API Base | Database |
|--------|-----------|----------|----------|
| **Local** | `http://localhost:8081/health` | `http://localhost:8081/api/v1` | `localhost:5432` |
| **Render** | `https://web-messenger-backend.onrender.com/health` | Same domain | Managed |
| **Oracle** | `https://api.messenger.prod/health` | Same domain | Oracle Cloud managed |

---

## Environment Variables

### Critical (must be set)
- `DATABASE_HOST` - PostgreSQL hostname
- `DATABASE_PORT` - PostgreSQL port
- `DATABASE_NAME` - Database name
- `DATABASE_USER` - PostgreSQL user
- `ENCRYPTION_MASTER_KEY` - 64-char hex key for message encryption

### Important (production)
- `RESEND_API_KEY` - Email service token
- `RESEND_FROM_EMAIL` - Sender email
- `SERVERPOD_ENV` - Environment mode

### Optional
- `SMTP_FROM_EMAIL` - Alternative email sender
- `ADMIN_DELETE_KEY` - Admin operations
- `VERBOSE_BACKEND_LOGS` - Debug logging

---

## Docker Services Verified

| Service | Container | Health Check | Port |
|---------|-----------|--------------|------|
| PostgreSQL | `messenger-postgres` | pg_isready | 5432 |
| Backend | `messenger-backend` | `/health` endpoint | 8081 |
| Frontend | web browser | HTTP response | 8080 |

---

## Configuration Files

| File | Purpose | Visibility | Mode |
|------|---------|-----------|------|
| `.env` | Local development vars | Gitignored | Edit manually |
| `.env.oracle` | Production Oracle vars | Gitignored | From vault |
| `.env.example` | Template for .env | Public | Reference |
| `docker-compose.yml` | Local services | Public | Reference |
| `docker-compose.oracle.yml` | Oracle production | Public | Reference |
| `ENDPOINT_MAPPING.md` | Endpoint reference | Public | New reference |

---

## Pre-Deployment Checklist

Use before every deployment:

```bash
# Step 1: Validate variables
./scripts/validate-env.sh
# Expected: "✓ All required variables are set!"

# Step 2: Start local services
./start.sh

# Step 3: Verify local environment
./scripts/verify-deployment.sh local
# Expected: "✓ All checks passed! Ready for deployment."

# Step 4: Compare configurations
./scripts/verify-deployment.sh compare
# Expected: "✓ All checks passed! Ready for deployment."

# Step 5: Test production endpoints
./scripts/verify-deployment.sh production
# Expected: Production backend responding

# Step 6: Push to repository
git add -A
git commit -m "Pre-deployment verification passed"
git push origin main
```

---

## Best Practices Implemented

✅ **Automation**: Verification scripts reduce manual testing
✅ **Documentation**: Endpoint mapping prevents URL mismatches
✅ **Environment Isolation**: Separate .env files for each target
✅ **Validation**: Early detection of configuration issues
✅ **Reporting**: Clear pass/fail indicators with actionable feedback
✅ **Troubleshooting**: Documented solutions for common issues
✅ **Consistency**: Same verification workflow for all developers
✅ **Parity Checking**: Ensures local matches production before deploy
✅ **Health Checks**: Automated endpoint validation
✅ **Agent Integration**: Custom VS Code agent for quick verification

---

## Usage Examples

### Quick Local Check
```bash
./scripts/verify-deployment.sh local
```

### Full Pre-Deployment
```bash
./scripts/verify-deployment.sh all
```

### Environment Setup
```bash
cp .env.example .env
nano .env
./scripts/validate-env.sh
```

### Using the Agent
```
User: @verify-deployment Check if backend is running

Agent Response:
✓ Docker daemon is running
✓ Backend container is running
✓ Backend health check: http://localhost:8081/health
✓ Backend API is responding: http://localhost:8081/api/v1
✓ Backend can access database
✓ All checks passed! Ready for deployment.
```

---

## Technology Stack Verified

- **Backend**: Dart/Serverpod on port 8081
- **Frontend**: Flutter Web, detects backend URL dynamically
- **Database**: PostgreSQL 13+ on port 5432
- **Deployment**: Docker Compose locally, cloud-managed in production
- **Targets**: Local (Docker), Render, Oracle Cloud

---

## Related Files Created/Updated

```
New Files:
├── .github/agents/verify-deployment.agent.md
├── .github/instructions/deployment.instructions.md
├── .github/copilot-instructions.md (updated)
├── scripts/verify-deployment.sh (new)
├── scripts/validate-env.sh (new)
├── ENDPOINT_MAPPING.md (new)
└── BEST_PRACTICES_DEPLOYMENT.md (this file)

Updated:
├── .github/copilot-instructions.md (quick reference)
```

---

## Next Steps

1. **Test the scripts**:
   ```bash
   ./scripts/validate-env.sh
   ./scripts/verify-deployment.sh local
   ```

2. **Update endpoint URLs**:
   - ENDPOINT_MAPPING.md: Update Oracle Cloud URL
   - verify-deployment.sh: Update BACKEND_ORACLE_PROD URL

3. **Integrate into CI/CD**:
   - Add `./scripts/verify-deployment.sh` to pre-merge checks
   - Run `./scripts/validate-env.sh` before deployments

4. **Team onboarding**:
   - Share copilot-instructions.md with team
   - Show checklist in README
   - Require verification before PRs

---

## Troubleshooting

### Scripts won't run
```bash
chmod +x scripts/verify-deployment.sh scripts/validate-env.sh
```

### Backend can't connect to database
```bash
./scripts/validate-env.sh        # Check DATABASE_* variables
docker-compose logs messenger-postgres  # Check if PostgreSQL is running
```

### Endpoints don't match between environments
```bash
./scripts/verify-deployment.sh compare  # Compare configs
cat ENDPOINT_MAPPING.md          # Review all endpoint mappings
```

### Environment variables keep failing
```bash
cp .env.example .env             # Start fresh
./scripts/validate-env.sh        # Identify missing vars
nano .env                        # Configure values
```

---

## Support

Each script includes help and detailed output:
- `./scripts/verify-deployment.sh --help` shows all modes
- Color-coded output (✓ pass, ✗ fail, ⚠ warning)
- Actionable suggestions for failures
- Related file references

For detailed guides, see:
- [.github/copilot-instructions.md](./.github/copilot-instructions.md) — Quick start
- [ENDPOINT_MAPPING.md](./ENDPOINT_MAPPING.md) — Endpoint reference
- [DEPLOYMENT.md](./DEPLOYMENT.md) — Full deployment guide
- [ORACLE_DEPLOYMENT.md](./ORACLE_DEPLOYMENT.md) — Oracle-specific
