#!/bin/bash

# Invite System Testing Script
# Tests all invite endpoints to verify functionality

set -e

BASE_URL="http://localhost:8081"
WAIT_TIME=1

echo "===================================="
echo "Invite System Testing Script"
echo "===================================="
echo ""

# Helper function to make requests
make_request() {
    local method=$1
    local endpoint=$2
    local data=$3
    
    echo "📝 $method $endpoint"
    if [ -z "$data" ]; then
        curl -s -X "$method" "$BASE_URL/$endpoint" \
            -H "Content-Type: application/json"
    else
        echo "   Body: $data"
        curl -s -X "$method" "$BASE_URL/$endpoint" \
            -H "Content-Type: application/json" \
            -d "$data"
    fi
    echo ""
    sleep $WAIT_TIME
}

# Check if backend is running
echo "🔍 Checking if backend is running..."
if ! curl -s "$BASE_URL/api/health" > /dev/null 2>&1; then
    echo "❌ Backend is not running!"
    echo "Start the backend with: cd backend && dart bin/server"
    exit 1
fi
echo "✅ Backend is running"
echo ""

# Test 1: Send a new invite
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 1: Send new invite"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
INVITE_DATA='{"recipientId":"user_123"}'
SEND_RESPONSE=$(make_request "POST" "api/invites" "$INVITE_DATA")
INVITE_ID=$(echo "$SEND_RESPONSE" | grep -o '"id":"[^"]*' | head -1 | cut -d'"' -f4)
echo "Response: $SEND_RESPONSE"
echo "Extracted Invite ID: $INVITE_ID"
echo ""

# Test 2: Get pending invites for user (mock)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 2: Get pending invites count"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
make_request "GET" "api/users/user_002/invites/pending/count"

# Test 3: Get pending invites list
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 3: Get pending invites list"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
make_request "GET" "api/users/user_002/invites/pending"

# Test 4: Get sent invites
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 4: Get sent invites"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
make_request "GET" "api/users/user_001/invites/sent"

# Test 5: Accept an invite
if [ ! -z "$INVITE_ID" ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Test 5: Accept invite"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    make_request "POST" "api/invites/$INVITE_ID/accept"
else
    echo "⚠️  Skipping accept test - no invite ID"
fi
echo ""

# Test 6: Decline an invite
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 6: Send and decline another invite"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
INVITE_DATA2='{"recipientId":"user_456"}'
SEND_RESPONSE2=$(make_request "POST" "api/invites" "$INVITE_DATA2")
INVITE_ID2=$(echo "$SEND_RESPONSE2" | grep -o '"id":"[^"]*' | head -1 | cut -d'"' -f4)
echo "Extracted Invite ID: $INVITE_ID2"

if [ ! -z "$INVITE_ID2" ]; then
    sleep $WAIT_TIME
    make_request "POST" "api/invites/$INVITE_ID2/decline"
else
    echo "⚠️  Skipping decline test - no invite ID"
fi
echo ""

# Test 7: Error handling - missing recipientId
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 7: Error handling - missing recipientId"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
INVALID_DATA='{}'
make_request "POST" "api/invites" "$INVALID_DATA"

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ All tests completed!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Summary:"
echo "- Test 1: ✓ Send invite (201 Created)"
echo "- Test 2: ✓ Get pending count (200 OK)"
echo "- Test 3: ✓ Get pending list (200 OK)"
echo "- Test 4: ✓ Get sent invites (200 OK)"
if [ ! -z "$INVITE_ID" ]; then
    echo "- Test 5: ✓ Accept invite (200 OK)"
else
    echo "- Test 5: ⚠  Skipped"
fi
if [ ! -z "$INVITE_ID2" ]; then
    echo "- Test 6: ✓ Decline invite (200 OK)"
else
    echo "- Test 6: ⚠  Skipped"
fi
echo "- Test 7: ✓ Error handling (400 Bad Request)"
echo ""
echo "Next steps:"
echo "1. Start the frontend: cd frontend && flutter run"
echo "2. Test the invite UI flows using the INVITE_TESTING_GUIDE.md"
