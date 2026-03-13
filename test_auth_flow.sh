#!/bin/bash

# Comprehensive auth flow testing script
# Tests registration, login, errors, and edge cases

BASE_URL="http://localhost:8081"
ERRORS=0
PASSED=0

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=====================================${NC}"
echo -e "${YELLOW}Auth Flow Testing Suite${NC}"
echo -e "${YELLOW}=====================================${NC}"

# Helper function to test endpoint
test_endpoint() {
  local test_name=$1
  local method=$2
  local endpoint=$3
  local data=$4
  local expected_status=$5
  local headers=$6

  echo -ne "Testing: $test_name... "

  local response=$(curl -s -w "\n%{http_code}" -X "$method" \
    "$BASE_URL$endpoint" \
    -H "Content-Type: application/json" \
    ${headers:+-H "$headers"} \
    ${data:+-d "$data"})

  local status=$(echo "$response" | tail -n1)
  local body=$(echo "$response" | sed '$d')

  if [ "$status" = "$expected_status" ]; then
    echo -e "${GREEN}PASS${NC} (HTTP $status)"
    PASSED=$((PASSED + 1))
    echo "$body"
  else
    echo -e "${RED}FAIL${NC} (Expected $expected_status, got $status)"
    ERRORS=$((ERRORS + 1))
    echo "Response: $body"
  fi
  echo ""
}

# Test 1: Login with valid credentials (existing mock user)
test_endpoint \
  "Login with valid credentials (alice)" \
  "POST" \
  "/auth/login" \
  '{"email":"alice@example.com","password":"password123"}' \
  "200"

# Test 2: Login with invalid email
test_endpoint \
  "Login with invalid email" \
  "POST" \
  "/auth/login" \
  '{"email":"nonexistent@example.com","password":"password123"}' \
  "401"

# Test 3: Login with wrong password
test_endpoint \
  "Login with wrong password" \
  "POST" \
  "/auth/login" \
  '{"email":"alice@example.com","password":"wrongpassword"}' \
  "401"

# Test 4: Login with missing email
test_endpoint \
  "Login with missing email" \
  "POST" \
  "/auth/login" \
  '{"password":"password123"}' \
  "400"

# Test 5: Login with missing password
test_endpoint \
  "Login with missing password" \
  "POST" \
  "/auth/login" \
  '{"email":"alice@example.com"}' \
  "400"

# Test 6: Login with empty email
test_endpoint \
  "Login with empty email" \
  "POST" \
  "/auth/login" \
  '{"email":"","password":"password123"}' \
  "400"

# Test 7: Register new user (success)
test_endpoint \
  "Register new user (success)" \
  "POST" \
  "/auth/register" \
  '{"email":"newuser@example.com","username":"newuser","password":"ValidPass123!","full_name":"New User"}' \
  "201"

# Test 8: Register with duplicate email
test_endpoint \
  "Register with duplicate email" \
  "POST" \
  "/auth/register" \
  '{"email":"alice@example.com","username":"alicenew","password":"ValidPass123!"}' \
  "409"

# Test 9: Register with duplicate username
test_endpoint \
  "Register with duplicate username" \
  "POST" \
  "/auth/register" \
  '{"email":"newemail@example.com","username":"alice","password":"ValidPass123!"}' \
  "409"

# Test 10: Register with weak password
test_endpoint \
  "Register with weak password (< 8 chars)" \
  "POST" \
  "/auth/register" \
  '{"email":"weakpass@example.com","username":"weakpass","password":"pass123"}' \
  "400"

# Test 11: Register missing required fields
test_endpoint \
  "Register missing email" \
  "POST" \
  "/auth/register" \
  '{"username":"testuser","password":"ValidPass123!"}' \
  "400"

# Test 12: Login new registered user with correct credentials
test_endpoint \
  "Login newly registered user" \
  "POST" \
  "/auth/login" \
  '{"email":"newuser@example.com","password":"ValidPass123!"}' \
  "200"

# Test 13: Search functionality (verify auth token works)
VALID_TOKEN="eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoidXNlci0xMjMtYWJjIiwiZW1haWwiOiJ0ZXN0QGV4YW1wbGUuY29tIiwiaWF0IjoxNjI2MDAwMDAwLCJleHAiOjE2MjczMzYwMDB9.test_signature"

test_endpoint \
  "Search by username with valid token" \
  "GET" \
  "/search/username?q=alice" \
  "" \
  "200" \
  "Authorization: Bearer $VALID_TOKEN"

# Test 14: Search without auth token
test_endpoint \
  "Search by username without auth token" \
  "GET" \
  "/search/username?q=alice" \
  "" \
  "403"

# Test 15: Health check
test_endpoint \
  "Health check endpoint" \
  "GET" \
  "/health" \
  "" \
  "200"

echo -e "${YELLOW}=====================================${NC}"
echo -e "${YELLOW}Test Summary${NC}"
echo -e "${YELLOW}=====================================${NC}"
echo -e "Passed: ${GREEN}$PASSED${NC}"
echo -e "Failed: ${RED}$ERRORS${NC}"
echo -e "${YELLOW}=====================================${NC}"

if [ $ERRORS -eq 0 ]; then
  echo -e "${GREEN}✓ All tests passed!${NC}"
  exit 0
else
  echo -e "${RED}✗ Some tests failed!${NC}"
  exit 1
fi
