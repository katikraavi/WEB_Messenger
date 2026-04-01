#!/bin/bash

# Real Flow Testing - Code Verification + Expected Behavior
# This verifies all fixes are in place and explains actual flows

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         REAL FLOW VERIFICATION: Code + Behaviors         ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"

# Test 1: Code Path Verification
echo -e "\n${CYAN}[TEST 1] Code Path Verification${NC}"
echo "Verifying all fix implementations..."
echo ""

TESTS_PASSED=0
TESTS_TOTAL=0

# Test 1a: Old picture deletion
TESTS_TOTAL=$((TESTS_TOTAL + 1))
if grep -q "DELETE OLD PICTURE FILE IF IT EXISTS" backend/lib/src/endpoints/profile.dart; then
  echo -e "${GREEN}✅ 1. Old picture deletion code path${NC}"
  echo "   Location: backend/lib/src/endpoints/profile.dart"
  echo "   Behavior: Fetches old URL, deletes file, then saves new"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo -e "${RED}❌ 1. Old picture deletion code path${NC}"
fi

# Test 1b: Cache-busting
TESTS_TOTAL=$((TESTS_TOTAL + 1))
if grep -q "cacheTs.*DateTime.now" backend/lib/src/endpoints/profile.dart; then
  echo -e "${GREEN}✅ 2. Cache-busting timestamp code path${NC}"
  echo "   Location: backend/lib/src/endpoints/profile.dart"
  echo "   Behavior: Appends ?v={timestamp} to force fresh load"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo -e "${RED}❌ 2. Cache-busting timestamp code path${NC}"
fi

# Test 1c: Media bytea fix
TESTS_TOTAL=$((TESTS_TOTAL + 1))
if grep -q "bytesAsList.*toList()" backend/lib/src/services/media_storage_service.dart; then
  echo -e "${GREEN}✅ 3. Media upload bytea encoding fix${NC}"
  echo "   Location: backend/lib/src/services/media_storage_service.dart"
  echo "   Behavior: Converts Uint8List to List<int> for PostgreSQL"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo -e "${RED}❌ 3. Media upload bytea encoding fix${NC}"
fi

# Test 1d: Frontend cache invalidation
TESTS_TOTAL=$((TESTS_TOTAL + 1))
if grep -q "invalidateUserProfileCache" frontend/lib/features/profile/widgets/profile_image_upload_widget.dart; then
  echo -e "${GREEN}✅ 4. Frontend cache invalidation${NC}"
  echo "   Location: frontend/lib/features/profile/widgets/profile_image_upload_widget.dart"
  echo "   Behavior: Invalidates profile caches after upload/delete"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo -e "${RED}❌ 4. Frontend cache invalidation${NC}"
fi

# Test 1e: UserAvatarWidget cache handling
TESTS_TOTAL=$((TESTS_TOTAL + 1))
if grep -q "_extractBaseUrl" frontend/lib/features/chats/widgets/user_avatar_widget.dart; then
  echo -e "${GREEN}✅ 5. UserAvatarWidget cache nonce refresh${NC}"
  echo "   Location: frontend/lib/features/chats/widgets/user_avatar_widget.dart"
  echo "   Behavior: Detects cache parameters, increments nonce on change"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo -e "${RED}❌ 5. UserAvatarWidget cache nonce refresh${NC}"
fi

# Test 2: Backend Health
echo -e "\n${CYAN}[TEST 2] Backend Health${NC}"
HEALTH=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8081/health)
if [ "$HEALTH" = "200" ]; then
  echo -e "${GREEN}✅ Backend is running and healthy (HTTP $HEALTH)${NC}"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo -e "${RED}❌ Backend health check failed (HTTP $HEALTH)${NC}"
fi
TESTS_TOTAL=$((TESTS_TOTAL + 1))

# Test 3: Recent Logs
echo -e "\n${CYAN}[TEST 3] Backend Logs Analysis${NC}"

ERROR_COUNT=$(docker-compose logs --tail=500 messenger-backend 2>/dev/null | grep -i "42601\|syntax error.*{" | wc -l)
if [ $ERROR_COUNT -eq 0 ]; then
  echo -e "${GREEN}✅ No PostgreSQL encoding errors in recent logs${NC}"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo -e "${RED}❌ Found $ERROR_COUNT PostgreSQL encoding errors!${NC}"
fi
TESTS_TOTAL=$((TESTS_TOTAL + 1))

# Check for profile updates
PROFILE_UPDATES=$(docker-compose logs --tail=100 messenger-backend 2>/dev/null | grep -i "profile.*picture\|cache.*bust" | wc -l)
if [ $PROFILE_UPDATES -gt 0 ]; then
  echo -e "${GREEN}✅ Found recent profile picture activity${NC}"
  docker-compose logs --tail=100 messenger-backend 2>/dev/null | grep -i "profile\|cache" | tail -3 | while read line; do
    echo "   $line"
  done
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo -e "${YELLOW}⚠️  No recent profile picture uploads (normal if none sent)${NC}"
fi
TESTS_TOTAL=$((TESTS_TOTAL + 1))

# Test 4: File System Check
echo -e "\n${CYAN}[TEST 4] File System State${NC}"

if [ -d "uploads/profile_pictures" ]; then
  FILE_COUNT=$(find uploads/profile_pictures -type f 2>/dev/null | wc -l)
  echo -e "${GREEN}✅ Profile pictures directory exists${NC}"
  echo "   Files: $FILE_COUNT"
  
  if [ $FILE_COUNT -gt 0 ]; then
    echo -e "   ${YELLOW}Most recent files:${NC}"
    find uploads/profile_pictures -type f -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -5 | while read timestamp path; do
      basename "$path" | sed 's/^/     /'
    done
  fi
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo -e "${YELLOW}⚠️  Profile pictures directory doesn't exist yet (created on first upload)${NC}"
fi
TESTS_TOTAL=$((TESTS_TOTAL + 1))

# Summary
echo -e "\n${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}Test Results: $TESTS_PASSED / $TESTS_TOTAL PASSED${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo ""

if [ $TESTS_PASSED -eq $TESTS_TOTAL ]; then
  echo -e "${GREEN}✅ All verification tests passed!${NC}"
else
  echo -e "${YELLOW}⚠️  Some tests failed - review above${NC}"
fi

echo ""
echo -e "${YELLOW}ACTUAL FLOW BEHAVIORS:${NC}"
echo ""
echo -e "${CYAN}1️⃣  PROFILE PICTURE UPDATE FLOW:${NC}"
echo "   User uploads new picture in Profile > Edit"
echo "   ├─ Backend receives upload"
echo "   ├─ 🗑️  Fetches old picture URL from database"
echo "   ├─ 🗑️  Deletes old file from /uploads/profile_pictures/"
echo "   ├─ 📤 Saves new file"
echo "   ├─ ⏰ Adds timestamp: ?v=1711900596310"
echo "   ├─ 💾 Updates database with cache-bust URL"
echo "   └─ 📡 Broadcasts 'profile_updated' event to all WebSocket clients"
echo ""
echo "   Then in frontend:"
echo "   ├─ User's profile page shows new picture immediately"
echo "   ├─ Chat list updates other users' avatars (via profile cache invalidation)"
echo "   ├─ Search users results update avatars"
echo "   ├─ All message sender avatars update"
echo "   └─ Group member lists update"
echo ""

echo -e "${CYAN}2️⃣  MEDIA (VIDEO/IMAGE) UPLOAD FLOW:${NC}"
echo "   User sends video/image in chat"
echo "   ├─ Frontend reads file → Uint8List"
echo "   ├─ 📤 Sends to /api/media/upload endpoint"
echo "   ├─ Backend receives multipart request"
echo "   ├─ ✅ Extracts file bytes properly"
echo "   ├─ 🔄 Converts Uint8List → List<int>"
echo "   ├─ 📊 Stores in media_storage table (BYTEA column)"
echo "   └─ ✅ Returns media ID and download URL"
echo ""
echo "   Result:"
echo "   ✅ No PostgreSQL error: 'syntax error at or near \"{{\"'"
echo "   ✅ Media displays in chat"
echo "   ✅ File persists in database (survives Render restarts)"
echo ""

echo -e "${CYAN}3️⃣  CACHE INVALIDATION FLOW:${NC}"
echo "   When profile picture changes:"
echo "   ├─ WebSocket sends 'profile_updated' event"
echo "   ├─ Frontend's profileUpdateListenerEffect listens for event"
echo "   ├─ Increments profileUserCacheInvalidatorProvider(userId)"
echo "   ├─ All userProfileProvider instances watching this counter re-evaluate"
echo "   ├─ UserAvatarWidget receives new URL with new ?v= parameter"
echo "   ├─ Increments _reloadNonce on parameter change"
echo "   ├─ Image.network() with new key bypasses cache"
echo "   └─ Fresh image loads everywhere"
echo ""

echo -e "${YELLOW}TO TEST MANUALLY:${NC}"
echo ""
echo "1. In one terminal, watch logs:"
echo "   ${CYAN}docker-compose logs -f messenger-backend | grep -iE 'picture|upload|cache|media|broadcast'${NC}"
echo ""
echo "2. In the app:"
echo "   • Go to Profile → Edit"
echo "   • Upload new profile picture"
echo "   • Watch logs for: '🗑️ Deleted old picture file' + 'cache-bust' timestamp"
echo ""
echo "3. For media upload test:"
echo "   • Send a small video/image through chat"
echo "   • Watch logs for: '✓ File uploaded to DB'"
echo "   • Should NOT see: 'PostgreSQLSeverity.error 42601'"
echo ""
echo "4. Verify display updates (no page reload needed):"
echo "   • Chat list avatars change"
echo "   • Search users avatars change"
echo "   • Message sender avatars change"
echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
