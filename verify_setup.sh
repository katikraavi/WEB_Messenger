#!/bin/bash

# Verify Complete Setup Script
# This script validates that the Mobile Messenger project is properly initialized
# and ready for development

set -e

echo "======================================"
echo "Mobile Messenger Setup Verification"
echo "======================================"
echo

# Color codes for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ERRORS=0

# Check function
check_file() {
  local file=$1
  local description=$2
  if [ -f "$file" ]; then
    echo -e "${GREEN}✓${NC} $description: $file"
  else
    echo -e "${RED}✗${NC} MISSING: $description: $file"
    ((ERRORS++))
  fi
}

check_dir() {
  local dir=$1
  local description=$2
  if [ -d "$dir" ]; then
    echo -e "${GREEN}✓${NC} $description: $dir"
  else
    echo -e "${RED}✗${NC} MISSING: $description: $dir"
    ((ERRORS++))
  fi
}

echo "Frontend Structure:"
check_file "frontend/lib/main.dart" "Frontend entry point"
check_file "frontend/lib/app.dart" "App root widget"
check_file "frontend/lib/core/services/api_client.dart" "API client"
check_file "frontend/pubspec.yaml" "Frontend dependencies"
check_dir "frontend/lib" "Frontend lib directory"
echo

echo "Backend Structure:"
check_file "backend/lib/server.dart" "Backend server"
check_file "backend/lib/src/endpoints/health.dart" "Health endpoint"
check_file "backend/pubspec.yaml" "Backend dependencies"
check_file "backend/Dockerfile" "Dockerfile"
check_file "backend/.env" "Backend environment config"
check_dir "backend/lib/src/endpoints" "Endpoints directory"
check_dir "backend/lib/src/services" "Services directory"
check_dir "backend/lib/src/models" "Models directory"
check_dir "backend/migrations" "Migrations directory"
echo

echo "Infrastructure & Configuration:"
check_file "docker-compose.yml" "Docker Compose configuration"
check_file ".env.example" "Environment template"
check_file ".gitignore" "Git ignore"
check_file "README.md" "Project README"
echo

echo "Docker Compose Validation:"
if command -v docker-compose &> /dev/null; then
  if docker-compose config > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Docker Compose syntax valid"
  else
    echo -e "${RED}✗${NC} Docker Compose syntax invalid"
    ((ERRORS++))
  fi
else
  echo -e "${YELLOW}⚠${NC} Docker Compose not found in PATH"
fi
echo

echo "======================================"
if [ $ERRORS -eq 0 ]; then
  echo -e "${GREEN}✓ Setup verification PASSED${NC}"
  echo "Project structure is complete and ready for development!"
  echo
  echo "Next steps:"
  echo "1. Run: docker-compose up"
  echo "2. In another terminal: cd frontend && flutter run"
  echo "3. Verify app connects to backend"
  exit 0
else
  echo -e "${RED}✗ Setup verification FAILED${NC}"
  echo "Please fix the $ERRORS missing file(s) and try again."
  exit 1
fi
