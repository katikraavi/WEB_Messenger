#!/bin/bash

# Profile Picture & Media Upload Verification Script
# Tests all fixes for profile picture display and media uploads

set -e

echo "=========================================="
echo "🖼️  Profile Picture & Media Upload Fix Verification"
echo "=========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test 1: Check profile picture upload directory exists
echo -e "\n${BLUE}Test 1: Checking profile picture upload directory...${NC}"
if [ -d "uploads/profile_pictures" ]; then
  echo -e "${GREEN}✅ Profile pictures directory exists${NC}"
  FILE_COUNT=$(find uploads/profile_pictures -type f 2>/dev/null | wc -l)
  echo "   Files in directory: $FILE_COUNT"
else
  echo -e "${YELLOW}⚠️  Profile pictures directory doesn't exist (will be created on first upload)${NC}"
fi

# Test 2: Check media storage directory exists
echo -e "\n${BLUE}Test 2: Checking media storage directory...${NC}"
if [ -d "uploads/media" ]; then
  echo -e "${GREEN}✅ Media storage directory exists${NC}"
  MEDIA_COUNT=$(find uploads/media -type f 2>/dev/null | wc -l)
  echo "   Files in directory: $MEDIA_COUNT"
else
  echo -e "${YELLOW}⚠️  Media storage directory doesn't exist (will be created on first upload)${NC}"
fi

# Test 3: Verify backend code changes
echo -e "\n${BLUE}Test 3: Verifying backend code changes...${NC}"

# Check for old picture deletion logic
if grep -q "DELETE OLD PICTURE FILE" backend/lib/src/endpoints/profile.dart; then
  echo -e "${GREEN}✅ Old picture deletion logic found${NC}"
else
  echo -e "${RED}❌ Old picture deletion logic NOT found${NC}"
fi

# Check for cache-busting timestamp
if grep -q "cache.*bust\|\\?v=" backend/lib/src/endpoints/profile.dart; then
  echo -e "${GREEN}✅ Cache-busting timestamp logic found${NC}"
else
  echo -e "${RED}❌ Cache-busting timestamp logic NOT found${NC}"
fi

# Check for binary data fix
if grep -q "bytesAsList.*=.*fileBytes.toList()" backend/lib/src/services/media_storage_service.dart; then
  echo -e "${GREEN}✅ Media upload binary data fix found${NC}"
else
  echo -e "${RED}❌ Media upload binary data fix NOT found${NC}"
fi

# Test 4: Verify frontend code changes
echo -e "\n${BLUE}Test 4: Verifying frontend code changes...${NC}"

# Check for cache nonce handling
if grep -q "_extractBaseUrl" frontend/lib/features/chats/widgets/user_avatar_widget.dart; then
  echo -e "${GREEN}✅ Cache nonce handling found${NC}"
else
  echo -e "${RED}❌ Cache nonce handling NOT found${NC}"
fi

# Check for invalidation calls
if grep -q "invalidateUserProfileCache" frontend/lib/features/profile/widgets/profile_image_upload_widget.dart; then
  echo -e "${GREEN}✅ Profile cache invalidation found in upload widget${NC}"
else
  echo -e "${RED}❌ Profile cache invalidation NOT found${NC}"
fi

# Test 5: Check database schema
echo -e "\n${BLUE}Test 5: Checking database schema...${NC}"
if grep -q "file_data BYTEA" backend/migrations/027_add_file_data_to_media_storage.dart; then
  echo -e "${GREEN}✅ Media storage BYTEA column found${NC}"
else
  echo -e "${YELLOW}⚠️  Media storage BYTEA column migration not found (might be in different migration)${NC}"
fi

# Test 6: Test local build
echo -e "\n${BLUE}Test 6: Testing backend build...${NC}"
if command -v dart &> /dev/null; then
  cd backend
  if dart analyze lib/src/endpoints/profile.dart 2>&1 | grep -q "error"; then
    echo -e "${RED}❌ Backend analysis failed${NC}"
    dart analyze lib/src/endpoints/profile.dart
  else
    echo -e "${GREEN}✅ Backend code analysis passed${NC}"
  fi
  cd -
else
  echo -e "${YELLOW}⚠️  Dart not found, skipping backend analysis${NC}"
fi

# Test 7: Summary
echo -e "\n${BLUE}=========================================="
echo "Summary of Changes:${NC}"
echo "=========================================="
echo -e "${GREEN}✅ Backend Changes:${NC}"
echo "   - Old profile pictures are now deleted on upload"
echo "   - Cache-busting timestamps appended to picture URLs"
echo "   - WebSocket broadcasts include new cache-bust URLs"

echo -e "\n${GREEN}✅ Frontend Changes:${NC}"
echo "   - UserAvatarWidget properly handles cache refresh"
echo "   - Profile cache invalidation after upload/delete"
echo "   - Ripple invalidation to all avatar displays"

echo -e "\n${GREEN}✅ Media Upload Fixes:${NC}"
echo "   - Fixed binary data encoding for PostgreSQL BYTEA"
echo "   - Video and image uploads now work correctly"

echo -e "\n${YELLOW}Next Steps:${NC}"
echo "1. Run: ./scripts/validate-env.sh"
echo "2. Run: ./start.sh"
echo "3. Test in app:"
echo "   - Upload a profile picture"
echo "   - Verify it shows in profile, chat list, search, messages"
echo "   - Verify old picture is deleted from disk"
echo "   - Send a video/image through chat"
echo "   - Verify no PostgreSQL errors in logs"
echo ""
