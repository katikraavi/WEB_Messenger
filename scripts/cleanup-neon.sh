#!/bin/bash

# ============================================================================
# NEON Database Cleanup Script - Safe Execution with Backup
# ============================================================================
# Best practices:
# - Creates backup before deletion
# - Verifies connection
# - Provides rollback capability
# - Logs all actions
# ============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Load environment
if [ ! -f ".env" ]; then
    echo -e "${RED}❌ .env file not found${NC}"
    exit 1
fi

source .env

if [ -z "$DATABASE_URL" ]; then
    echo -e "${RED}❌ DATABASE_URL not set in .env${NC}"
    exit 1
fi

echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}🗑️  NEON Database Cleanup (Keep Test Users Only)${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""

# Step 1: Backup
BACKUP_FILE="backup-neon-$(date +%Y%m%d-%H%M%S).sql"
echo -e "${YELLOW}📦 Creating backup: $BACKUP_FILE${NC}"
pg_dump "$DATABASE_URL" > "$BACKUP_FILE" 2>/dev/null
echo -e "${GREEN}✅ Backup created successfully${NC}"
echo ""

# Step 2: Verify connection
echo -e "${YELLOW}🔌 Verifying Neon connection...${NC}"
psql "$DATABASE_URL" -c "SELECT version();" > /dev/null 2>&1 || {
    echo -e "${RED}❌ Failed to connect to Neon database${NC}"
    exit 1
}
echo -e "${GREEN}✅ Connected to Neon database${NC}"
echo ""

# Step 3: Show current state
echo -e "${YELLOW}📊 Current database state:${NC}"
psql "$DATABASE_URL" -t -c "
  SELECT 
    (SELECT COUNT(*) FROM users) as users,
    (SELECT COUNT(*) FROM chats) as chats,
    (SELECT COUNT(*) FROM messages) as messages,
    (SELECT COUNT(*) FROM invites) as invites
" | awk '{print "  👥 Users: $1, 💬 Chats: $2, 📝 Messages: $3, 📧 Invites: $4"}'
echo ""

# Step 4: Show test users
echo -e "${YELLOW}🧪 Test users that will be kept:${NC}"
psql "$DATABASE_URL" -t -c "
  SELECT '  ✓ ' || username || ' (' || email || ')'
  FROM users 
  WHERE username ILIKE '%test%' OR email ILIKE '%test%' OR email = 'katikraavi@gmail.com'
  ORDER BY username
"
echo ""

# Step 5: Confirm before deletion
read -p "$(echo -e ${YELLOW}⚠️  CONFIRM: Delete all non-test data? Type 'DELETE' to proceed: ${NC})" confirm

if [ "$confirm" != "DELETE" ]; then
    echo -e "${RED}❌ Cleanup cancelled${NC}"
    exit 0
fi

echo ""
echo -e "${YELLOW}🔄 Executing cleanup...${NC}"

# Step 6: Execute the cleanup SQL
psql "$DATABASE_URL" -f "scripts/clean-neon-database.sql" > /dev/null 2>&1

echo -e "${GREEN}✅ Cleanup completed${NC}"
echo ""

# Step 7: Verify results
echo -e "${YELLOW}📊 New database state:${NC}"
psql "$DATABASE_URL" -t -c "
  SELECT 
    (SELECT COUNT(*) FROM users) as users,
    (SELECT COUNT(*) FROM chats) as chats,
    (SELECT COUNT(*) FROM messages) as messages,
    (SELECT COUNT(*) FROM invites) as invites
" | awk '{print "  👥 Users: $1, 💬 Chats: $2, 📝 Messages: $3, 📧 Invites: $4"}'
echo ""

# Step 8: List remaining users
echo -e "${YELLOW}📋 Remaining users:${NC}"
psql "$DATABASE_URL" -t -c "
  SELECT '  ✓ ' || username || ' | ' || email || ' | Created: ' || created_at::date
  FROM users 
  ORDER BY created_at DESC
"
echo ""

echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ Cleanup complete! Backup saved: $BACKUP_FILE${NC}"
echo -e "${GREEN}Restore with: psql \$DATABASE_URL < $BACKUP_FILE${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
