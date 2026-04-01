# Complete Testing Guide: Message Edits + Encryption + Resilience

## Overview
Test 3 critical fixes:
1. **Encryption Fix** - Random.secure() nonce generation (no MAC errors on edited messages)
2. **Resilience Fix** - Connection health monitoring (survives database outages)
3. **UI Fix** - Edited messages display immediately (no refresh needed)

---

## 📋 BASELINE SETUP

### Prerequisites
- [ ] Fresh APK installed (build date: April 1, 2026)
- [ ] Backend running locally (`docker-compose ps` shows healthy)
- [ ] Two test user accounts created (User A & User B)
- [ ] Test users in a group chat together
- [ ] Browser DevTools open (F12) for debugging

### Quick Environment Check
```bash
# Backend health
curl http://localhost:8081/health

# Database connected
docker-compose logs messenger-backend | grep -i "database\|connected"

# WebSocket working
curl http://localhost:8081/api/chats/{chatId}
# Should list messages
```

---

## 🧪 TEST 1: EDITED MESSAGE DISPLAY (Personal Chats)

**Duration:** 5 minutes

### Step 1: Send Initial Message
1. Open app as User A
2. Open personal chat with User B
3. Send message: `"Hello - ORIGINAL MESSAGE"`
4. ✅ Verify User B receives it immediately

### Step 2: Edit Message (Critical Test)
1. User A: Long-press message → Edit
2. Change to: `"Hello - EDITED MESSAGE"`
3. Save/Send edit
4. **Watch User B's chat - message should update WITHOUT refresh** ⭐

### Expected Result
- [ ] User B sees `"Hello - EDITED MESSAGE"` immediately
- [ ] Message shows "(edited)" badge
- [ ] No refresh button needed
- [ ] No errors in DevTools console
- [ ] No MAC errors: `[ERROR] Decryption failed: SecretBox has wrong...`

### If It Fails
```bash
# Check browser console for errors
# DevTools → Console tab
# Look for: "Decryption failed", "MAC", "authentication"

# Check backend logs
docker logs messenger-backend | tail -50 | grep -i "error\|decrypt"

# Check if edit was sent
# Network tab → PUT /api/chats/{chatId}/messages/{id}
# Should be 200 OK
```

---

## 🧪 TEST 2: EDITED MESSAGE DISPLAY (Group Chats)

**Duration:** 5 minutes

### Setup
- [ ] 3+ users in group chat (A, B, C)

### Test Flow
1. User A sends: `"Group message - ORIGINAL"`
2. All users receive it
3. User A edits to: `"Group message - EDITED"`
4. User B AND User C should see update immediately
5. **No refresh needed for either user** ⭐

### Expected Result
- [ ] Both User B and C see the edit without refresh
- [ ] Edit shows in messages list
- [ ] Timestamps correct
- [ ] No decryption errors

---

## 🧪 TEST 3: Rapid Message Edits (Stress Test)

**Duration:** 10 minutes

### Test Flow
1. User A sends: `"Edit 1 of 5"`
2. Rapidly edit 4 more times:
   - Save → `"Edit 2 of 5"`
   - Save → `"Edit 3 of 5"`
   - Save → `"Edit 4 of 5"`
   - Save → `"Edit 5 of 5"`
3. Watch User B's chat in real-time
4. Each edit should appear without refresh

### Expected Result
- [ ] All 5 edits visible to User B
- [ ] Each appears immediately
- [ ] No stuck messages
- [ ] No MAC errors in console
- [ ] All messages final-state correct

### If It Fails
- Check backend logs for nonce generation issues
- Verify Random.secure() is being used:
  ```bash
  grep -n "Random.secure()" backend/lib/src/services/encryption_service.dart
  # Should show: final random = Random.secure();
  ```

---

## 🧪 TEST 4: Message Edit + Network Interruption

**Duration:** 15 minutes

### Test Flow
1. User A sends: `"Test with network issue"`
2. User B receives it
3. **Simulate network interruption** (unplug ethernet OR use DevTools throttling)
4. User A edits message
5. **Restore connection**
6. User B should eventually see the edit

### How to Simulate (Browser DevTools)
- DevTools → Network tab
- Click gear icon → Add "Offline" condition
- Wait 5 seconds
- Remove offline condition

### Expected Result
- [ ] Edit eventually arrives after network restored
- [ ] No permanent errors
- [ ] Next message after edit sends/receives normally
- [ ] Chat is responsive again

---

## 🧪 TEST 5: Database Connection Recovery (Render-Like Scenario)

**Duration:** 10 minutes

### Test Flow
1. Backend running, app connected
2. Make several message sends/receives (verify working)
3. **Stop PostgreSQL without stopping backend:**
   ```bash
   docker pause messenger-postgres
   ```
4. Try user action (send message, fetch chat)
5. **Restart PostgreSQL:**
   ```bash
   docker unpause messenger-postgres
   ```
6. Try message operations again

### Expected Result
- [ ] While DB paused:
  - Requests return 503 error (not 500)
  - Clear "Database unavailable" message
  - No confusing errors
  
- [ ] After DB restarts:
  - Backend auto-reconnects
  - Requests succeed immediately
  - No manual intervention needed
  - Previous unsent messages retry (if queueing implemented)

### Verification
```bash
# Check backend health during downtime
curl http://localhost:8081/health
# Should return 503, not 500

# Watch backend logs
docker logs -f messenger-backend | grep -i "health\|reconnect\|database"
# Should show: "attempting reconnect", "reconnected successfully"
```

---

## 🧪 TEST 6: Message Integrity (Encryption Quality)

**Duration:** 5 minutes

### Test Flow
1. User A sends 10 different messages
2. User A edits 5 of them multiple times
3. User B checks that:
   - Original versions shown with metadata
   - All edits visible and correct
   - No content corruption
   - No garbled text

### Content Variations to Test
- [ ] Regular ASCII: `"Hello world"`
- [ ] Emojis: `"Hello 😊 world 🌍"`
- [ ] Long text: Multi-paragraph content
- [ ] Special chars: `"Test!@#$%^&*()"`
- [ ] Empty/minimal: `"Hi"`

### Expected Result
- [ ] ALL content decrypts correctly
- [ ] Edited versions show correct final content
- [ ] No corrupted data in database

### If It Fails
```bash
# Check encrypted content format
# Browser DevTools → Application → Local Storage
# Look for cached messages

# Verify message in database
docker exec messenger-postgres psql -U messenger_user -d messenger_db -c \
  "SELECT id, encrypted_content, edited_at FROM messages LIMIT 5;"
# Should show proper base64 format: nonce::ciphertext::mac
```

---

## 🧪 TEST 7: No Regression - Other Features Still Work

**Duration:** 15 minutes

### Basic Functionality
- [ ] Login / Logout works
- [ ] Create personal chat works
- [ ] Create group chat works
- [ ] Send regular (unedited) messages works
- [ ] Delete messages works
- [ ] Change profile picture works

### Message Operations
- [ ] Send message to User B
- [ ] Edit message (just fixed)
- [ ] Delete message → shows "[Message deleted]"
- [ ] React to message (if implemented)
- [ ] Forward message (if implemented)
- [ ] Search messages works

### Chat Operations
- [ ] Mute/unmute chat
- [ ] Archive chat (if implemented)
- [ ] Leave group
- [ ] Add member to group
- [ ] Remove member from group
- [ ] View member list

### Media (if used)
- [ ] Send photo/video
- [ ] Edit message with media (text changes)
- [ ] Display media correctly

### Notifications
- [ ] New message notification appears
- [ ] Notification shows correct preview
- [ ] Clicking notification opens correct chat

### Check Box
- [ ] Nothing broken ✅

---

## 🧪 TEST 8: Error Handling

**Duration:** 10 minutes

### Deliberate Error Scenarios
1. **Invalid/Corrupted Message:**
   - Manually corrupt a message in database
   - Try to view chat
   - Should show error, not crash

2. **Old Format Messages:**
   - If any old pre-encryption messages exist
   - Should still display correctly
   - No decryption errors

3. **Connection Loss During Edit:**
   - Start editing message
   - Lose internet
   - Try to save
   - Should show error, allow retry

4. **Concurrent Edits:**
   - User A edits message
   - User B edits same message simultaneously
   - Last edit should win
   - Both users see correct final version

### Expected Result
- [ ] All errors graceful with user-friendly messages
- [ ] No crashes or blank screens
- [ ] Retry mechanisms work
- [ ] App remains functional after errors

---

## 📊 COMPREHENSIVE CHECKLIST

### Critical Fixes (Must Pass)
- [ ] **Encryption Fix**: Edited messages decrypt without MAC errors
- [ ] **UI Fix**: Edited messages show immediately (no refresh)
- [ ] **Resilience Fix**: Backend survives DB reconnection
- [ ] **Personal Chats**: Edits work for 1-on-1 messages
- [ ] **Group Chats**: Edits work for group messages

### Functionality (Regression)
- [ ] Login/Logout
- [ ] Send messages
- [ ] Receive messages
- [ ] Create chats
- [ ] Search
- [ ] Profile updates
- [ ] Notifications

### Platform Coverage
- [ ] Web (http://localhost:5000)
- [ ] Mobile APK (on device)
- [ ] Different Android versions (if multiple devices)

### Edge Cases
- [ ] Long messages (>1000 char)
- [ ] Rapid edits (5+ in sequence)
- [ ] Network interruptions
- [ ] Database temporarily down
- [ ] Empty/minimal content
- [ ] Special characters/emojis

---

## 🔍 DEBUGGING COMMANDS

If tests fail, run these:

```bash
# 1. Backend logs - see what server is doing
docker logs -f messenger-backend | grep -i "error\|warning\|decrypt\|health"

# 2. Check encryption implementation
grep -A5 "Random.secure()" backend/lib/src/services/encryption_service.dart

# 3. Verify message in database
docker exec messenger-postgres psql -U messenger_user -d messenger_db -c \
  "SELECT id, chat_id, sender_id, created_at, edited_at, encrypted_content \
   FROM messages ORDER BY created_at DESC LIMIT 5;"

# 4. Frontend console (Browser DevTools)
# Console tab → look for errors
# Network tab → check request/response for edits
# Application → Local Storage → check cached data

# 5. Test nonce uniqueness
cd backend && dart test_encryption_fix.dart
# Should show all nonces UNIQUE

# 6. Check connection health
curl http://localhost:8081/health
# Should show: {"status":"healthy","timestamp":"..."}

# 7. Force connection error (for resilience testing)
docker pause messenger-postgres
sleep 3
curl http://localhost:8081/health
# Should show 503, not 500 or hang

docker unpause messenger-postgres
sleep 5
curl http://localhost:8081/health
# Should recover to healthy
```

---

## ✅ SIGN-OFF CHECKLIST

When all tests pass, check these:

- [ ] No errors in browser console
- [ ] No errors in backend logs
- [ ] All 3 fixes verified working
- [ ] No regressions in existing features
- [ ] Edge cases handled gracefully
- [ ] APK ready for distribution
- [ ] Backend ready for Render deployment

**Test Date:** _______________
**Tester:** _______________
**Result:** ✅ PASS / ❌ FAIL
**Issues Found:** _______________

---

## 📝 WHAT WAS FIXED (Reference)

### 1. Encryption (Random.secure())
- **Before:** Weak timestamp-based nonce generation → MAC errors
- **After:** Cryptographically secure Random.secure() → unique nonces
- **Files:** `encryption_service.dart`, `message_encryption_service.dart`

### 2. Connection Health
- **Before:** Connection dies → all requests fail (503)
- **After:** Auto-detects death → auto-reconnects
- **Files:** `connection_health_monitor.dart`, `middleware.dart`, `server.dart`

### 3. Edit Display
- **Before:** Edited messages only show after refresh
- **After:** Immediate display via updated equality operator
- **Files:** `message_model.dart`, `messages_provider.dart`

---

## Need Help?

If a test fails:
1. Run the debug command for that section
2. Check the logs
3. Look at the files mentioned above
4. Compare with expected behavior
5. Note the error and file a bug report with:
   - Steps to reproduce
   - Error message/screenshot
   - Backend logs snippet
   - Browser console errors
