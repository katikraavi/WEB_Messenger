# Complete User Journey - Registration, Verification, and Sign In

## User Story Flow: Create Account → Verify Email → Sign In → Resend Verification

---

## 🎯 STEP 1: User Registration

### User Action
- Opens app
- Clicks "Create Account" button
- Fills in form:
  - Email: `newuser@example.com`
  - Username: `newuser2026`
  - Password: `SecurePass123!`
  - Full Name: `John Newbie`

### Backend Request
```http
POST /auth/register
Content-Type: application/json

{
  "email": "newuser@example.com",
  "username": "newuser2026",
  "password": "SecurePass123!",
  "full_name": "John Newbie"
}
```

### Backend Response
```json
HTTP/1.1 201 Created
{
  "user_id": "user-abc123def456",
  "email": "newuser@example.com",
  "username": "newuser2026",
  "message": "Account created successfully"
}
```

### UI Response
- ✅ Success message: "Account created successfully!"
- ✅ Button to proceed: "Send Verification Email"
- ✅ Option to go back: "Already have an account? Sign In"

### What Happens Behind Scenes
- User stored in auth database
- Account created with `verified_at = NULL` (not yet verified)
- User can now proceed to email verification OR try to login (but login will fail until verified in production)

---

## 🎯 STEP 2: Email Verification - Send Verification Email

### User Action
- Clicks "Send Verification Email" button
- App displays: "Verification email sent to newuser@example.com"
- User goes to email to find verification link

### Backend Request
```http
POST /auth/verify-email/send
Content-Type: application/json
Authorization: Bearer {JWT_TOKEN_FROM_REGISTRATION}

{
  "email": "newuser@example.com"
}
```

### Backend Response
```json
HTTP/1.1 200 OK
{
  "message": "Verification email sent",
  "email": "newuser@example.com",
  "expires_in_minutes": 15
}
```

### Email Content Received
```
Subject: Verify Your Email - Mobile Messenger

Hi John,

Please verify your email by clicking the link below or entering the code:

CODE: 123456
or
LINK: https://messenger.app/verify?token=eyJhbGc...

This code expires in 15 minutes.

Best regards,
Mobile Messenger Team
```

### UI Response
- ✅ Message: "Check your email for verification link"
- ✅ Input field: "Enter 6-digit code from email"
- ✅ Resend button: "Didn't receive email? Resend" (appears after 2 minutes)
- ✅ Timer showing: "Resend in 00:02:15"

---

## 🎯 STEP 3: Verify Email - Enter Code

### User Action
- User checks email and finds verification code: `123456`
- Returns to app
- Enters code in input field
- Clicks "Verify Email" button

### Backend Request
```http
POST /auth/verify-email/confirm
Content-Type: application/json

{
  "email": "newuser@example.com",
  "code": "123456"
}
```

### Backend Response (Success)
```json
HTTP/1.1 200 OK
{
  "message": "Email verified successfully",
  "email": "newuser@example.com",
  "verified_at": "2026-03-12T20:35:22.123Z"
}
```

### Backend Response (Failed - Wrong Code)
```json
HTTP/1.1 400 Bad Request
{
  "error": "Invalid verification code",
  "details": ["Code is expired or incorrect"]
}
```

### UI Response (Success)
- ✅ Green checkmark: "Email verified!"
- ✅ Success message: "Your email has been verified successfully"
- ✅ Button: "Continue to Sign In"
- ✅ Auto-redirect after 2 seconds to login screen

### Backend Database Update
```sql
-- User record updated:
UPDATE users 
SET verified_at = NOW() 
WHERE email = 'newuser@example.com'
```

---

## 🎯 STEP 4: Sign In

### User Action
- App shows login screen (or user navigates there)
- Enters credentials:
  - Email: `newuser@example.com`
  - Password: `SecurePass123!`
- Clicks "Sign In" button

### Backend Request
```http
POST /auth/login
Content-Type: application/json

{
  "email": "newuser@example.com",
  "password": "SecurePass123!"
}
```

### Backend Response (Success)
```json
HTTP/1.1 200 OK
{
  "user_id": "user-abc123def456",
  "email": "newuser@example.com",
  "username": "newuser2026",
  "token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

### Backend Response (Failed - Not Verified)
```json
HTTP/1.1 401 Unauthorized
{
  "error": "Email not verified",
  "details": ["Please verify your email before logging in"]
}
```

### UI Response (Success)
- ✅ Loading spinner: "Signing you in..."
- ✅ After 2-3 seconds: Auto-redirect to Home screen
- ✅ Welcome message: "Welcome back, John!"
- ✅ Visible features:
  - Search Users button (blue gradient)
  - Floating action button (search icon)
  - Test users display (alice, bob, charlie, diane)
  - Logout button

### What Happens Behind Scenes
- Token stored in secure storage
- User session created
- Provider state updated with user info
- Home screen loaded with authenticated state

---

## 🎯 STEP 5: User Can Now Use App

### Available Actions
1. ✅ **Search Users** - Search for other users by username/email
2. ✅ **View Profile** - View own profile
3. ✅ **Edit Profile** - Update profile info
4. ✅ **Logout** - End session

### Example: Search for Another User
- User clicks "Search Users" button
- Navigates to search screen
- Searches for "alice"
- Results appear showing found users
- User can tap on result to view profile

---

## 🎯 STEP 6 (ALTERNATIVE): Resend Verification Email

### Scenario
User didn't receive verification email or code expired

### User Action (Option A - From Verification Screen)
- User on verification code entry screen
- Clicks "Didn't receive email? Resend"
- (Timer was showing: "Resend in 00:01:45")
- Resend button now enabled

### User Action (Option B - From Login Screen)
- User tries to login
- Gets error: "Email not verified"
- Sees option: "Resend verification email"
- Clicks the link/button

### Backend Request
```http
POST /auth/verify-email/send (Resend)
Content-Type: application/json

{
  "email": "newuser@example.com"
}
```

### Backend Response
```json
HTTP/1.1 200 OK
{
  "message": "Verification email resent",
  "email": "newuser@example.com",
  "expires_in_minutes": 15
}
```

### UI Response
- ✅ Toast/Snackbar: "Verification email sent to newuser@example.com"
- ✅ Timer restarts: "Resend in 00:15:00"
- ✅ New email received with new code (or same code if not expired)

### User Returns to Email
- Checks email for new verification code
- Returns to app
- Enters new code
- Clicks "Verify Email"
- Process completes (same as Step 3)

---

## ❌ STEP 7: Error Scenarios Handled

### Scenario 1: Duplicate Email During Registration
```http
POST /auth/register
{
  "email": "existing@example.com",
  "username": "newuser",
  "password": "SecurePass123!"
}
```

**Response**:
```json
HTTP/1.1 409 Conflict
{
  "error": "Email already registered"
}
```

**UI Shows**:
- ❌ Error message: "Email already registered"
- ✅ Link: "Already have account? Sign In"
- ✅ Link: "Forgot Password?"

---

### Scenario 2: Login Before Email Verified
```http
POST /auth/login
{
  "email": "newuser@example.com",
  "password": "SecurePass123!"
}
```

**Response** (in development mode - allows login):
```json
HTTP/1.1 200 OK
{
  "user_id": "user-abc123def456",
  "email": "newuser@example.com",
  "username": "newuser2026",
  "token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**UI Shows**:
- ✅ Login succeeds (in dev/mock mode)
- ⚠️ Banner: "Please verify your email to unlock all features"
- ✅ User can still browse but some features restricted

---

### Scenario 3: Invalid Verification Code
```http
POST /auth/verify-email/confirm
{
  "email": "newuser@example.com",
  "code": "999999"
}
```

**Response**:
```json
HTTP/1.1 400 Bad Request
{
  "error": "Invalid verification code",
  "details": ["Code is expired or incorrect"]
}
```

**UI Shows**:
- ❌ Error: "Invalid code. Please try again."
- ✅ Button: "Resend Code"
- ✅ Input cleared, focused for retry

---

### Scenario 4: Verification Code Expired
User waits longer than 15 minutes to enter code

```http
POST /auth/verify-email/confirm
{
  "email": "newuser@example.com",
  "code": "123456"
}
```

**Response**:
```json
HTTP/1.1 400 Bad Request
{
  "error": "Verification code expired",
  "details": ["Code expired. Please request a new one."]
}
```

**UI Shows**:
- ❌ Error: "Code expired. Request a new one."
- ✅ Automatic redirect to resend screen
- ✅ New verification email button ready

---

## 📊 Complete User Journey Timeline

```
┌─────────────────────────────────────────────────────────────────┐
│                    USER JOURNEY TIMELINE                         │
├─────────────────────────────────────────────────────────────────┤
│ T+0:00   User starts app                                        │
│ T+0:10   Clicks "Create Account"                                │
│ T+0:15   Fills registration form                                │
│ T+0:20   Clicks "Register" → API call                           │
│ T+0:21   ✅ Response: Account created (HTTP 201)                │
│          Screen: "Send Verification Email"                      │
│                                                                  │
│ T+0:25   Clicks "Send Verification Email"                       │
│ T+0:26   ✅ Response: Email sent (HTTP 200)                     │
│          Email: Code 123456 received                            │
│                                                                  │
│ T+0:35   User checks email, gets code                           │
│ T+0:40   Returns to app, enters code "123456"                   │
│ T+0:42   Clicks "Verify Email" → API call                       │
│ T+0:43   ✅ Response: Verified (HTTP 200)                       │
│          Screen auto-redirects to login                         │
│                                                                  │
│ T+0:50   User on login screen                                   │
│ T+0:55   Enters email & password                                │
│ T+1:00   Clicks "Sign In" → API call                            │
│ T+1:01   ✅ Response: Token received (HTTP 200)                 │
│          Screen auto-redirects to Home                          │
│                                                                  │
│ T+1:05   ✅ HOME SCREEN: User fully authenticated               │
│          - Welcome message displayed                            │
│          - Can search for users                                 │
│          - Can view/edit profile                                │
│          - Can logout                                           │
│                                                                  │
│ TOTAL TIME: ~1 minute 5 seconds                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📱 UI Screens Flow Diagram

```
┌─────────────────┐
│   Start App     │
│   Login Screen  │
└────────┬────────┘
         │
         ├─ "Create Account" clicked
         │         ▼
         │  ┌──────────────────┐
         │  │  Registration    │
         │  │  Form Screen     │
         │  └────────┬─────────┘
         │           │
         │           ├─ Invalid input
         │           │  ▼
         │           │ Error message
         │           │ (retry)
         │           │
         │           ├─ Valid submission
         │           │  ▼
         │           │ API: /auth/register
         │           │  ▼
         │           │ ✅ Success (201)
         │           │  ▼
         │  ┌────────────────────────┐
         │  │ Email Verification     │
         │  │ "Send Email" Screen    │
         │  └────────┬───────────────┘
         │           │
         │           ├─ "Send" clicked
         │           │  ▼
         │           │ API: /auth/verify-email/send
         │           │  ▼
         │           │ ✅ Success (200)
         │           │  ▼
         │  ┌────────────────────────┐
         │  │ Code Entry Screen      │
         │  │ "Enter 6-digit code"   │
         │  └────────┬───────────────┘
         │           │
         │           ├─ User checks email
         │           ├─ Gets code (e.g., 123456)
         │           ├─ Enters code
         │           │  ▼
         │           │ API: /auth/verify-email/confirm
         │           │  ▼
         │           │ ✅ Success (200)
         │           │  ▼
         │           │ Verified! Auto-redirect
         │           │  ▼
         │  ┌────────────────────────┐
         │  │ Login Screen           │
         │  │ (Email field pre-filled)│
         │  └────────┬───────────────┘
         │           │
         │           ├─ Enter password
         │           ├─ Click "Sign In"
         │           │  ▼
         │           │ API: /auth/login
         │           │  ▼
         │           │ ✅ Success (200) + TOKEN
         │           │  ▼
         │           │ Token stored in secure storage
         │           │ Auto-redirect
         │           │  ▼
         │  ┌────────────────────────┐
         │  │ HOME SCREEN            │
         │  │ (Fully Authenticated)  │
         │  │                        │
         │  │ - Welcome John         │
         │  │ - Search button        │
         │  │ - Profile button       │
         │  │ - Logout button        │
         │  └────────────────────────┘
         │
         └─ "Sign In" clicked (email verified)
            ▼
           [Login Screen]
            ▼
           API: /auth/login
            ▼
           ✅ Success + TOKEN
            ▼
           [HOME SCREEN]
```

---

## 🔄 Resend Verification Email Flow

```
Scenario 1: From Verification Code Screen
─────────────────────────────────────────

User on code entry screen sees:
"Didn't receive code? Resend (0:05:00)" ← Button disabled

After 2 minutes:
"Didn't receive code? Resend" ← Button enabled

User clicks "Resend"
        ▼
API: /auth/verify-email/send
        ▼
✅ Success (200)
        ▼
Toast: "Email resent to newuser@example.com"
Timer resets: "0:15:00"
User checks email for new code
        ▼
Enters new code
        ▼
API: /auth/verify-email/confirm
        ▼
✅ Success (200)
        ▼
Auto-redirect to login


Scenario 2: From Login Screen (Unverified User)
─────────────────────────────────────────

User tries to login with unverified email
        ▼
API: /auth/login
        ▼
❌ Response: "Email not verified"
        ▼
Error screen shows:
"Verify your email to continue"
"Resend verification email" ← Link
        ▼
User clicks "Resend"
        ▼
API: /auth/verify-email/send
        ▼
✅ Success (200)
        ▼
Route to code entry screen
        ▼
User enters new code → verify → login
```

---

## 📋 API Endpoints Summary

| Endpoint | Method | Auth | Purpose |
|----------|--------|------|---------|
| `/auth/register` | POST | ❌ Public | Register new user |
| `/auth/login` | POST | ❌ Public | User login |
| `/auth/verify-email/send` | POST | ❌ Public | Send verification email |
| `/auth/verify-email/confirm` | POST | ❌ Public | Verify email with code |
| `/auth/me` | GET | ✅ Required | Get current user |
| `/auth/logout` | POST | ✅ Required | End session |

---

## ✅ Testing Checklist - Complete User Journey

- [ ] **Registration Flow**
  - [ ] Fill form with valid data
  - [ ] Click register
  - [ ] See success message
  - [ ] Token received from backend
  
- [ ] **Email Verification - Send**
  - [ ] Click "Send Verification Email"
  - [ ] See confirmation message
  - [ ] Email sent to backend
  - [ ] (In dev mode: Code appears in backend logs)

- [ ] **Email Verification - Confirm**
  - [ ] Enter verification code
  - [ ] Click "Verify"
  - [ ] See "Email Verified" message
  - [ ] Auto-redirect to login

- [ ] **Sign In**
  - [ ] Enter registered email & password
  - [ ] Click "Sign In"
  - [ ] Auto-redirect to Home
  - [ ] See welcome message

- [ ] **Post-Login Features**
  - [ ] Search button visible & clickable
  - [ ] Can search for other users
  - [ ] Profile button visible & clickable
  - [ ] Logout button visible & works

- [ ] **Error Handling**
  - [ ] Duplicate email shows error
  - [ ] Wrong password shows error
  - [ ] Invalid code shows error
  - [ ] Expired code can resend
  - [ ] App doesn't crash

- [ ] **Resend Verification**
  - [ ] Resend button disabled during cooldown
  - [ ] Resend button enabled after 2 minutes
  - [ ] New email received
  - [ ] New code works
  - [ ] Process completes successfully

---

## 🎉 Success Criteria

User journey is complete and successful when:

✅ User registers with unique email/username  
✅ Email verification sent successfully  
✅ Verification code accepted  
✅ User can login with registered credentials  
✅ Home screen displays after login  
✅ User can search for other users  
✅ User can logout  
✅ All errors handled gracefully (no crashes)  
✅ Can resend verification if needed  
✅ Complete journey takes ~1 minute  

---

**Status**: All backend APIs tested and working ✓  
**Ready to test**: In Flutter emulator with full UI flows ✓
