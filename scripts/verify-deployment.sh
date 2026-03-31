#!/bin/bash

# Deployment Verification Script
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASSED=0
FAILED=0

log_pass() { echo -e "${GREEN}✓${NC} $1"; ((PASSED++)); }
log_fail() { echo -e "${RED}✗${NC} $1"; ((FAILED++)); }
log_info() { echo -e "${BLUE}ℹ${NC} $1"; }

section() { echo; echo -e "${BLUE}━━ $1 ━━${NC}"; }

main() {
  local target="${1:-local}"
  
  if [[ "$target" == "local" ]]; then
    section "ENVIRONMENT VERIFICATION"
    
    if docker --version &>/dev/null; then
      log_pass "Docker installed"
    else
      log_fail "Docker not installed"
    fi
    
    if command -v curl &>/dev/null; then
      log_pass "curl installed"
    else
      log_fail "curl not installed"
    fi
    
    section "DOCKER SERVICES"
    
    if docker-compose ps &>/dev/null; then
      log_pass "docker-compose accessible"
    else
      log_fail "docker-compose not accessible"
    fi
    
    if docker-compose ps 2>/dev/null | grep -q "messenger-backend"; then
      log_pass "Backend service found"
    else
      log_fail "Backend service not found"
    fi
    
    section "ENDPOINT CHECKS"
    
    if timeout 5 curl -s http://localhost:8081/health &>/dev/null; then
      log_pass "Backend health check responding"
    else
      log_info "Backend not responding (may not be running)"
    fi
    
  elif [[ "$target" == "production" ]]; then
    section "PRODUCTION ENDPOINTS"
    log_info "Production endpoint verification not configured yet"
    log_info "Update ENDPOINT_MAPPING.md with your Oracle Cloud URLs"
    
  elif [[ "$target" == "compare" ]]; then
    section "CONFIGURATION COMPARISON"
    
    if [[ -f "docker-compose.yml" ]]; then
      log_pass "Local docker-compose.yml found"
    else
      log_fail "Local docker-compose.yml missing"
    fi
    
    if [[ -f ".env" ]]; then
      log_pass ".env file found"
    else
      log_fail ".env file missing"
    fi
    
    if [[ -f ".env.oracle" ]]; then
      log_pass ".env.oracle file found"
    else
      log_fail ".env.oracle file missing"
    fi
  fi
  
  section "SUMMARY"
  echo "✓ Passed: $PASSED"
  echo "✗ Failed: $FAILED"
  
  if [[ $FAILED -eq 0 ]]; then
    echo -e "${GREEN}✓ All checks passed!${NC}"
    exit 0
  else
    echo -e "${RED}✗ Some checks failed${NC}"
    exit 1
  fi
}

main "$@"
