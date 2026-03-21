#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

BASE_URL="http://localhost:8081"

echo -e "${YELLOW}🎥 Testing Video Upload to Messenger App${NC}\n"

# 1. Register a new test user
echo -e "${YELLOW}1️⃣ Registering test user...${NC}"
TEST_ID=$(date +%s)
TEST_EMAIL="video_test_${TEST_ID}@test.com"
TEST_USERNAME="video_tester_${TEST_ID}"
TEST_PASSWORD="VideoTest123!"

REGISTER_RESPONSE=$(curl -s -X POST $BASE_URL/auth/register \
  -H "Content-Type: application/json" \
  -d "{
    \"email\": \"$TEST_EMAIL\",
    \"password\": \"$TEST_PASSWORD\",
    \"username\": \"$TEST_USERNAME\"
  }")

echo "$REGISTER_RESPONSE" | jq . 2>/dev/null || echo "$REGISTER_RESPONSE"
echo ""

# Check registration status and extract verification token
if echo "$REGISTER_RESPONSE" | grep -q 'error'; then
  echo -e "${RED}   ❌ Registration failed${NC}"
  exit 1
fi
echo -e "${GREEN}   ✅ User registered: $TEST_EMAIL${NC}\n"

# Extract dev verification token
DEV_TOKEN=$(echo "$REGISTER_RESPONSE" | grep -o '"dev_verification_token":"[^"]*' | cut -d'"' -f4)
echo -e "${BLUE}   Dev Token: ${DEV_TOKEN:0:20}...${NC}\n"

# Verify email using dev token
echo -e "${YELLOW}1b️⃣ Verifying email...${NC}"
VERIFY_RESPONSE=$(curl -s -X POST $BASE_URL/auth/verify-email/confirm \
  -H "Content-Type: application/json" \
  -d "{
    \"token\": \"$DEV_TOKEN\"
  }")

if echo "$VERIFY_RESPONSE" | grep -q 'error'; then
  echo -e "${RED}   ❌ Email verification failed${NC}"
  echo "Response: $VERIFY_RESPONSE"
  exit 1
fi
echo -e "${GREEN}   ✅ Email verified${NC}\n"

# 2. Login to get auth token
echo -e "${YELLOW}2️⃣ Logging in to get auth token...${NC}"
LOGIN_RESPONSE=$(curl -s -X POST $BASE_URL/auth/login \
  -H "Content-Type: application/json" \
  -d "{
    \"email\": \"$TEST_EMAIL\",
    \"password\": \"$TEST_PASSWORD\"
  }")

TOKEN=$(echo "$LOGIN_RESPONSE" | grep -o '"token":"[^"]*' | cut -d'"' -f4)

if [ -z "$TOKEN" ]; then
  echo -e "${RED}   ❌ Failed to get token${NC}"
  echo "Response: $LOGIN_RESPONSE"
  exit 1
fi

echo -e "${GREEN}   ✅ Got auth token: ${TOKEN:0:30}...${NC}\n"

# 3. Create test video file (2MB fake video)
echo -e "${YELLOW}3️⃣ Creating test video file...${NC}"
dd if=/dev/urandom of=/tmp/test_video.mp4 bs=1M count=2 2>/dev/null
echo -e "${GREEN}   ✅ Created /tmp/test_video.mp4 (2MB)${NC}\n"

# 4. Upload video
echo -e "${YELLOW}4️⃣ Uploading video file...${NC}"
UPLOAD_RESPONSE=$(curl -s -X POST $BASE_URL/api/media/upload \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-file-type: video/mp4" \
  -H "x-file-name: test_video.mp4" \
  -H "Content-Type: multipart/form-data" \
  -F "file=@/tmp/test_video.mp4")

echo -e "${BLUE}Response:${NC}"
echo "$UPLOAD_RESPONSE" | jq . 2>/dev/null || echo "$UPLOAD_RESPONSE"
echo ""

# Check if upload was successful
if echo "$UPLOAD_RESPONSE" | grep -q '"id"'; then
  echo -e "${GREEN}   ✅ Video uploaded successfully!${NC}\n"
  
  # Extract media ID
  MEDIA_ID=$(echo "$UPLOAD_RESPONSE" | grep -o '"id":"[^"]*' | cut -d'"' -f4 | head -1)
  echo -e "${GREEN}   Media ID: ${MEDIA_ID}${NC}\n"
  
  # Extract file size and type
  FILE_SIZE=$(echo "$UPLOAD_RESPONSE" | grep -o '"size":[0-9]*' | cut -d':' -f2)
  FILE_TYPE=$(echo "$UPLOAD_RESPONSE" | grep -o '"mime_type":"[^"]*' | cut -d'"' -f4)
  
  echo -e "${GREEN}   File Type: ${FILE_TYPE}${NC}"
  echo -e "${GREEN}   File Size: ${FILE_SIZE} bytes${NC}"
else
  echo -e "${RED}   ❌ Upload failed${NC}\n"
  echo "Response: $UPLOAD_RESPONSE"
  exit 1
fi

# 5. Clean up
rm /tmp/test_video.mp4
echo -e "\n${GREEN}✅ Video upload test completed successfully!${NC}"
