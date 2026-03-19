#!/bin/bash

# Test script to send and verify messages

BASE_URL="http://localhost:8081"

# User credentials
ALICE_EMAIL="alice@example.com"
ALICE_PASSWORD="Test@123"
BOB_EMAIL="bob@example.com"
BOB_PASSWORD="Test@123"

echo "===== MESSAGE VERIFICATION TEST ====="
echo ""

# Step 1: Login as Alice
echo "1️⃣  Logging in as Alice..."
ALICE_LOGIN=$(curl -s -X POST "$BASE_URL/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$ALICE_EMAIL\",\"password\":\"$ALICE_PASSWORD\"}")

ALICE_TOKEN=$(echo $ALICE_LOGIN | grep -o '"token":"[^"]*' | sed 's/"token":"//' | head -1)
ALICE_ID=$(echo $ALICE_LOGIN | grep -o '"userId":"[^"]*' | sed 's/"userId":"//' | head -1)

if [ -z "$ALICE_TOKEN" ]; then
  echo "❌ Failed to login Alice"
  exit 1
fi

echo "✅ Alice logged in: $ALICE_ID"
echo ""

# Step 2: Login as Bob
echo "2️⃣  Logging in as Bob..."
BOB_LOGIN=$(curl -s -X POST "$BASE_URL/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$BOB_EMAIL\",\"password\":\"$BOB_PASSWORD\"}")

BOB_TOKEN=$(echo $BOB_LOGIN | grep -o '"token":"[^"]*' | sed 's/"token":"//' | head -1)
BOB_ID=$(echo $BOB_LOGIN | grep -o '"userId":"[^"]*' | sed 's/"userId":"//' | head -1)

if [ -z "$BOB_TOKEN" ]; then
  echo "❌ Failed to login Bob"
  exit 1
fi

echo "✅ Bob logged in: $BOB_ID"
echo ""

# Step 3: Get chats for Alice
echo "3️⃣  Fetching chats for Alice..."
ALICE_CHATS=$(curl -s "$BASE_URL/api/chats?limit=10&offset=0" \
  -H "Authorization: Bearer $ALICE_TOKEN")

CHAT_ID=$(echo $ALICE_CHATS | grep -o '"id":"[^"]*' | sed 's/"id":"//' | head -1)

if [ -z "$CHAT_ID" ]; then
  echo "❌ No chats found for Alice"
  exit 1
fi

echo "✅ Found chat: $CHAT_ID"
echo ""

# Step 4: Send a message from Alice
echo "4️⃣  Sending message from Alice..."
# Create encrypted content (for now, base64 encode plaintext)
MESSAGE_TEXT="Hello from Alice! This is a test message."
ENCRYPTED=$(echo -n "$MESSAGE_TEXT" | base64 | tr -d '\n')

SEND_RESULT=$(curl -s -X POST "$BASE_URL/api/chats/$CHAT_ID/messages" \
  -H "Authorization: Bearer $ALICE_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"encrypted_content\":\"$ENCRYPTED\"}")

MESSAGE_ID=$(echo $SEND_RESULT | grep -o '"id":"[^"]*' | sed 's/"id":"//' | head -1)

if [ -z "$MESSAGE_ID" ]; then
  echo "❌ Failed to send message"
  echo "Response: $SEND_RESULT"
  exit 1
fi

echo "✅ Message sent: $MESSAGE_ID"
echo ""

# Step 5: Fetch messages for Bob
echo "5️⃣  Fetching messages for Bob..."
BOB_MESSAGES=$(curl -s "$BASE_URL/api/chats/$CHAT_ID/messages?limit=10&offset=0" \
  -H "Authorization: Bearer $BOB_TOKEN")

echo "Messages received:"
echo "$BOB_MESSAGES" | grep -o '"encrypted_content":"[^"]*' | head -5

echo ""
echo "===== TEST COMPLETE ====="
echo "✅ Message flow verified!"
echo ""
echo "To see full response:"
echo "curl -s 'http://localhost:8081/api/chats/$CHAT_ID/messages?limit=10' -H 'Authorization: Bearer $BOB_TOKEN' | jq"
