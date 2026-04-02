#!/bin/bash

# Test password reset flow end-to-end

echo "🔐 PASSWORD RESET FLOW TEST"
echo "============================"
echo ""

# Test email
TEST_EMAIL="test.reset.$(date +%s)@example.com"
TEST_USERNAME="testuser_$(date +%s)"
TEST_PASSWORD="InitialPass123!"
NEW_PASSWORD="NewPass456!"

echo "📝 Step 1: Register new account"
echo "Email: $TEST_EMAIL"
echo "Username: $TEST_USERNAME"
echo "Password: $TEST_PASSWORD"
echo ""

# Register
REGISTER_RESPONSE=$(curl -s -X POST http://localhost:8081/api/auth/register \
  -H "Content-Type: application/json" \
  -d "{
    \"email\": \"$TEST_EMAIL\",
    \"username\": \"$TEST_USERNAME\",
    \"password\": \"$TEST_PASSWORD\",
    \"fullName\": \"Test User\"
  }")

echo "Registration Response:"
echo "$REGISTER_RESPONSE" | jq '.' 2>/dev/null || echo "$REGISTER_RESPONSE"
echo ""

# Extract user ID if available
USER_ID=$(echo "$REGISTER_RESPONSE" | jq -r '.data.user.user_id // empty' 2>/dev/null)

echo "📧 Step 2: Request password reset"
RESET_REQUEST=$(curl -s -X POST http://localhost:8081/api/auth/password-reset/request \
  -H "Content-Type: application/json" \
  -d "{\"email\": \"$TEST_EMAIL\"}")

echo "Reset Request Response:"
echo "$RESET_REQUEST" | jq '.' 2>/dev/null || echo "$RESET_REQUEST"
echo ""

# Extract dev token if in development mode
DEV_TOKEN=$(echo "$RESET_REQUEST" | jq -r '.token // empty' 2>/dev/null)
if [ -n "$DEV_TOKEN" ]; then
  echo "✅ Dev Token Found: $DEV_TOKEN"
  echo ""
  
  echo "🔄 Step 3: Confirm password reset with token"
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
    echo "✅ Password reset successful!"
    echo ""
    echo "🔐 Step 4: Test login with OLD password (should fail)"
    LOGIN_OLD=$(curl -s -X POST http://localhost:8081/api/auth/login \
      -H "Content-Type: application/json" \
      -d "{
        \"email\": \"$TEST_EMAIL\",
        \"password\": \"$TEST_PASSWORD\"
      }")
    
    LOGIN_OLD_SUCCESS=$(echo "$LOGIN_OLD" | jq '.success // false' 2>/dev/null)
    if [ "$LOGIN_OLD_SUCCESS" = "false" ]; then
      echo "✅ OLD password correctly rejected"
      echo "$LOGIN_OLD" | jq '.error' 2>/dev/null | head -1
    else
      echo "❌ OLD password still works (BUG!)"
    fi
    echo ""
    
    echo "🔐 Step 5: Test login with NEW password (should succeed)"
    LOGIN_NEW=$(curl -s -X POST http://localhost:8081/api/auth/login \
      -H "Content-Type: application/json" \
      -d "{
        \"email\": \"$TEST_EMAIL\",
        \"password\": \"$NEW_PASSWORD\"
      }")
    
    LOGIN_NEW_SUCCESS=$(echo "$LOGIN_NEW" | jq '.success // false' 2>/dev/null)
    if [ "$LOGIN_NEW_SUCCESS" = "true" ]; then
      echo "✅ NEW password works correctly!"
      echo "✅ Password reset is WORKING ✅"
      TOKEN=$(echo "$LOGIN_NEW" | jq -r '.data.token' 2>/dev/null)
      if [ -n "$TOKEN" ]; then
        echo ""
        echo "Auth Token: ${TOKEN:0:30}..."
      fi
    else
      echo "❌ NEW password doesn't work (BUG - hashing mismatch)"
      echo "$LOGIN_NEW" | jq '.' 2>/dev/null || echo "$LOGIN_NEW"
    fi
  else
    echo "❌ Password reset failed"
    echo "$RESET_CONFIRM" | jq '.error' 2>/dev/null
  fi
else
  echo "⚠️  No dev token found - check if backend is in development mode"
  echo "Full response: $RESET_REQUEST"
fi

echo ""
echo "============================"
echo "TEST COMPLETE"
