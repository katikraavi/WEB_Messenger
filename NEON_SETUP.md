# Neon Database + Render Deployment Configuration

## Environment Variables for Render Backend

Copy these into your Render backend service environment:

```
# ========================================
# DATABASE (Neon)
# ========================================
DATABASE_URL=postgresql://neon_user:YOUR_NEON_PASSWORD@ep-XXXXX.us-east-2.aws.neon.tech/messenger_db?sslmode=require
DATABASE_SSL=true
DATABASE_HOST=ep-XXXXX.us-east-2.aws.neon.tech
DATABASE_PORT=5432
DATABASE_NAME=messenger_db
DATABASE_USER=neon_user
DATABASE_PASSWORD=YOUR_NEON_PASSWORD

# ========================================
# SERVER CONFIGURATION
# ========================================
SERVERPOD_ENV=production
SERVERPOD_PORT=8081
APP_BASE_URL=https://messenger-backend-XXXXX.onrender.com

# ========================================
# ENCRYPTION
# ========================================
ENCRYPTION_MASTER_KEY=a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6a7b8c9d0e1f2

# ========================================
# EMAIL (SMTP)
# ========================================
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_FROM_EMAIL=noreply@yourdomain.com
SMTP_FROM_NAME=Mobile Messenger
SMTP_USER=your-email@gmail.com
SMTP_PASSWORD=your-google-app-password
SMTP_SECURE=true
```

## Frontend Environment Variables for Render

```
BACKEND_URL=https://messenger-backend-XXXXX.onrender.com
```

Important:

- Do not use `BACKEND_URL=https://api` or `BACKEND_URL=http://api`.
- If frontend and backend are on the same Render service/domain, set `BACKEND_URL=/`.
- If they are separate services, set `BACKEND_URL` to the full backend origin.

If browser console shows `POST https://api/auth/login net::ERR_NAME_NOT_RESOLVED`, frontend is built with an invalid backend URL and must be rebuilt/redeployed.

## Step-by-Step Setup

### 1. Create Neon Project
- Visit https://console.neon.tech
- Click "New Project"
- Name: `messenger`
- Database: `messenger_db`
- Region: Same as your Render region

### 2. Get Neon Connection String
- Go to Project Settings
- Select "Connection Details"
- Switch to "Pooled Connection"
- Copy the full connection string
- Replace `YOUR_NEON_PASSWORD` in `DATABASE_URL` above

### 3. Deploy Backend to Render
1. Go to https://render.com
2. Click "New +" → "Web Service"
3. Connect your GitHub repository
4. Configure:
   - Name: `messenger-backend`
   - Environment: `Docker`
   - Build: (default)
   - Start: (default)
5. In "Environment", paste all variables above
6. Click "Deploy"

### 4. Deploy Frontend to Render
1. Click "New +" → "Static Site"
2. Connect GitHub repository
3. Build Command: 
   ```
   cd frontend && flutter build web --release
   ```
4. Publish Directory: `frontend/build/web`
5. Click "Create Static Site"

### 5. Test Your Deployment
Once both services are deployed:

1. Visit frontend URL: `https://messenger-frontend-XXXXX.onrender.com`
2. Register a new account
3. Check logs if anything fails:
   - Render Dashboard → Service → Logs

## Neon Free Tier Limits

✅ **Included:**
- Up to 3 projects
- 5 GB storage
- Generous compute credits (~$15/month value)
- Free SSL/TLS
- Automatic backups
- Connection pooling

⚠️ **Rate limits:**
- 3,000 compute units/month (roughly ~100 hours)
- Auto-suspend after 5 minutes of inactivity (wakes on demand)

**Upgrade to Pro when:**
- You exceed free tier limits
- Need 24/7 availability (no auto-suspend)
- Want priority support

Cost: ~$15/month for Pro tier with 25 GB storage

## Troubleshooting

### "Connection refused" error
- Check `sslmode=require` is in DATABASE_URL
- Verify Render backend can reach Neon IP (it can - Neon is public)
- Check DATABASE_SSL=true

### "Too many connections"
- Neon free tier has limited connections
- Ensure connection pooling is enabled
- Use `?sslmode=require` to enable pooling

### "Disk quota exceeded"
- Check database size in Neon console
- Delete old message/media files if needed
- Upgrade Neon plan

### "SSL certificate error"
- Make sure you're using the _pooled_ connection string
- For direct connections, trust the self-signed cert

## Verify Neon Connection Locally (Optional)

Test connection from your machine:

```bash
# Install psql if needed
# Then run:
psql "postgresql://neon_user:password@ep-XXXXX.us-east-2.aws.neon.tech/messenger_db?sslmode=require"

# You should see: messenger_db=#
```

## Local Development with Neon (Optional)

Update `docker-compose.yml` to use Neon instead of local Postgres:

```yaml
services:
  serverpod:
    # ... existing config
    environment:
      DATABASE_URL: postgresql://neon_user:password@ep-XXXXX.us-east-2.aws.neon.tech/messenger_db?sslmode=require
      DATABASE_SSL: true
    # Remove: depends_on: postgres
    # Remove: healthcheck for postgres
```

Then run only backend + frontend:
```bash
docker compose up serverpod mailhog
```

## Security Best Practices

1. **Never commit .env file** - use Render's secret management
2. **Rotate ENCRYPTION_MASTER_KEY** periodically
3. **Use strong SMTP passwords** (Gmail: use app-specific passwords)
4. **Enable Neon IP allowlist** in console (Rendering IPs are whitelisted by default)
5. **Monitor Neon usage** - set spending limits if needed

## Migration Path

If you later want to:
- **Switch from Neon to AWS RDS**: Just update DATABASE_URL
- **Scale to multiple regions**: Neon supports replication with enterprise plan
- **Move to managed PostgreSQL on cloud provider**: Same DATABASE_URL format

Neon makes it easy to switch!

## Next Steps

1. ✅ Create Neon account and project
2. ✅ Copy pooled connection string
3. ✅ Deploy backend with DATABASE_URL
4. ✅ Deploy frontend with BACKEND_URL
5. ✅ Test registration and login
6. ✅ Monitor Render and Neon dashboards

Good luck! 🚀
