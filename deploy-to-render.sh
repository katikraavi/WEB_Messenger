#!/bin/bash
# Deploy Mobile Messenger to Render.com
# This script guides you through the deployment process

set -e

echo "🚀 Mobile Messenger - Render Deployment Guide"
echo "==========================================="
echo ""

# Step 1: GitHub Setup
echo "📝 Step 1: GitHub Repository Setup"
echo "=================================="
echo ""
echo "If you haven't already pushed to GitHub:"
echo ""
echo "   cd /home/katikraavi/web-messenger"
echo "   git init"
echo "   git add ."
echo "   git commit -m 'Initial commit: Mobile Messenger'"
echo "   git branch -M main"
echo "   git remote add origin https://github.com/YOUR_USERNAME/web-messenger.git"
echo "   git push -u origin main"
echo ""
echo "✅ Once pushed, continue to Step 2 (press Enter)"
read

# Step 2: Environment Variables
echo ""
echo "🔐 Step 2: Generate Environment Variables"
echo "========================================="
echo ""
echo "Generate a random 64-character encryption key:"
ENCRYPTION_KEY=$(openssl rand -hex 32)
echo "ENCRYPTION_MASTER_KEY=$ENCRYPTION_KEY"
echo ""
echo "Save these for later:"
echo "  - Database connection string"
echo "  - SMTP credentials"
echo "  - Backend URL (will be given by Render)"
echo ""
echo "✅ Continue to Step 3 (press Enter)"
read

# Step 3: Render Login
echo ""
echo "🌐 Step 3: Create Render Account"
echo "================================"
echo ""
echo "📌 Go to https://render.com and sign up/login"
echo ""
echo "✅ Once logged in, continue to Step 4 (press Enter)"
read

# Step 4: Create PostgreSQL
echo ""
echo "🗄️  Step 4: Create PostgreSQL Database"
echo "====================================="
echo ""
echo "1. Click 'New +' → 'PostgreSQL'"
echo "2. Fill in:"
echo "   • Name: messenger-db"
echo "   • Database: messenger_db"
echo "   • User: messenger_user"
echo "   • Region: oregon (or your preferred region)"
echo "3. Click 'Create Database'"
echo "4. Copy the 'Internal Database URL' after it's created"
echo ""
echo "✅ Continue to Step 5 (press Enter)"
read

echo "Paste the Internal Database URL:"
read DATABASE_URL

# Step 5: Deploy Backend
echo ""
echo "🔧 Step 5: Deploy Backend Service"
echo "=================================="
echo ""
echo "1. Click 'New +' → 'Web Service'"
echo "2. Connect your GitHub repository"
echo "3. Configuration:"
echo "   • Name: messenger-backend"
echo "   • Environment: Docker"
echo "   • Build Command: (leave default)"
echo "   • Start Command: (leave default)"
echo "4. Click 'Create Web Service'"
echo ""
echo "5. Go to 'Environment' tab and add variables:"
echo ""
echo "SERVERPOD_ENV=production"
echo "SERVERPOD_PORT=8081"
echo "DATABASE_URL=$DATABASE_URL"
echo "DATABASE_SSL=true"
echo "ENCRYPTION_MASTER_KEY=$ENCRYPTION_KEY"
echo "SMTP_HOST=smtp.gmail.com (or your provider)"
echo "SMTP_PORT=587"
echo "SMTP_FROM_EMAIL=noreply@yourdomain.com"
echo "SMTP_FROM_NAME=Mobile Messenger"
echo "SMTP_USER=your-email@gmail.com"
echo "SMTP_PASSWORD=your-app-password"
echo "SMTP_SECURE=true"
echo ""
echo "6. Render will automatically deploy"
echo ""
echo "Once deployment completes, copy the backend URL:"
echo "It will look like: https://messenger-backend-xxxx.onrender.com"
echo ""
echo "Paste backend URL:"
read BACKEND_URL

# Step 6: Deploy Frontend
echo ""
echo "🎨 Step 6: Deploy Frontend"
echo "=========================="
echo ""
echo "Option 1: Static Site (Easiest)"
echo "  1. Click 'New +' → 'Static Site'"
echo "  2. Connect GitHub repo"
echo "  3. Build Command: cd frontend && flutter build web --release"
echo "  4. Publish Directory: frontend/build/web"
echo "  5. Click 'Create Static Site'"
echo ""
echo "Option 2: Web Service (with Node.js)"
echo "  We've already created the files, just deploy as web service"
echo ""
echo "Choose deployment method (1 or 2):"
read FRONTEND_METHOD

# Step 7: Update API URLs
echo ""
echo "🔗 Step 7: Update Frontend API URLs"
echo "==================================="
echo ""
echo "We need to update your frontend to use: $BACKEND_URL"
echo ""

# Step 8: Git Push
echo "📤 Step 8: Commit and Push Changes"
echo "=================================="
echo ""
echo "Run these commands:"
echo ""
echo "  cd /home/katikraavi/web-messenger"
echo "  git add ."
echo "  git commit -m 'Update API URLs for Render deployment'"
echo "  git push origin main"
echo ""
echo "Then Render will automatically redeploy both services."
echo ""

echo "✅ Done!"
echo ""
echo "📊 Your application will be deployed at:"
echo "   Frontend: https://messenger-frontend-xxxx.onrender.com"
echo "   Backend:  $BACKEND_URL"
echo ""
