#!/bin/bash
# Quick database cleanup script
# Usage: ./clean.sh [all|email <email>|unverified|count|list]

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Database config
DB_HOST="localhost"
DB_PORT="5432"
DB_NAME="messenger_db"
DB_USER="messenger_user"
DB_PASS="messenger_password"

# PostgreSQL connection
PG_CONNECT="postgresql://$DB_USER:$DB_PASS@$DB_HOST:$DB_PORT/$DB_NAME"

print_header() {
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║        Database Account Cleanup Script              ║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════╝${NC}\n"
}

print_usage() {
    echo -e "${YELLOW}USAGE:${NC}
  ./clean.sh <command> [options]

${YELLOW}COMMANDS:${NC}
  ${GREEN}all${NC}              Delete all accounts and reset ID sequence
  ${GREEN}email <email>${NC}    Delete specific account by email
  ${GREEN}unverified${NC}       Delete all unverified accounts only
  ${GREEN}count${NC}            Show total account count
  ${GREEN}list${NC}             List all accounts with details
  ${GREEN}help${NC}             Show this help message

${YELLOW}EXAMPLES:${NC}
  ./clean.sh all
  ./clean.sh email test@example.com
  ./clean.sh unverified
  ./clean.sh count
  ./clean.sh list
"
}

delete_all() {
    echo -e "${YELLOW}[INFO]${NC} Deleting all accounts...\n"
    
    PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" << EOF
SELECT COUNT(*) as accounts_deleted FROM users;
DELETE FROM users;
ALTER SEQUENCE users_id_seq RESTART WITH 1;
\echo ''
SELECT '✓ Deleted all accounts' as result;
SELECT '✓ Reset ID sequence to 1' as result;
EOF
}

delete_by_email() {
    local email="$1"
    echo -e "${YELLOW}[INFO]${NC} Deleting account: $email\n"
    
    PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c \
        "DELETE FROM users WHERE email = '$email'; SELECT '✓ Deleted account: $email' as result;"
}

delete_unverified() {
    echo -e "${YELLOW}[INFO]${NC} Deleting unverified accounts...\n"
    
    PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" << EOF
SELECT COUNT(*), 'unverified accounts found' FROM users WHERE email_verified = false;
DELETE FROM users WHERE email_verified = false;
\echo ''
SELECT '✓ Cleanup completed' as result;
EOF
}

show_count() {
    echo -e "${YELLOW}[INFO]${NC} Current account count:\n"
    
    PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" << EOF
SELECT COUNT(*) as total_accounts FROM users;
SELECT COUNT(*) as verified_accounts FROM users WHERE email_verified = true;
SELECT COUNT(*) as unverified_accounts FROM users WHERE email_verified = false;
EOF
}

list_accounts() {
    echo -e "${YELLOW}[INFO]${NC} All accounts:\n"
    
    PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c \
        "SELECT id, email, username, CASE WHEN email_verified = true THEN 'Verified' ELSE 'Pending' END as status, created_at FROM users ORDER BY created_at DESC;"
}

# Main logic
print_header

if [ -z "$1" ]; then
    print_usage
    exit 0
fi

case "$1" in
    all)
        delete_all
        ;;
    email)
        if [ -z "$2" ]; then
            echo -e "${RED}❌ Error: Email required${NC}"
            echo "Usage: ./clean.sh email <email>"
            exit 1
        fi
        delete_by_email "$2"
        ;;
    unverified)
        delete_unverified
        ;;
    count)
        show_count
        ;;
    list)
        list_accounts
        ;;
    help)
        print_usage
        ;;
    *)
        echo -e "${RED}❌ Unknown command: $1${NC}"
        print_usage
        exit 1
        ;;
esac

echo ""
