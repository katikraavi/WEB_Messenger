# Render Deployment Guide

This guide walks you through deploying your Mobile Messenger to Render.com.

## Prerequisites

- ✅ GitHub repository (public or connected to Render)
- ✅ Render account (free tier or paid)
- ✅ PostgreSQL database (use Neon via Render or external managed DB)
- ✅ Environment variables configured

## Deployment Architecture

```
┌─────────────────────────────────────────────┐
│         Render.com CDN / Load Balancer      │
├────────────────┬───────────────┬────────────┤
│  Web Frontend   │  Backend API  │   Static  │
│  (Next.js or   │  (Serverpod)  │   Assets  │
│   Static Site) │               │           │
└────────────────┴───────────────┴────────────┘
         │                 │
         └─────────────────┴──────────────┐
                                          │
                    ┌─────────────────────▼──────────────┐
                    │  PostgreSQL (Neon or managed)      │
                    └────────────────────────────────────┘
```

## Step 1: Create GitHub Repository Setup

```bash
# If not already using GitHub:
cd /home/katikraavi/web-messenger
git init
git add .
git commit -m "Initial commit: Mobile Messenger setup"
git remote add origin https://github.com/YOUR_USERNAME/web-messenger.git
git branch -M main
git push -u origin main
```

Ensure `.gitignore` includes:
```
.env
.env.local
.dart_tool/
build/
.firebase/
firebase-debug.log
```

## Step 2: Set Up PostgreSQL on Render

### Option A: Use Render's Managed PostgreSQL (Recommended)

1. Go to [render.com](https://render.com) → Dashboard
2. Click **"New +"** → **"PostgreSQL"**
3. Fill in:
   - **Name**: `messenger-db`
   - **Database**: `messenger_db`
   - **User**: `messenger_user`
   - **Region**: Same as backend (e.g., `oregon`)
   - **PostgreSQL Version**: 13+
4. Click **Create**
5. Copy the **Internal Database URL** (looks like: `postgresql://user:pwd@localhost:5432/db`)

### Option B: Use Neon (External Managed PostgreSQL)

1. Sign up at [neon.tech](https://neon.tech)
2. Create a project and copy the pooled connection string
3. Set `DATABASE_SSL=true` in environment variables
4. Connection string: `postgresql://user:password@host/database?sslmode=require`

## Step 3: Deploy Backend to Render

### 3.1 Create Web Service for Backend

1. Go to **Dashboard** → Click **"New +"** → **"Web Service"**
2. Connect your GitHub repository
3. Configure:
   - **Name**: `messenger-backend`
   - **Environment**: `Docker`
   - **Build Command**: (leave default - uses Dockerfile)
   - **Start Command**: (leave default - uses CMD from Dockerfile)
   - **Instance Type**: Standard (free tier) or higher

### 3.2 Set Environment Variables

In Render dashboard for backend service:

```
SERVERPOD_ENV=production
SERVERPOD_PORT=8081
DATABASE_URL=<from Step 2>
DATABASE_SSL=true
ENCRYPTION_MASTER_KEY=<generate random 64-char hex>
SMTP_HOST=<your email provider>
SMTP_PORT=587
SMTP_FROM_EMAIL=noreply@yourdomain.com
SMTP_FROM_NAME=Mobile Messenger
SMTP_USER=<email api key>
SMTP_PASSWORD=<email api secret>
SMTP_SECURE=true
APP_BASE_URL=https://messenger-backend-xxxx.onrender.com
```

### 3.3 Deploy

Click **"Deploy"** and wait for completion (usually 3-5 minutes).

Your backend URL will be: `https://messenger-backend-xxxx.onrender.com`

## Step 4: Build Frontend Web

Build Flutter web production version locally first:

```bash
cd frontend
flutter build web --release --dart-define=BACKEND_URL=https://messenger-backend-xxxx.onrender.com

# Output will be in: frontend/build/web/
```

## Step 5: Deploy Frontend to Render

### Option A: As Static Site (Easiest)

1. Go to **Dashboard** → Click **"New +"** → **"Static Site"**
2. Connect your GitHub repository
3. Configure:
   - **Name**: `messenger-frontend`
   - **Build Command**: `cd frontend && flutter build web --release`
   - **Publish Directory**: `frontend/build/web`
4. Set environment variable:
   ```
   BACKEND_URL=https://messenger-backend-xxxx.onrender.com
   ```
5. Click **"Create Static Site"**

**Note**: Static site doesn't execute build commands. Instead, you need to:
- Generate `frontend/build/web` locally
- Commit to git
- Render will serve pre-built files

### Option B: As Web Service with Node.js Server (Better for API routing)

Create `frontend/server.js`:

```javascript
const express = require('express');
const path = require('path');
const app = express();

app.use(express.static(path.join(__dirname, 'build/web')));

app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'build/web', 'index.html'));
});

app.listen(3000, () => {
  console.log('Frontend server running on port 3000');
});
```

Create `frontend/package.json`:

```json
{
  "name": "messenger-frontend",
  "version": "1.0.0",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "express": "^4.18.2"
  }
}
```

Then deploy as web service with:
- **Build Command**: `cd frontend && flutter build web --release && cd .. && npm install`
- **Start Command**: `cd frontend && npm start`

## Step 6: Update API URLs

Update frontend API base URL to point to Render backend:

**File**: `frontend/lib/core/services/api_client.dart`

```dart
// Change from:
const String baseUrl = 'http://172.20.0.3:8081';

// To:
const String baseUrl = 'https://messenger-backend-xxxx.onrender.com';
```

Update in all service files:
- `auth_service.dart`
- `email_verification_service.dart`
- `password_recovery_service.dart`
- `profile_service.dart`
- `chat_api_service.dart`
- etc.

## Step 7: Database Migrations & Seeding

After backend deployment:

```bash
# SSH into Render backend container via Render dashboard shell, then:
cd /app
dart run server
# Migrations should run automatically on startup

# Or manually trigger if needed
dart bin/server.dart --migrate
```

## Step 8: Test Deployment

1. **Frontend URL**: `https://messenger-frontend-xxxx.onrender.com`
2. **Backend API**: `https://messenger-backend-xxxx.onrender.com/api/health`
3. **Register new account** and verify email works
4. **Login and test chat** functionality

## Step 9: Custom Domain (Optional)

1. In Render dashboard, go to service settings
2. Add custom domain (e.g., `messenger.yourdomain.com`)
3. Update DNS records as shown by Render
4. Update `APP_BASE_URL` environment variable

## Troubleshooting

### Issue: "Backend not responding"
- Check `APP_BASE_URL` is accessible
- Verify `ENCRYPTION_MASTER_KEY` matches across services
- Check Render logs: **Settings** → **Logs**

### Issue: "Database connection failed"
- Verify `DATABASE_URL` is correct
- Check `DATABASE_SSL=true` if using Neon
- Test connection: `psql <DATABASE_URL>`

### Issue: "Email not sending"
- Verify SMTP credentials
- Check email service provider's API limits
- Test with different provider (SendGrid, Mailgun)

### Issue: "Frontend not loading"
- Check `build/web` directory exists
- Verify JavaScript is enabled
- Check browser console for CORS errors
- Update API URL in frontend code

## Environment Variables Checklist

```
✅ SERVERPOD_ENV=production
✅ SERVERPOD_PORT=8081
✅ DATABASE_URL=postgresql://...
✅ DATABASE_SSL=true (if Neon)
✅ ENCRYPTION_MASTER_KEY=<64-char-hex>
✅ SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASSWORD
✅ APP_BASE_URL=<backend-URL>
✅ BACKEND_URL=<backend-URL> (frontend env)
```

## Post-Deployment Monitoring

1. **Enable Render alerts** for:
   - Memory usage > 80%
   - CPU usage > 80%
   - Error rate > 5%

2. **Monitor logs** regularly:
   ```
   Render Dashboard → Service → Logs
   ```

3. **Set up metrics** (in Render dashboard):
   - Request count
   - Response time
   - Error rate

## Scaling (When Needed)

- **Free tier**: Works for small projects (~100 concurrent users)
- **Paid services**: Upgrade to Pro/Team for better performance
- **Database**: Scale up PostgreSQL resources if needed
- **Multi-region**: Use multiple backend instances behind load balancer

## Cost Estimates (Monthly)

| Service | Free | Pro | Premium |
|---------|------|-----|---------|
| Backend | $0 (paused) | $7 | $25+ |
| Frontend | $0 | $0 | $0 |
| PostgreSQL | $0 (managed) | $15-30 | $50+ |
| **Total** | **~$0-15** | **~$22-37** | **$50+** |

## Next Steps

1. ✅ Create GitHub repo
2. ✅ Set up PostgreSQL (Render or Neon)
3. ✅ Deploy backend web service
4. ✅ Configure environment variables
5. ✅ Build and deploy frontend
6. ✅ Update API URLs
7. ✅ Test registration & login
8. ✅ Monitor logs & metrics
9. ✅ Add custom domain
10. ✅ Set up auto-scaling

Good luck! 🚀
