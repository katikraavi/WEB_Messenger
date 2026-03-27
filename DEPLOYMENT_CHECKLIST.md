# 🚀 Neon + Render Deployment Checklist

## ✅ Phase 1: Neon Setup (5 minutes)

### In your Chrome browser (Neon console):

- [ ] Project created: `messenger`
- [ ] Database name: `messenger_db`
- [ ] Region selected: `us-east-2` (or your preference)
- [ ] **Connection string copied** (Pooled Connection)
  - Format: `postgresql://neon_user:pwd@ep-XXXXX...`
  - Saved to: `NEON_CONNECTION.txt`

**✅ Done with Neon!**

---

## ✅ Phase 2: Prepare for Render (2 minutes)

### Local Setup:

```bash
cd /home/katikraavi/web-messenger

# 1. Generate encryption key
openssl rand -hex 32
# Copy output to ENCRYPTION_MASTER_KEY

# 2. Build web app (already done)
ls frontend/build/web/
# Should show: index.html, main.dart.js, etc.

# 3. Commit to GitHub
git add .
git commit -m "Ready for Render deployment"
git push origin main
```

---

## ✅ Phase 3: Deploy Backend to Render (5 minutes)

### Step 1: Open Render Dashboard
Go to: https://render.com/dashboard

### Step 2: Create Web Service
1. Click **"New +"** → **"Web Service"**
2. Connect your GitHub repository (`web-messenger`)
3. Fill in:
   - **Name**: `messenger-backend`
   - **Environment**: `Docker`
   - **Build Command**: `(use default)`
   - **Start Command**: `(use default)`
   - **Instance Type**: `Free` or `Standard`
4. Click **"Create Web Service"**

### Step 3: Add Environment Variables
In the Render dashboard:
1. Go to **"Environment"** tab
2. Click **"Add Environment Variable"**
3. Add these one by one:

```
SERVERPOD_ENV = production
SERVERPOD_PORT = 8081
DATABASE_URL = (from Neon - paste here!)
DATABASE_SSL = true
ENCRYPTION_MASTER_KEY = (from openssl command above)
SMTP_HOST = smtp.gmail.com
SMTP_PORT = 587
SMTP_FROM_EMAIL = noreply@yourdomain.com
SMTP_FROM_NAME = Mobile Messenger
SMTP_USER = your-email@gmail.com
SMTP_PASSWORD = (Gmail app password)
SMTP_SECURE = true
APP_BASE_URL = (Render will give you this URL after first deploy)
```

### Step 4: Deploy
1. Scroll down, click **"Deploy"**
2. Wait 3-5 minutes for deployment
3. Once done, copy your backend URL
   - Format: `https://messenger-backend-XXXXX.onrender.com`
   - Save this!

### Step 5: Update DATABASE_URLS
1. Go back to Environment variables
2. Update `APP_BASE_URL = https://messenger-backend-XXXXX.onrender.com`
3. Render will auto-redeploy

**✅ Backend deployed!**

---

## ✅ Phase 4: Deploy Frontend to Render (5 minutes)

### Option A: Static Site (Simplest)

1. In Render dashboard: **"New +"** → **"Static Site"**
2. Connect your GitHub repository
3. Fill in:
   - **Name**: `messenger-frontend`
   - **Build Command**: 
     ```
     cd frontend && flutter build web --release
     ```
   - **Publish Directory**: `frontend/build/web`
4. Set Environment Variable:
   ```
   BACKEND_URL = https://messenger-backend-XXXXX.onrender.com
   ```
5. Click **"Create Static Site"**
6. Wait for deployment (~5 minutes)

**Frontend URL**: `https://messenger-frontend-XXXXX.onrender.com`

### Option B: Web Service (if Static Site has issues)

Same as backend but:
- **Build Command**: `cd frontend && flutter build web --release && cd .. && npm install --prefix frontend`
- **Start Command**: `cd frontend && npm start`
- **Publish Directory**: (leave empty)

---

## ✅ Phase 5: Test Deployment (3 minutes)

### Test Backend Health
Open in browser:
```
https://messenger-backend-XXXXX.onrender.com/health
```
Should return: `{"status":"healthy"}`

### Test Frontend
Open in browser:
```
https://messenger-frontend-XXXXX.onrender.com
```
Should load your app!

### Test Registration
1. Click "Sign Up"
2. Enter email (e.g., `test@example.com`)
3. Create password
4. Should receive verification email
5. Verify and log in

---

## ✅ Phase 6: Monitoring & Maintenance

### Check Backend Logs
- Render Dashboard → `messenger-backend` → **Logs**
- Look for errors like:
  - ❌ `Database connection refused` → check DATABASE_URL
  - ❌ `SMTP connection failed` → check SMTP settings
  - ✅ `Server started` → all good!

### Check Database
```bash
# From your local machine:
psql "postgresql://neon_user:pwd@ep-XXXXX.us-east-2.aws.neon.tech/messenger_db?sslmode=require"

# You should see: messenger_db=#
# Then list tables:
\dt
```

### Monitor Neon Usage
- Go to https://console.neon.tech
- Check compute units used
- Free tier: 3,000 compute units/month (plenty!)

---

## 🎯 Final URLs

Once deployed:
- **Frontend**: `https://messenger-frontend-XXXXX.onrender.com`
- **Backend**: `https://messenger-backend-XXXXX.onrender.com`
- **Database**: Neon managed (no public URL needed)

---

## 🆘 Troubleshooting

| Problem | Solution |
|---------|----------|
| "Bad gateway" error | Wait 5 mins for Render to deploy, then refresh |
| Backend won't start | Check DATABASE_URL in Neon console, verify SSL settings |
| Can't send email | Verify Gmail app password (not account password) |
| Database connection refused | Add `?sslmode=require` to end of DATABASE_URL |
| Frontend shows blank page | Check browser console (F12) for CORS errors |
| API is running but frontend can't reach it | Update BACKEND_URL in environment variables |

---

## 📊 Costs (Monthly)

| Service | Free | Pro |
|---------|------|-----|
| Render Backend | $0 (sleeps) | $7 |
| Render Frontend | $0 | $0 |
| Neon Database | Free | $15 |
| **Total** | **~$0-15** | **~$22** |

---

## Ready? 🚀

1. ✅ Neon project created & connection string saved
2. ✅ GitHub repo ready
3. Start from **Phase 3: Deploy Backend** above!

Questions? Check the logs in Render dashboard or Neon console!
