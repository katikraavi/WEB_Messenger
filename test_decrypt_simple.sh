#!/bin/bash

# Simple decryption test without jq dependency

set -e

API_URL="${API_URL:-https://web-messenger-backend.onrender.com}"

 echo "╔════════════════════════════════════════════════════════════╗"
echo "║ SIMPLE ENCRYPTION/DECRYPTION TEST                         ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Test 1: Check if backend is running
echo "✓ Checking backend connectivity..."
HEALTH=$(curl -s "$API_URL/api/chats" \
  -H "Authorization: Bearer invalid-token" 2>&1 || echo "")

if [[ $HEALTH == *"error"* ]] || [[ $HEALTH == *"Unauthorized"* ]] || [[ $HEALTH == *"401"* ]]; then
  echo "  ✅ Backend is running and accessible"
else
  echo "  ❌ Backend not responding properly"
  echo "  Response: $(echo $HEALTH | head -c 200)"
  exit 1
fi

echo ""
echo "✓ Attempting to login Alice..."

# Test 2: Login
LOGIN_RESPONSE=$(curl -s -X POST "$API_URL/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"alice@example.com","password":"alice123"}' 2>&1)

if [[ $LOGIN_RESPONSE == *"error"* ]] || [[ ! $LOGIN_RESPONSE == *"token"* ]]; then
  echo "  ❌ Login failed"
  echo "  Response: $LOGIN_RESPONSE"
  exit 1
fi

# Extract token (simple grep-based extraction)
TOKEN=$(echo "$LOGIN_RESPONSE" | grep -o '"token":"[^"]*' | cut -d'"' -f4)
ALICE_ID=$(echo "$LOGIN_RESPONSE" | grep -o '"id":"[^"]*' | head -1 | cut -d'"' -f4)

if [ -z "$TOKEN" ]; then
  echo "  ❌ Could not extract token"
  exit 1
fi

echo "  ✅ Alice logged in: $ALICE_ID"
echo "  Token: ${TOKEN:0:20}..."
echo ""

# Test 3: Get messages
echo "✓ Fetching messages..."
CHATS=$(curl -s "$API_URL/api/chats" \
  -H "Authorization: Bearer $TOKEN" 2>&1)

if [[ $CHATS == *"error"* ]]; then
  echo "  ❌ Failed to fetch chats"
  echo "  Response: $CHATS"
  exit 1
fi

# Extract first chat ID  
CHAT_ID=$(echo "$CHATS" | grep -o '"id":"[a-f0-9\-]*' | head -4 | tail -1 | cut -d'"' -f4)

if [ -z "$CHAT_ID" ]; then
  echo "  ⚠️  No chats found"
  exit 0
fi

echo "  ✅ Chat ID: $CHAT_ID"
echo ""

# Test 4: Get messages from that chat
echo "✓ Fetching messages from chat..."
MESSAGES=$(curl -s "$API_URL/api/chats/$CHAT_ID/messages" \
  -H "Authorization: Bearer $TOKEN" 2>&1)

if [[ $MESSAGES == *"error"* ]]; then
  echo "  ❌ Failed to fetch messages"
  exit 1
fi

# Find first message with encrypted content
FIRST_ENCRYPTED=$(echo "$MESSAGES" | grep -o '"encrypted_content":"[^"]*' | head -1 | cut -d'"' -f4)
FIRST_CONTENT=$(echo "$MESSAGES" | grep -o '"content":"[^"]*' | head -1 | cut -d'"' -f4)

if [ -z "$FIRST_ENCRYPTED" ]; then
  echo "  ⚠️  No encrypted messages found"
  echo "  Messages: $(echo $MESSAGES | head -c 300)..."
  exit 0
fi

echo "  Encrypted content: ${FIRST_ENCRYPTED:0:50}..."
echo "  Decrypted content: ${FIRST_CONTENT:0:100}..."
echo ""

# Test 5: Check result
echo "✓ Checking decryption status..."

if [[ $FIRST_CONTENT == *"Decryption failed"* ]]; then
  echo "  ❌ DECRYPTION FAILED!"
  echo "  Error: $FIRST_CONTENT"
  echo ""
  echo "  Debug: Message is still encrypted on server:"
  echo "  => $FIRST_ENCRYPTED"
  echo ""
  echo "  This means frontend decryption is failing. Check browser console (F12) for logs."
  exit 1
elif [[ $FIRST_CONTENT == "[Encrypted"* ]] || [[ $FIRST_CONTENT == "" ]]; then
  echo "  ⚠️  ENCRYPTED BUT NOT DECRYPTED"
  echo "  The message is encrypted on the server (as expected)"
  echo "  It should decrypt on the frontend"
  echo "  Check browser console (F12 → Console tab) for '[_decrypt]' logs"
  exit 0
else
  echo "  ✅ MESSAGE DECRYPTED SUCCESSFULLY!"
  echo "  Content: $FIRST_CONTENT"
  exit 0
fi
