#!/bin/bash

# Environment Variable Validator
# Validates required and recommended environment variables

ENV_FILE="${1:-.env}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

REQUIRED_PASSED=0
REQUIRED_FAILED=0

log_pass() { echo -e "${GREEN}✓${NC} $1"; }
log_fail() { echo -e "${RED}✗${NC} $1"; }

check_var() {
  local var_name=$1
  local desc=$2
  local value=$(grep "^${var_name}=" "$ENV_FILE" 2>/dev/null | cut -d'=' -f2-)
  
  if [[ -z "$value" ]]; then
    log_fail "$var_name - $desc"
    ((REQUIRED_FAILED++))
  else
    log_pass "$var_name"
    ((REQUIRED_PASSED++))
  fi
}

main() {
  if [[ ! -f "$ENV_FILE" ]]; then
    echo -e "${RED}✗ File not found: $ENV_FILE${NC}"
    exit 1
  fi
  
  echo -e "${BLUE}Validating: $ENV_FILE${NC}"
  echo
  echo -e "${BLUE}━━━ REQUIRED VARIABLES ━━━${NC}"
  
  check_var "DATABASE_HOST" "database hostname"
  check_var "DATABASE_PORT" "database port"
  check_var "DATABASE_NAME" "database name"
  check_var "DATABASE_USER" "database user"
  check_var "ENCRYPTION_MASTER_KEY" "encryption key (64-char hex)"
  check_var "SERVERPOD_PORT" "backend port"
  
  echo
  echo -e "${BLUE}━━━ RESULT ━━━${NC}"
  if [[ $REQUIRED_FAILED -eq 0 ]]; then
    echo -e "${GREEN}✓ All required variables are set!${NC}"
    exit 0
  else
    echo -e "${RED}✗ $REQUIRED_FAILED variable(s) missing${NC}"
    exit 1
  fi
}

main
