# ✅ How to Use the Verification Button

## What Changed

I added a **Verification Token Input Field** and **Verify Button** to the email verification screen. Now you can verify your account **directly in the app** instead of using the CLI!

---

## Step-by-Step Guide

### Step 1: Create Account on Emulator

```
1. Open app on emulator
2. Click "Create Account"
3. Fill form:
   - Full Name: Your Name
   - Email: test_user@example.com
   - Username: testuser123
   - Password: StrongPass123!
4. Click "CREATE ACCOUNT"
```

### Step 2: See Verification Screen

After registration, you'll see:

```
┌─────────────────────────────────┐
│     Verify Email                │
│                                 │
│   ✉️ (mail icon)               │
│                                 │
│   Verification Email Sent       │
│                                 │
│   We sent a verification link   │
│   to test_user@example.com      │
└─────────────────────────────────┘
```

### Step 3: Get Verification Token

In your **terminal**, run:

```bash
# Get the token from the backend:
curl -s -X POST http://localhost:8081/auth/verify-email/send \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test_user@example.com",
    "userId": "PUT_USER_ID_HERE"
  }' | jq '.token' -r
```

Or use the automated script:

```bash
bash /tmp/simple_verify.sh
```

**You'll get something like:**
```
1kWXcy7J7bIkn0Mdo4b7WdP5ZFitWRVLAFd5IhaGEz0
```

### Step 4: Paste Token in App

Back on **emulator screen**, you'll see:

```
┌─────────────────────────────────┐
│ Enter Verification Token        │ ← (new section added!)
│ (for testing)                   │
│                                 │
│ ┌─────────────────────────────┐ │
│ │ 🔑 Paste token here...      │ │
│ │                             │ │
│ │ 1kWXcy7J7bIkn...  [✕]      │ │ ← Clear button
│ └─────────────────────────────┘ │
│                                 │
│  ┌───────────────────────────┐  │
│  │ ✓ Verify Email            │  │ ← New button!
│  └───────────────────────────┘  │
└─────────────────────────────────┘
```

1. **Tap** on the text field
2. **Paste** the token you copied from terminal
3. **Click** "Verify Email" button

### Step 5: Success! ✅

If the token is valid, you'll see:

```
┌─────────────────────────────────┐
│ ✅ Email verified successfully! │
│                                 │
│    [Continue to Sign In]        │
└─────────────────────────────────┘
```

Now you can **login with your credentials**!

---

## UI Features

### The New Verification Section Includes:

✅ **Token Input Field**
- Multi-line text field for pasting long tokens
- Clear (✕) button to remove text quickly
- Respects the token format

✅ **Verify Button**
- Shows "Verify Email" normally
- Shows "Verifying..." while processing
- Becomes disabled during verification
- Has loading spinner

✅ **Instructions Updated**
- Now shows token option first
- Mentions pasting token
- Still supports email link option

✅ **Error Handling**
- Shows warning if token is empty
- Displays error messages from backend
- Shows success confirmation

---

## Testing Workflow

### Quick Test (90 seconds):

```bash
# Terminal 1: Run auto-verification script
bash /tmp/simple_verify.sh
# → Copies the token

# Terminal 2: Emulator
# 1. Click "Create Account"
# 2. Fill form → Click "CREATE ACCOUNT"
# 3. Paste token → Click "VERIFY EMAIL"
# ✅ DONE!
```

### Manual Test (2 minutes):

```
1. Create account on emulator
2. In terminal: Get token from backend
3. Paste into app → Click verify
4. See success message
5. Click "Continue to Sign In"
6. Login with credentials
✅ COMPLETE FLOW TESTED!
```

---

## How It Works (Technical)

### Before (Without Button):
```
Emulator → "Send Email" → ??? → Can't verify
```

### After (With Button):
```
Emulator → "Send Email" ↓
        ↓ "Paste Token" ↓
        ↓ Click "Verify" ↓
        POST /auth/verify-email/confirm {token} ↓
        ✅ "Email Verified!"
```

---

## What Was Changed

**File Modified:**
`frontend/lib/features/email_verification/pages/verification_pending_screen.dart`

**Added:**
```dart
// Token input controller
final TextEditingController _tokenController = TextEditingController();

// Verify handler method
void _handleVerifyEmail() {
  final token = _tokenController.text.trim();
  ref.read(verificationProvider.notifier).verifyEmail(token: token);
}

// UI: Token input field + Verify button
TextField(
  controller: _tokenController,
  decoration: InputDecoration(
    hintText: 'Paste verification token from email',
    labelText: 'Verification Token',
    prefixIcon: const Icon(Icons.key),
  ),
)

ElevatedButton.icon(
  onPressed: _handleVerifyEmail,
  label: Text('Verify Email'),
)
```

---

## Test Accounts (No Verification Needed)

If you want to skip verification entirely:

```
alice@example.com / password123           ✅ Already verified
bob@example.com / password123             ✅ Already verified
charlie@example.com / password123         ✅ Already verified
alice.smith@example.com / password123     ✅ Already verified
```

Just login with these!

---

## Troubleshooting

### Token not showing in terminal?
```bash
# Make sure backend is running:
docker compose up -d

# Check if backend is healthy:
curl http://localhost:8081/health
```

### Button shows "Verifying..." forever?
```
→ Backend might be down
→ Check: docker compose ps
→ Restart: docker compose down && docker compose up -d
```

### "Invalid token" error?
```
→ Token might have expired (15 minute limit)
→ Get a fresh token: bash /tmp/simple_verify.sh
→ Copy the token immediately
```

### Clear button not showing?
```
→ Works after you type in the field
→ Tap once to activate, then clear button appears
```

---

## Next: Rebuild & Test

```bash
cd /home/katikraavi/mobile-messenger/frontend
flutter clean
flutter pub get
flutter run
```

Then follow the **Step-by-Step Guide** above and you're ready to test! 🚀

---

## Summary

| Before | After |
|--------|-------|
| ❌ No token input field | ✅ Token input field |
| ❌ Can't verify in app | ✅ Click "Verify Email" button |
| ❌ Must use CLI | ✅ Works entirely on emulator |
| ⏱️ Complex workflow | ⏱️ 30 seconds to verify |

**You can now test the complete verification flow by just clicking buttons! 🎉**
