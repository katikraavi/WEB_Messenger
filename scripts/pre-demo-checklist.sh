#!/bin/bash

# 🎬 Web Messenger - Pre-Demo Checklist
# Run this 5 minutes before demo to verify everything is ready
# Usage: bash scripts/pre-demo-checklist.sh

set -e

echo "🎬 PRE-DEMO CHECKLIST STARTED"
echo "=================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

PASSED=0
FAILED=0

# Function to check a condition
check() {
    local description="$1"
    local command="$2"
    
    if eval "$command" 2>/dev/null; then
        echo -e "${GREEN}✅${NC} $description"
        ((PASSED++))
    else
        echo -e "${RED}❌${NC} $description"
        ((FAILED++))
    fi
}

echo -e "${BLUE}1. SERVICE READINESS${NC}"
check "Backend health endpoint responds" "curl -s http://localhost:8081/health | grep -q 'healthy'"
check "Frontend server running on port 5000" "curl -s http://localhost:5000/ | grep -q 'html' || curl -s -o /dev/null -w '%{http_code}' http://localhost:5000/ | grep -q '200'"
check "PostgreSQL accessible" "docker-compose ps | grep -q 'messenger-postgres.*Up'"

echo ""
echo -e "${BLUE}2. DATABASE STATE${NC}"

# Check if they want to verify test users
if command -v psql &> /dev/null; then
    check "PostgreSQL client available" "which psql"
    
    if [ -f .env ]; then
        source .env 2>/dev/null || true
        if [ ! -z "$DATABASE_URL" ]; then
            CHECK_USERS=$(psql "$DATABASE_URL" -c "SELECT COUNT(*) FROM public.users WHERE email ILIKE '%test%' OR username ILIKE '%test%' OR email = 'katikraavi@gmail.com';" 2>/dev/null || echo "0")
            if [ "$CHECK_USERS" -gt 0 ]; then
                echo -e "${GREEN}✅${NC} Test users present in database ($CHECK_USERS total)"
                ((PASSED++))
            else
                echo -e "${YELLOW}⚠️ ${NC} No test users found - you may need to run database cleanup"
                ((FAILED++))
            fi
        fi
    fi
fi

echo ""
echo -e "${BLUE}3. FRONTEND VERIFICATION${NC}"

# Check for build artifacts
if [ -d "frontend/build/web" ]; then
    echo -e "${GREEN}✅${NC} Flutter web build artifacts present"
    ((PASSED++))
else
    echo -e "${YELLOW}⚠️ ${NC} Web build not found - run: cd frontend && flutter build web"
    ((FAILED++))
fi

echo ""
echo -e "${BLUE}4. ENVIRONMENT VARIABLES${NC}"

# Check .env exists
if [ -f ".env" ]; then
    echo -e "${GREEN}✅${NC} .env configuration file exists"
    ((PASSED++))
    
    # Check critical vars
    source .env 2>/dev/null || true
    [ ! -z "$DATABASE_URL" ] && echo -e "${GREEN}✅${NC} DATABASE_URL configured" && ((PASSED++)) || (echo -e "${RED}❌${NC} DATABASE_URL missing" && ((FAILED++)))
    [ ! -z "$BACKEND_HOST" ] && echo -e "${GREEN}✅${NC} BACKEND_HOST configured" && ((PASSED++)) || (echo -e "${YELLOW}⚠️ ${NC} BACKEND_HOST not set" && ((FAILED++)))
else
    echo -e "${RED}❌${NC} .env file missing"
    ((FAILED++))
fi

echo ""
echo -e "${BLUE}5. DOCKER STATUS${NC}"

RUNNING=$(docker-compose ps 2>/dev/null | grep -c "Up" || echo "0")
if [ "$RUNNING" -ge 2 ]; then
    echo -e "${GREEN}✅${NC} Docker services running ($RUNNING running)"
    ((PASSED++))
    
    # Show which services
    echo "   Services:"
    docker-compose ps 2>/dev/null | grep "Up" | awk '{print "   - " $1 " (" $5 ")"}'
else
    echo -e "${RED}❌${NC} Not enough services running (found $RUNNING)"
    ((FAILED++))
fi

echo ""
echo -e "${BLUE}6. BROWSER PREPARATION${NC}"

echo -e "${YELLOW}📋 MANUAL CHECKS:${NC}"
echo "   [ ] Open Window 1: http://localhost:5000 (Web)"
echo "   [ ] Open Window 2: http://localhost:5000 (Mobile simulator)"
echo "   [ ] Position windows side-by-side for visibility"
echo "   [ ] Open DevTools (F12) in at least one window"
echo ""

echo -e "${BLUE}7. TEST ACCOUNT VERIFICATION${NC}"

if command -v psql &> /dev/null && [ ! -z "$DATABASE_URL" ]; then
    # Get list of test users
    TEST_USERS=$(psql "$DATABASE_URL" -t -c "SELECT DISTINCT email FROM public.users WHERE email ILIKE '%test%' OR username ILIKE '%test%' LIMIT 5;" 2>/dev/null || echo "")
    if [ ! -z "$TEST_USERS" ]; then
        echo "   Available test credentials:"
        echo "$TEST_USERS" | while read email; do
            if [ ! -z "$email" ]; then
                echo "   - Email: $email"
                echo "     Password: (check your setup)"
            fi
        done
        ((PASSED++))
    fi
fi

echo ""
echo "=================================="
echo -e "${BLUE}SUMMARY${NC}"
echo "=================================="
echo -e "${GREEN}✅ Passed: $PASSED${NC}"
echo -e "${RED}❌ Failed: $FAILED${NC}"

if [ "$FAILED" -eq 0 ]; then
    echo ""
    echo -e "${GREEN}🚀 ALL CHECKS PASSED - READY FOR DEMO!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Open http://localhost:5000 in two browser windows"
    echo "2. Sign in with same test account in both"
    echo "3. Follow REVIEWER_DEMO_GUIDE.md for demo script"
    echo ""
    exit 0
else
    echo ""
    echo -e "${RED}⚠️  SOME CHECKS FAILED - PLEASE FIX BEFORE DEMO${NC}"
    echo ""
    echo "Troubleshooting:"
    echo "1. Services not running? Use: ./start.sh"
    echo "2. No test users? Use: ./scripts/populate-test-users.sh"
    echo "3. Build missing? Use: cd frontend && flutter build web"
    echo ""
    exit 1
fi
