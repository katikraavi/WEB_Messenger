#!/bin/bash

# Test password reset flow with allowed email

echo "🔐 PASSWORD RESET FLOW TEST (With Allowed Email)"
echo "=================================================="
echo ""

# Use allowed email for testing
TEST_EMAIL="kati.kraavi@gmail.com"
TEST_USERNAME="testuser_$(date +%s)"
TEST_PASSWORD="InitialPass123!"
NEW_PASSWORD="NewPass456!"

echo "📧 Step 1: Request password reset for allowed email"
echo "Email: $TEST_EMAIL"
echo ""

RESET_REQUEST=$(curl -s -X POST http://localhost:8081/api/auth/password-reset/request \
  -H "Content-Type: application/json" \
  -d "{\"email\": \"$TEST_EMAIL\"}")

echo "Reset Request Response:"
echo "$RESET_REQUEST" | jq '.' 2>/dev/null || echo "$RESET_REQUEST"
echo ""

# Extract dev token if available
DEV_TOKEN=$(echo "$RESET_REQUEST" | jq -r '.token // empty' 2>/dev/null)

if [ -n "$DEV_TOKEN" ]; then
  echo "✅ Dev Token found!"
  echo "Token: $DEV_TOKEN"
  echo ""
  
  echo "🔄 Step 2: Confirm password reset with token"
  echo "New Password: $NEW_PASSWORD"
  echo ""
  
  RESET_CONFIRM=$(curl -s -X POST http://localhost:8081/api/auth/password-reset/confirm \
    -H "Content-Type: application/json" \
    -d "{
      \"token\": \"$DEV_TOKEN\",
      \"newPassword\": \"$NEW_PASSWORD\"
    }")
  
  echo "Reset Confirm Response:"
  echo "$RESET_CONFIRM" | jq '.' 2>/dev/null || echo "$RESET_CONFIRM"
  echo ""
  
  RESET_SUCCESS=$(echo "$RESET_CONFIRM" | jq '.success' 2>/dev/null)
  
  if [ "$RESET_SUCCESS" = "true" ]; then
    echo "✅ Password reset confirmed!"
    echo ""
    echo "🔐 Step 3: Test login with NEW password"
    
    LOGIN_NEW=$(curl -s -X POST http://localhost:8081/api/auth/login \
      -H "Content-Type: application/json" \
      -d "{
        \"email\": \"$TEST_EMAIL\",
        \"password\": \"$NEW_PASSWORD\"
      }")
    
    LOGIN_SUCCESS=$(echo "$LOGIN_NEW" | jq '.success // false' 2>/dev/null)
    
    if [ "$LOGIN_SUCCESS" = "true" ]; then
      echo "✅ LOGIN SUCCESSFUL WITH NEW PASSWORD!"
      echo ""
      echo "========================================="
      echo "✅ PASSWORD RESET IS WORKING ✅"
      echo "========================================="
      TOKEN=$(echo "$LOGIN_NEW" | jq -r '.data.token' 2>/dev/null)
      if [ -n "$TOKEN" ]; then
        echo ""
        echo "Auth Token: ${TOKEN:0:40}..."
      fi
    else
      echo "❌ Login failed with new password"
      echo "$LOGIN_NEW" | jq '.' 2>/dev/null || echo "$LOGIN_NEW"
    fi
  else
    echo "❌ Password reset confirmation failed"
    echo "$RESET_CONFIRM" | jq '.error' 2>/dev/null || echo "$RESET_CONFIRM"
  fi
else
  echo "⚠️  No dev token in response"
  echo "Email sending may have failed. Check backend logs."
  echo ""
  echo "Full response:"
  echo "$RESET_REQUEST" | jq '.' 2>/dev/null || echo "$RESET_REQUEST"
fi

echo ""
echo "=================================================="
