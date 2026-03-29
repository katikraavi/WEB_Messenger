#!/bin/bash

# End-to-End Encryption/Decryption Test with Detailed Logging
# Simulates Alice sending an encrypted message to Bob, then verifies decryption

set -e

API_URL="${API_URL:-https://web-messenger-backend.onrender.com}"
BACKEND_LOG="/tmp/backend.log"

echo "╔════════════════════════════════════════════════════════════╗"
echo "║ END-TO-END ENCRYPTION TEST WITH DECRYPTION VERIFICATION   ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Test credentials
ALICE_EMAIL="alice@example.com"
ALICE_PASSWORD="alice123"
BOB_EMAIL="bob@example.com"
BOB_PASSWORD="bob123"
TEST_MESSAGE="Secret message from Alice to Bob 🔐"

echo "📋 Test Configuration:"
echo "  API URL: $API_URL"
echo "  Alice: $ALICE_EMAIL"
echo "  Bob: $BOB_EMAIL"
echo "  Message: $TEST_MESSAGE"
echo ""

# Step 1: Login Alice
echo "✓ Step 1: Login as Alice..."
ALICE_LOGIN=$(curl -s -X POST "$API_URL/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\": \"$ALICE_EMAIL\", \"password\": \"$ALICE_PASSWORD\"}")

ALICE_TOKEN=$(echo "$ALICE_LOGIN" | jq -r '.token')
ALICE_ID=$(echo "$ALICE_LOGIN" | jq -r '.user.id')

if [ -z "$ALICE_TOKEN" ] || [ "$ALICE_TOKEN" = "null" ]; then
  echo "❌ Failed to login Alice"
  echo "Response: $ALICE_LOGIN"
  exit 1
fi

echo "  Alice ID: $ALICE_ID"
echo "  Token: ${ALICE_TOKEN:0:20}..."
echo ""

# Step 2: Get Bob's user ID
echo "✓ Step 2: Finding Bob's user ID..."
BOB_SEARCH=$(curl -s -X GET "$API_URL/users/search?query=bob" \
  -H "Authorization: Bearer $ALICE_TOKEN")

BOB_ID=$(echo "$BOB_SEARCH" | jq -r '.users[0].id')

if [ -z "$BOB_ID" ] || [ "$BOB_ID" = "null" ]; then
  echo "❌ Failed to find Bob"
  echo "Response: $BOB_SEARCH"
  exit 1
fi

echo "  Bob ID: $BOB_ID"
echo ""

# Step 3: Get or create chat with Bob
echo "✓ Step 3: Creating direct chat with Bob..."
CHATS=$(curl -s -X GET "$API_URL/chats" \
  -H "Authorization: Bearer $ALICE_TOKEN")

# Look for existing direct chat
CHAT_ID=$(echo "$CHATS" | jq -r ".chats[] | select(.type == \"direct\" and .members | map(.id) | contains([\"$BOB_ID\"])) | .id" | head -1)

if [ -z "$CHAT_ID" ] || [ "$CHAT_ID" = "null" ]; then
  echo "  Creating new direct chat..."
  CREATE_CHAT=$(curl -s -X POST "$API_URL/chats" \
    -H "Authorization: Bearer $ALICE_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"name\": \"Encryption Test - Alice & Bob\", \"type\": \"direct\", \"members\": [\"$BOB_ID\"]}")
  
  CHAT_ID=$(echo "$CREATE_CHAT" | jq -r '.chat.id')
fi

echo "  Chat ID: $CHAT_ID"
echo ""

# Step 4: Send encrypted message
echo "✓ Step 4: Sending encrypted message from Alice to Bob..."
SEND_MESSAGE=$(curl -s -X POST "$API_URL/chats/$CHAT_ID/messages" \
  -H "Authorization: Bearer $ALICE_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"content\": \"$TEST_MESSAGE\"}")

MESSAGE_ID=$(echo "$SEND_MESSAGE" | jq -r '.message.id')
ENCRYPTED_CONTENT=$(echo "$SEND_MESSAGE" | jq -r '.message.encrypted_content')
SENDER_ID=$(echo "$SEND_MESSAGE" | jq -r '.message.sender_id')

if [ -z "$MESSAGE_ID" ] || [ "$MESSAGE_ID" = "null" ]; then
  echo "❌ Failed to send message"
  echo "Response: $SEND_MESSAGE"
  exit 1
fi

echo "  Message ID: $MESSAGE_ID"
echo "  Sender ID: $SENDER_ID"
echo "  Encrypted format: ${ENCRYPTED_CONTENT:0:40}..."
echo ""

# Step 5: Analyze encryption format
echo "✓ Step 5: Analyzing encryption format..."
IFS='::' read -r NONCE CT MAC <<< "$ENCRYPTED_CONTENT"

echo "  Parts: 3 (nonce :: ciphertext :: mac)"
echo "  Nonce base64 length: ${#NONCE} chars"
echo "  Ciphertext base64 length: ${#CT} chars"
echo "  MAC base64 length: ${#MAC} chars"

# Calculate decoded sizes
NONCE_BYTES=$(echo -n "$NONCE" | wc -c)
CT_BYTES=$(echo -n "$CT" | wc -c)
MAC_BYTES=$(echo -n "$MAC" | wc -c)

echo "  Nonce decoded size: ~$((NONCE_BYTES * 3 / 4)) bytes (should be 12)"
echo "  Ciphertext decoded size: ~$((CT_BYTES * 3 / 4)) bytes"
echo "  MAC decoded size: ~$((MAC_BYTES * 3 / 4)) bytes (should be 16)"
echo ""

# Step 6: Query message from database
echo "✓ Step 6: Verifying message in database..."
DB_MESSAGE=$(docker exec messenger-postgres \
  psql -U messenger_user -d messenger_db -h localhost -tc \
  "SELECT id, sender_id, encrypted_content, created_at FROM messages WHERE id = '$MESSAGE_ID';")

if [ -z "$DB_MESSAGE" ]; then
  echo "❌ Message not found in database"
  exit 1
fi

echo "  Database entry:"
echo "$DB_MESSAGE" | sed 's/^/    /'
echo ""

# Step 7: Fetch as Bob and check decryption
echo "✓ Step 7: Logging in as Bob to fetch encrypted message..."
BOB_LOGIN=$(curl -s -X POST "$API_URL/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\": \"$BOB_EMAIL\", \"password\": \"$BOB_PASSWORD\"}")

BOB_TOKEN=$(echo "$BOB_LOGIN" | jq -r '.token')

if [ -z "$BOB_TOKEN" ] || [ "$BOB_TOKEN" = "null" ]; then
  echo "❌ Failed to login Bob"
  exit 1
fi

echo "  Bob logged in successfully"
echo ""

# Step 8: Get chat messages as Bob
echo "✓ Step 8: Fetching encrypted message as Bob..."
BOB_MESSAGES=$(curl -s -X GET "$API_URL/chats/$CHAT_ID/messages" \
  -H "Authorization: Bearer $BOB_TOKEN")

BOB_MESSAGE=$(echo "$BOB_MESSAGES" | jq ".messages[] | select(.id == \"$MESSAGE_ID\")")

if [ -z "$BOB_MESSAGE" ] || [ "$BOB_MESSAGE" = "null" ]; then
  echo "❌ Message not found in Bob's chat"
  echo "Response: $BOB_MESSAGES"
  exit 1
fi

echo "  Message retrieved successfully"
echo ""

# Step 9: Check message decryption status
echo "✓ Step 9: Checking message decryption status..."
BOB_MESSAGE_CONTENT=$(echo "$BOB_MESSAGE" | jq -r '.content')
BOB_MESSAGE_ENCRYPTED=$(echo "$BOB_MESSAGE" | jq -r '.encrypted_content')

echo "  Message sender ID (from message): $(echo "$BOB_MESSAGE" | jq -r '.sender_id')"
echo "  Message still encrypted on server: $BOB_MESSAGE_ENCRYPTED"
echo "  Message should decrypt on client to: $TEST_MESSAGE"
echo "  Actual decrypted message: $BOB_MESSAGE_CONTENT"
echo ""

# Step 10: Analyze the result
echo "✓ Step 10: Analysis"
if [[ "$BOB_MESSAGE_CONTENT" == *"Decryption failed"* ]]; then
  echo "  ⚠️  DECRYPTION FAILED!"
  echo "  The message is encrypted but frontend cannot decrypt it"
  echo "  Check browser console (F12 → Console) for [_decrypt] logs"
  echo "  Content: $BOB_MESSAGE_CONTENT"
  exit 1
elif [[ "$BOB_MESSAGE_CONTENT" == "$TEST_MESSAGE" ]]; then
  echo "  ✅ DECRYPTION SUCCESSFUL!"
  echo "  Message encrypted: $ENCRYPTED_CONTENT"
  echo "  Message decrypted: $BOB_MESSAGE_CONTENT"
  exit 0
else
  echo "  ⚠️  UNEXPECTED CONTENT"
  echo "  Expected: $TEST_MESSAGE"
  echo "  Got: $BOB_MESSAGE_CONTENT"
fi

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║ TEST COMPLETE - CHECK RESULTS ABOVE                        ║"
echo "╚════════════════════════════════════════════════════════════╝"
