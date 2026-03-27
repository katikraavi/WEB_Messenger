#!/bin/bash
# Pre-deployment commands to run locally

echo "📋 Pre-Deployment Checklist"
echo "==========================="
echo ""

# Step 1: Generate encryption key
echo "1️⃣  Generating encryption key..."
ENCRYPTION_KEY=$(openssl rand -hex 32)
echo "Save this:"
echo "ENCRYPTION_MASTER_KEY=$ENCRYPTION_KEY"
echo ""

# Step 2: Verify web build exists
echo "2️⃣  Checking Flutter web build..."
if [ -f "frontend/build/web/index.html" ]; then
    echo "✅ Web build found"
    SIZE=$(du -sh frontend/build/web/ | cut -f1)
    echo "   Size: $SIZE"
else
    echo "❌ Web build not found - run: flutter build web --release"
    exit 1
fi
echo ""

# Step 3: Check git status
echo "3️⃣  Checking Git status..."
if [ -d ".git" ]; then
    echo "✅ Git repository exists"
    BRANCH=$(git branch --show-current)
    echo "   Current branch: $branch"
    echo "   Uncommitted changes:"
    git status --short
else
    echo "❌ Not a Git repository - run: git init && git add . && git commit -m 'Initial'"
    exit 1
fi
echo ""

# Step 4: TODO - User needs to fill in Neon connection string
echo "4️⃣  Next Steps:"
echo ""
echo "   a) Go to https://console.neon.tech"
echo "   b) Create new project 'messenger'"
echo "   c) Copy Pooled Connection string"
echo "   d) Save this in NEON_CONNECTION.txt"
echo ""
echo "5️⃣  Then follow DEPLOYMENT_CHECKLIST.md for Render deployment"
echo ""

# Step 5: Show example env vars
echo "📝 Example Environment Variables (save for Render):"
echo ""
echo "SERVERPOD_ENV=production"
echo "SERVERPOD_PORT=8081"
echo "DATABASE_URL=postgresql://neon_user:PASSWORD@ep-XXXXX.us-east-2.aws.neon.tech/messenger_db?sslmode=require"
echo "DATABASE_SSL=true"
echo "ENCRYPTION_MASTER_KEY=$ENCRYPTION_KEY"
echo "SMTP_HOST=smtp.gmail.com"
echo "SMTP_PORT=587"
echo "SMTP_FROM_EMAIL=noreply@yourdomain.com"
echo "SMTP_FROM_NAME=Mobile Messenger"
echo "SMTP_USER=your-email@gmail.com"
echo "SMTP_PASSWORD=your-app-password"
echo "SMTP_SECURE=true"
echo "APP_BASE_URL=https://messenger-backend-XXXXX.onrender.com"
echo ""

# Step 6: Default values check
echo "✅ System check complete!"
echo ""
echo "Ready for deployment? Follow: DEPLOYMENT_CHECKLIST.md"
