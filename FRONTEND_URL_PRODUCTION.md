# Important: FRONTEND_URL for Production

## The Issue

When you deploy to Render, **add this environment variable to your BACKEND service**:

```
FRONTEND_URL=https://messenger-frontend-XXXX.onrender.com
```

Replace `XXXX` with your actual Render frontend subdomain.

## Why It Matters

The backend uses `FRONTEND_URL` to build **verification links in emails**. 

When a user registers:
1. Backend receives signup request
2. Generates verification token
3. Builds email link: `$FRONTEND_URL/verify?token=ABC123`
4. Sends email to user
5. User clicks link to verify email

**If `FRONTEND_URL` is wrong, verification links will break!**

## Current Code

**File**: `backend/lib/src/server/auth_handlers.dart` (line 125)

```dart
final appBaseUrl = Platform.environment['FRONTEND_URL'] ?? 'http://localhost:5000';
final verificationLink = '$appBaseUrl/verify?token=$token';
```

## Also Used In

- Email verification links
- Password reset links
- Any redirect-to-frontend operations

## Deployment Order

1. **Deploy Frontend FIRST** to Render
   - Get the frontend subdomain: `https://messenger-frontend-XXXX.onrender.com`

2. **Deploy Backend SECOND** with:
   ```
   FRONTEND_URL=https://messenger-frontend-XXXX.onrender.com
   ```

3. **Now emails work!** ✅

## Complete Backend Environment Variables

```
SERVERPOD_ENV=production
SERVERPOD_PORT=8081
DATABASE_URL=postgresql://neondb_owner:PASSWORD@ep-XXXXX.aws.neon.tech/neondb?sslmode=require
DATABASE_SSL=true
ENCRYPTION_MASTER_KEY=<your-64-char-hex>
FRONTEND_URL=https://messenger-frontend-XXXX.onrender.com
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_FROM_EMAIL=your-email@gmail.com
SMTP_FROM_NAME=Mobile Messenger
SMTP_USER=your-email@gmail.com
SMTP_PASSWORD=your-app-password
SMTP_SECURE=true
APP_BASE_URL=https://messenger-backend-YYYY.onrender.com
```

Replace:
- `PASSWORD` - Neon password
- `XXXXX` - Neon endpoint ID
- `XXXX` - Render frontend subdomain
- `YYYY` - Render backend subdomain (auto-generated)

## Testing

After deployment:
1. Go to frontend: `https://messenger-frontend-XXXX.onrender.com`
2. Click "Sign Up"
3. Enter email address
4. Check email - should have verification link to the frontend URL
5. Click link - should verify successfully

If verification link goes to `localhost:5000`, then `FRONTEND_URL` wasn't set correctly!
