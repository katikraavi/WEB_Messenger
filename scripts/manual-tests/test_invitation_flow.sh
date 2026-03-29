#!/bin/bash

# Test Invitation Flow
# This script tests the complete invitation system:
# 1. Alice sends invitation to Bob
# 2. Bob fetches pending invitations
# 3. Bob accepts the invitation
# 4. Verify status changes to accepted

set -e

BASE_URL="${BASE_URL:-https://web-messenger-backend.onrender.com}"
ALICE_ID="bfd3a96a-ab36-442c-9b4e-276050b87678"
BOB_ID="b8465fd4-56e0-4f97-9a4f-9e2cb862d444"
ALICE_TOKEN="alice_token"
BOB_TOKEN="bob_token"

echo "================================================================"
echo "Testing Invitation System Flow"
echo "================================================================"
echo ""

# Step 1: Alice sends invitation to Bob
echo "STEP 1: Alice sends invitation to Bob"
echo "Request: POST /api/invites"
echo "Body: {\"recipient_id\": \"$BOB_ID\"}"
echo ""

SEND_RESPONSE=$(curl -s -X POST "$BASE_URL/api/invites" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ALICE_TOKEN" \
  -d "{\"recipient_id\": \"$BOB_ID\"}")

echo "Response:"
echo "$SEND_RESPONSE" | jq . 2>/dev/null || echo "$SEND_RESPONSE"
echo ""

INVITE_ID=$(echo "$SEND_RESPONSE" | jq -r '.id' 2>/dev/null || echo "")
echo "Invitation ID: $INVITE_ID"
echo ""

# Step 2: Bob fetches pending invitations
echo "================================================================"
echo "STEP 2: Bob fetches pending invitations"
echo "Request: GET /api/users/$BOB_ID/invites/pending"
echo ""

PENDING_RESPONSE=$(curl -s -X GET "$BASE_URL/api/users/$BOB_ID/invites/pending" \
  -H "Authorization: Bearer $BOB_TOKEN")

echo "Response:"
echo "$PENDING_RESPONSE" | jq . 2>/dev/null || echo "$PENDING_RESPONSE"
echo ""

PENDING_COUNT=$(echo "$PENDING_RESPONSE" | jq 'length' 2>/dev/null || echo "?")
echo "Bob has $PENDING_COUNT pending invitation(s)"
echo ""

# Step 3: Check that invitation status is 'pending'
if [ -n "$INVITE_ID" ] && [ "$INVITE_ID" != "null" ]; then
  echo "================================================================"
  echo "STEP 3: Verify invitation status is 'pending'"
  
  INVITE_IN_PENDING=$(echo "$PENDING_RESPONSE" | jq ".[] | select(.id == \"$INVITE_ID\")" 2>/dev/null || echo "")
  
  if [ -n "$INVITE_IN_PENDING" ]; then
    STATUS=$(echo "$INVITE_IN_PENDING" | jq -r '.status' 2>/dev/null || echo "?")
    echo "✅ Invitation found in Bob's pending list with status: $STATUS"
    echo ""
  else
    echo "❌ Invitation NOT found in Bob's pending list!"
    echo ""
  fi
  
  # Step 4: Bob accepts the invitation
  echo "================================================================"
  echo "STEP 4: Bob accepts the invitation"
  echo "Request: POST /api/invites/$INVITE_ID/accept"
  echo ""
  
  ACCEPT_RESPONSE=$(curl -s -X POST "$BASE_URL/api/invites/$INVITE_ID/accept" \
    -H "Authorization: Bearer $BOB_TOKEN")
  
  echo "Response:"
  echo "$ACCEPT_RESPONSE" | jq . 2>/dev/null || echo "$ACCEPT_RESPONSE"
  echo ""
  
  FINAL_STATUS=$(echo "$ACCEPT_RESPONSE" | jq -r '.status' 2>/dev/null || echo "?")
  
  if [ "$FINAL_STATUS" = "accepted" ]; then
    echo "✅ Invitation successfully accepted! Status: $FINAL_STATUS"
  else
    echo "❌ Invitation status is still: $FINAL_STATUS (expected: accepted)"
  fi
else
  echo "❌ Could not get invitation ID from send response"
fi

echo ""
echo "================================================================"
echo "STEP 5: Alice checks sent invitations"
echo "Request: GET /api/users/$ALICE_ID/invites/sent"
echo ""

SENT_RESPONSE=$(curl -s -X GET "$BASE_URL/api/users/$ALICE_ID/invites/sent" \
  -H "Authorization: Bearer $ALICE_TOKEN")

echo "Response (showing first 2 items):"
echo "$SENT_RESPONSE" | jq '.[0:2]' 2>/dev/null || echo "$SENT_RESPONSE"
SENT_COUNT=$(echo "$SENT_RESPONSE" | jq 'length' 2>/dev/null || echo "?")
echo "Alice has $SENT_COUNT sent invitation(s)"
echo ""

echo "================================================================"
echo "Test Complete!"
echo "================================================================"
