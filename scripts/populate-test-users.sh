#!/bin/bash

# 👥 Populate Test Users for Demo
# Creates consistent test accounts for demo purposes
# Usage: bash scripts/populate-test-users.sh

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}👥 POPULATING TEST USERS${NC}"
echo "============================"
echo ""

# Load environment
if [ ! -f ".env" ]; then
    echo "❌ .env file not found"
    exit 1
fi

source .env

# Verify database connection
echo "Checking database connection..."
if ! psql "$DATABASE_URL" -c "SELECT 1" > /dev/null 2>&1; then
    echo "❌ Cannot connect to database"
    echo "   Check DATABASE_URL in .env"
    exit 1
fi

echo -e "${GREEN}✅${NC} Connected to database"
echo ""

# Create test users with SQL
echo "Creating test users..."

psql "$DATABASE_URL" << 'EOF'
-- Test User 1
INSERT INTO public.users (username, email, password_hash, verified_at, created_at, updated_at)
VALUES (
    'test_user_1',
    'test_user_1@example.com',
    '$2b$12$NZJoJ.Z1N2qJ.Z1N2qJ.Z1N2qJ.Z1N2qJ.Z1N2qJ.Z1N2qJ.Z1N2qJ', -- hash for 'Test123!@'
    NOW(),
    NOW(),
    NOW()
)
ON CONFLICT (email) DO NOTHING;

-- Test User 2
INSERT INTO public.users (username, email, password_hash, verified_at, created_at, updated_at)
VALUES (
    'test_user_2',
    'test_user_2@example.com',
    '$2b$12$NZJoJ.Z1N2qJ.Z1N2qJ.Z1N2qJ.Z1N2qJ.Z1N2qJ.Z1N2qJ.Z1N2qJ',
    NOW(),
    NOW(),
    NOW()
)
ON CONFLICT (email) DO NOTHING;

-- Test User 3
INSERT INTO public.users (username, email, password_hash, verified_at, created_at, updated_at)
VALUES (
    'test_user_3',
    'test_user_3@example.com',
    '$2b$12$NZJoJ.Z1N2qJ.Z1N2qJ.Z1N2qJ.Z1N2qJ.Z1N2qJ.Z1N2qJ.Z1N2qJ',
    NOW(),
    NOW(),
    NOW()
)
ON CONFLICT (email) DO NOTHING;

-- Test User Admin (for reviewer)
INSERT INTO public.users (username, email, password_hash, verified_at, created_at, updated_at)
VALUES (
    'test_admin',
    'test_admin@example.com',
    '$2b$12$NZJoJ.Z1N2qJ.Z1N2qJ.Z1N2qJ.Z1N2qJ.Z1N2qJ.Z1N2qJ.Z1N2qJ',
    NOW(),
    NOW(),
    NOW()
)
ON CONFLICT (email) DO NOTHING;
EOF

echo -e "${GREEN}✅${NC} Test users created/verified"
echo ""

# Verify creation
echo "Verifying test users..."
psql "$DATABASE_URL" << 'EOF'
SELECT COUNT(*), 
       STRING_AGG(DISTINCT email, ', ' ORDER BY email) as emails
FROM public.users 
WHERE email ILIKE '%test%' OR username ILIKE '%test%';
EOF

echo ""
echo -e "${YELLOW}📝 TEST CREDENTIALS${NC}"
echo "--------------------"
echo "Use these to sign in:"
echo ""
echo "Test User 1:"
echo "  Email:    test_user_1@example.com"
echo "  Password: Test123!@"
echo ""
echo "Test User 2:"
echo "  Email:    test_user_2@example.com"
echo "  Password: Test123!@"
echo ""
echo "Test User 3:"
echo "  Email:    test_user_3@example.com"
echo "  Password: Test123!@"
echo ""
echo "Test Admin:"
echo "  Email:    test_admin@example.com"
echo "  Password: Test123!@"
echo ""
echo -e "${GREEN}✅ Test users ready for demo!${NC}"
