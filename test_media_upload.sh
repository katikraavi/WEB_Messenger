#!/bin/bash

# Test script to verify image and video uploads

BASE_URL="http://localhost:8081"
BOB_EMAIL="bob@example.com"
BOB_PASSWORD="bob123"

echo "===== MEDIA UPLOAD TEST ====="
echo ""

# Step 1: Login as Bob
echo "1️⃣  Logging in as Bob..."
BOB_LOGIN=$(curl -s -X POST "$BASE_URL/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$BOB_EMAIL\",\"password\":\"$BOB_PASSWORD\"}")

BOB_TOKEN=$(echo $BOB_LOGIN | grep -o '"token":"[^"]*' | sed 's/"token":"//' | head -1)

if [ -z "$BOB_TOKEN" ]; then
  echo "❌ Failed to login Bob"
  echo "Response: $BOB_LOGIN"
  exit 1
fi

echo "✅ Bob logged in"
echo ""

# Step 2: Test image upload
echo "2️⃣  Testing PNG image upload..."
IMAGE_RESPONSE=$(curl -s -X POST "$BASE_URL/api/media/upload" \
  -H "Authorization: Bearer $BOB_TOKEN" \
  -F "file=@/home/katikraavi/mobile-messenger/Test_Pictures/Maastik.png" \
  -F "mime_type=image/png" \
  -F "file_name=Maastik.png")

IMAGE_ID=$(echo $IMAGE_RESPONSE | grep -o '"id":"[^"]*' | sed 's/"id":"//' | head -1)

if [ -z "$IMAGE_ID" ]; then
  echo "❌ Image upload failed"
  echo "Response: $IMAGE_RESPONSE"
  exit 1
fi

echo "✅ Image uploaded successfully: $IMAGE_ID"
echo ""

# Step 3: Test JPG image upload
echo "3️⃣  Testing JPG image upload..."
JPG_RESPONSE=$(curl -s -X POST "$BASE_URL/api/media/upload" \
  -H "Authorization: Bearer $BOB_TOKEN" \
  -F "file=@/home/katikraavi/mobile-messenger/Test_Pictures/okPicture.jpg" \
  -F "mime_type=image/jpeg" \
  -F "file_name=okPicture.jpg")

JPG_ID=$(echo $JPG_RESPONSE | grep -o '"id":"[^"]*' | sed 's/"id":"//' | head -1)

if [ -z "$JPG_ID" ]; then
  echo "❌ JPG upload failed"
  echo "Response: $JPG_RESPONSE"
  exit 1
fi

echo "✅ JPG uploaded successfully: $JPG_ID"
echo ""

# Step 4: Test video upload
echo "4️⃣  Testing video upload (MP4)..."
VIDEO_RESPONSE=$(curl -s -X POST "$BASE_URL/api/media/upload" \
  -H "Authorization: Bearer $BOB_TOKEN" \
  -F "file=@/home/katikraavi/mobile-messenger/Test_Pictures/Salvestamine202334.mp4" \
  -F "mime_type=video/mp4" \
  -F "file_name=Salvestamine202334.mp4")

VIDEO_ID=$(echo $VIDEO_RESPONSE | grep -o '"id":"[^"]*' | sed 's/"id":"//' | head -1)

if [ -z "$VIDEO_ID" ]; then
  echo "❌ Video upload failed"
  echo "Response: $VIDEO_RESPONSE"
  exit 1
fi

echo "✅ Video uploaded successfully: $VIDEO_ID"
echo ""

echo "===== TEST SUMMARY ====="
echo "✅ PNG Image: $IMAGE_ID"
echo "✅ JPG Image: $JPG_ID"
echo "✅ Video (MP4): $VIDEO_ID"
echo ""
echo "All media uploads successful! 🎉"
