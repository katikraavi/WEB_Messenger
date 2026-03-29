#!/bin/bash

# Decryption debugging test - shows what's being decrypted and why it fails

API_URL="${API_URL:-https://web-messenger-backend.onrender.com}"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}=== DECRYPTION DEBUGGING TEST ===${NC}\n"

# 1. Login
echo -e "${YELLOW}1. Logging in as Alice...${NC}"
ALICE_LOGIN=$(curl -s -X POST "${API_URL}/auth/login" \
    -H "Content-Type: application/json" \
    -d '{"email": "alice@example.com", "password": "alice123"}')

ALICE_TOKEN=$(echo "$ALICE_LOGIN" | python3 -m json.tool 2>/dev/null | grep '"token"' | head -1 | cut -d'"' -f4 || echo "$ALICE_LOGIN" | grep -o '"token":"[^"]*' | head -1 | cut -d'"' -f4)
ALICE_ID=$(echo "$ALICE_LOGIN" | python3 -m json.tool 2>/dev/null | grep '"user_id"' | head -1 | cut -d'"' -f4 || echo "$ALICE_LOGIN" | grep -o '"user_id":"[^"]*' | head -1 | cut -d'"' -f4)

echo -e "${GREEN}✓ Alice logged in${NC}"
echo -e "  Token: ${ALICE_TOKEN:0:30}..."
echo -e "  User ID: $ALICE_ID\n"

# 2. Get Alice's chats
echo -e "${YELLOW}2. Fetching Alice's chats and messages...${NC}"
CHATS=$(curl -s -X GET "${API_URL}/api/chats" \
    -H "Authorization: Bearer $ALICE_TOKEN")

CHAT_ID=$(echo "$CHATS" | python3 -m json.tool 2>/dev/null | grep '"chatId"' | head -1 | cut -d'"' -f4 || echo "$CHATS" | grep -o '"chatId":"[^"]*' | head -1 | cut -d'"' -f4)

if [ -z "$CHAT_ID" ]; then
    # Try id instead of chatId
    CHAT_ID=$(echo "$CHATS" | python3 -m json.tool 2>/dev/null | grep '"id"' | head -1 | cut -d'"' -f4 | grep -v "user_id" || echo "$CHATS" | grep -o '"id":"[^"]*' | head -1 | cut -d'"' -f4)
fi

if [ -z "$CHAT_ID" ]; then
    echo -e "${RED}✗ No chats found${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Found chat: $CHAT_ID${NC}\n"

# 3. Get messages from chat
echo -e "${YELLOW}3. Fetching messages from chat...${NC}"
MESSAGES=$(curl -s -X GET "${API_URL}/api/chats/${CHAT_ID}/messages?limit=5" \
    -H "Authorization: Bearer $ALICE_TOKEN")

# Extract first message details
MSG_ID=$(echo "$MESSAGES" | python3 -m json.tool 2>/dev/null | grep '"id"' | head -2 | tail -1 | cut -d'"' -f4)
SENDER_ID=$(echo "$MESSAGES" | python3 -m json.tool 2>/dev/null | grep '"sender_id"' | head -1 | cut -d'"' -f4)
ENCRYPTED_CONTENT=$(echo "$MESSAGES" | python3 -m json.tool 2>/dev/null | grep '"encrypted_content"' | head -1 | cut -d'"' -f4)
DECRYPTED_CONTENT=$(echo "$MESSAGES" | python3 -m json.tool 2>/dev/null | grep '"decrypted_content"' | head -1 | cut -d'"' -f4)

if [ -z "$MSG_ID" ]; then
    echo -e "${RED}✗ No messages found${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Message found: $MSG_ID${NC}"
echo -e "  Sender ID: $SENDER_ID"
echo -e "  Current User ID: $ALICE_ID"
echo ""

# 4. Analyze encryption format
echo -e "${YELLOW}4. Analyzing encrypted content format...${NC}"
if [ -n "$ENCRYPTED_CONTENT" ] && [ "$ENCRYPTED_CONTENT" != "null" ]; then
    echo -e "${GREEN}✓ Encrypted content present${NC}"
    
    # Count colons (should have 2 for format: nonce::ciphertext::mac)
    COLON_COUNT=$(echo "$ENCRYPTED_CONTENT" | grep -o '::' | wc -l)
    echo -e "  Format parts (::): $COLON_COUNT (expected: 2)"
    
    # Get each part
    IFS='::' read -ra PARTS <<< "$ENCRYPTED_CONTENT"
    NONCE="${PARTS[0]}"
    CIPHERTEXT="${PARTS[1]}"
    MAC="${PARTS[2]}"
    
    echo -e "  Nonce length: ${#NONCE}"
    echo -e "  Ciphertext length: ${#CIPHERTEXT}"
    echo -e "  MAC length: ${#MAC}"
    
    if [ $COLON_COUNT -ne 2 ]; then
        echo -e "${RED}✗ Invalid format! Expected 3 parts, got $((COLON_COUNT+1))${NC}"
    fi
else
    echo -e "${RED}✗ No encrypted content${NC}"
fi
echo ""

# 5. Check decrypted content
echo -e "${YELLOW}5. Checking decrypted content from backend...${NC}"
if [ -n "$DECRYPTED_CONTENT" ] && [ "$DECRYPTED_CONTENT" != "null" ]; then
    if [[ "$DECRYPTED_CONTENT" == "Decryption failed"* ]]; then
        echo -e "${RED}✗ Backend decryption failed${NC}"
        echo -e "  Error: $DECRYPTED_CONTENT"
    else
        echo -e "${GREEN}✓ Decrypted content: $DECRYPTED_CONTENT${NC}"
    fi
else
    echo -e "${YELLOW}⚠ No decrypted content (expected - decryption happens on frontend)${NC}"
fi
echo ""

# 6. Print full message for manual analysis
echo -e "${CYAN}=== FULL MESSAGE DETAILS ===${NC}"
echo "$MESSAGES" | python3 -m json.tool 2>/dev/null | head -50

echo -e "\n${CYAN}=== ENCRYPTION FORMAT BREAKDOWN ===${NC}"
echo -e "To decrypt manually, frontend needs:"
echo -e "  • Master key: ${GREEN}(same as backend ENCRYPTION_MASTER_KEY)${NC}"
echo -e "  • Sender ID for key derivation: ${GREEN}$SENDER_ID${NC}"
echo -e "  • Encrypted message in format: ${GREEN}nonce::ciphertext::mac${NC}"
echo -e "  • All parts are base64-encoded"
echo ""

# 7. Test key derivation match
echo -e "${CYAN}=== KEY DERIVATION TEST ===${NC}"
echo -e "Frontend and backend should derive SAME key:"
echo -e "  Key = HMAC-SHA256(master_key, sender_id)"
echo -e "  Sender ID: $SENDER_ID"
echo -e "  If keys don't match → decryption fails with MAC error"
echo ""

echo -e "${GREEN}✓ Test complete. Check above for decryption issues.${NC}"
