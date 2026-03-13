# Testing Guide - Authentication Flow

## Quick Setup
Backend and database are running and ready.

---

## Test Scenario 1: Fresh Registration & Login

### Step 1: Clear Previous Test Data
- Press `c` in the Flutter terminal to clear the screen
- Or close and reopen the app

### Step 2: Register New Account
1. **From Login Screen**: Click **"Create one"** link (bottom)
2. **Fill in Test Person 1 Account**:
   - Click `Person 1` button (yellow box at bottom)
   - Should auto-fill:
     - Email: `test1@example.com`
     - Username: `test1_user`
     - Password: `Test123!`
     - Full Name: `Test Person 1`
3. **Click "Create Account"** button
4. Note the result:
   - ✅ Should show "Account created successfully! Please login."
   - ❌ If error: Report the exact error message

### Step 3: Login With Same Account
1. **Auto-fill on Login Screen**:
   - Click `Person 1` button (yellow box at bottom)
   - Should auto-fill:
     - Email: `test1@example.com`
     - Password: `Test123!`
2. **Click "Login"** button
3. Note the result:
   - ✅ Should show "Login successful!" message
   - ✅ Should dismiss login screen and show home
   - ❌ If error: **Take note of the exact error message** and report it

---

## Test Scenario 2: Test Person 2

### Step 1: Register Person 2
1. **From Login Screen**: Click "Create one"
2. **Click "Person 2"** button (auto-fills test2 account)
3. **Click "Create Account"**
4. Note result

### Step 2: Login as Person 2
1. You should automatically go back to Login screen
2. **Click "Person 2"** button (auto-fills)
3. **Click "Login"**
4. Note result

---

## Test Scenario 3: Manual Registration

### If Auto-Fill Works But Login Fails
1. **Go to Registration**
2. **Manually enter unique credentials**:
   - Email: `mytest@example.com` (use something unique)
   - Username: `myusername`
   - Password: Must have:
     - 8+ characters
     - Uppercase letter (A-Z)
     - Lowercase letter (a-z)
     - Number (0-9)
     - Special character (!@#$%^&*(),.?":{}|<>)
   - Full Name: `My Test Name`
3. **Click "Create Account"**
4. **Then try logging in with those same credentials**

---

## What to Report If There's an Error

When you see an error, please tell me:

1. **Exact error message text** (copy-paste from screen or snackbar)
2. **Which button caused it** (Register / Login / Test Account)
3. **Which screen you were on** (Login / Registration)
4. **Check Flutter terminal** - Look for any red error output
5. **Check backend logs** - Run:
   ```bash
   docker logs messenger-backend 2>&1 | tail -20
   ```

---

## UI Button Layout

### Login Screen (Bottom Section)
```
┌─────────────────────────────────────────────┐
│ 🧪 Quick Test Accounts                      │
│                                             │
│ [Person 1 Button]  [Person 2 Button]       │
└─────────────────────────────────────────────┘
```

### Registration Screen (Bottom Section)
Same layout as login screen

---

## Expected Behavior After Login

After successful login, you should see:
- ✅ App dismisses the login/registration screens
- ✅ Shows the authenticated home screen
- ✅ Displays logged-in user's email and username
- ✅ Has a "Logout" button

---

## Troubleshooting Checklist

- [ ] Backend is running: `docker ps` should show both `messenger-postgres` and `messenger-backend`
- [ ] Backend is healthy: `curl http://localhost:8081/health` should return `{"status":"healthy",...}`
- [ ] Flutter app is running: Active Flutter DevTools connection
- [ ] No compilation errors: Flutter terminal shows "All good" or no red errors

---

## Test Each Feature

| Feature | Test | Expected |
|---------|------|----------|
| **Health Button** | Press quick test button | Fields auto-fill, no crash |
| **Email Validation** | Enter invalid email | Shows "Invalid email format" error |
| **Password Validation** | Enter weak password | Shows password requirements error |
| **Duplicate Email** | Register twice with same email | Shows "Email already registered" error |
| **Duplicate Username** | Register with same username | Shows "Username already taken" error |
| **Invalid Login** | Login with wrong password | Shows "Invalid email or password" error |
| **Successful Login** | Login with correct credentials | Goes to home screen |
| **Token Storage** | Login, then close app | Should still be logged in after restart |
| **Logout** | Click logout button | Returns to login screen |

---

## Questions to Answer While Testing

1. Does the app **crash** on any button click?
2. Does **registration** complete successfully?
3. Does **login** work after registration?
4. Can you see the **quick test buttons** (yellow boxes)?
5. Do test buttons **auto-fill correctly**?
6. Are error messages **clear and helpful**?
7. Can you see your **username/email** after login?
8. Does **logout** work?

---

## Report Format

If you find a problem, copy this template:

```
## Bug Report

**Test Scenario**: [Which test scenario]
**Issue**: [What went wrong]
**Error Message**: [Exact text shown to user]
**Terminal Output**: [Any red errors in Flutter terminal]
**Backend Logs**: [Last 10 lines from docker logs messenger-backend]
**Steps to Reproduce**:
1. [Step 1]
2. [Step 2]
3. [Step 3]

**Expected**: [What should happen]
**Actual**: [What actually happened]
```

---

## Ready to Test?

Start with **Test Scenario 1** and follow each step carefully.

Report back with any errors you encounter! 🧪
