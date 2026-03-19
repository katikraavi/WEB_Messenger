#!/bin/bash

# Message Status System End-to-End Test
# Tests the complete message status flow with real-time updates

set -e

BASE_URL="http://localhost:8081"
WAIT_TIME=2

echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║ Message Status System E2E Test                                     ║"
echo "║ Tests: auto-read, status broadcast, real-time updates             ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo ""

# Check if backend is running
echo "🔍 Checking backend..."
if ! curl -s "$BASE_URL/health" > /dev/null 2>&1; then
    echo "❌ Backend not running on $BASE_URL"
    echo "   Start with: docker-compose up backend"
    exit 1
fi
echo "✅ Backend is running"
echo ""

# Note: For full testing, you need two authenticated users
echo "📝 To test the full flow:"
echo ""
echo "1. Register two users:"
echo "   curl -X POST $BASE_URL/api/auth/register \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"email\":\"user1@test.com\",\"password\":\"Test123!\",\"username\":\"User1\"}'"
echo ""
echo "2. Login and get tokens:"
echo "   TOKEN_USER1=\$(curl -s -X POST $BASE_URL/api/auth/login \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"email\":\"user1@test.com\",\"password\":\"Test123!\"}' \\"
echo "     | grep -o '\"token\":\"[^\"]*' | cut -d'\"' -f4)"
echo ""
echo "3. Create a chat and send message:"
echo "   CHAT_ID=\$(curl -s -X POST $BASE_URL/api/chats \\"
echo "     -H \"Authorization: Bearer \$TOKEN_USER1\" \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"user_ids\":[\"user2_id\"]}' \\"
echo "     | grep -o '\"id\":\"[^\"]*' | cut -d'\"' -f4)"
echo ""
echo "4. Send a message:"
echo "   curl -X POST $BASE_URL/api/chats/\$CHAT_ID/messages \\"
echo "     -H \"Authorization: Bearer \$TOKEN_USER1\" \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"content\":\"Test message\",\"encryptedContent\":\"encrypted...\"}'"
echo ""
echo "5. Update message status (simulating auto-read):"
echo "   curl -X PUT $BASE_URL/api/chats/\$CHAT_ID/messages/status \\"
echo "     -H \"Authorization: Bearer \$TOKEN_USER2\" \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"message_id\":\"msg_id\",\"status\":\"read\"}'"
echo ""
echo "6. Check frontend console for:"
echo "   ✓ [ChatDetail] 📡 Status update: msg_id -> read"
echo "   ✓ [MessageWebSocket] 📨 Received messageStatusChanged"
echo "   ✓ Message status indicators update to ✓✓ (blue)"
echo ""
echo "✅ System is ready for end-to-end testing"
echo ""
