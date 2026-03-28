#!/usr/bin/env bash

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <render-base-url>"
  echo "Example: $0 https://web-messenger-backend.onrender.com"
  exit 1
fi

BASE_URL="${1%/}"

check_json_endpoint() {
  local path="$1"
  local expected_code="$2"
  local must_contain="$3"

  local tmp_file
  tmp_file="$(mktemp)"
  local code
  code="$(curl -sS -o "$tmp_file" -w "%{http_code}" "$BASE_URL$path")"

  if [[ "$code" != "$expected_code" ]]; then
    echo "FAIL $path expected HTTP $expected_code got $code"
    cat "$tmp_file"
    rm -f "$tmp_file"
    exit 1
  fi

  if [[ -n "$must_contain" ]] && ! grep -q "$must_contain" "$tmp_file"; then
    echo "FAIL $path response missing expected marker: $must_contain"
    cat "$tmp_file"
    rm -f "$tmp_file"
    exit 1
  fi

  echo "OK   $path -> HTTP $code"
  rm -f "$tmp_file"
}

echo "Checking deployment at $BASE_URL"

# Core health endpoint
check_json_endpoint "/health" "200" "healthy"

# API routing sanity checks
auth_tmp="$(mktemp)"
auth_code="$(curl -sS -o "$auth_tmp" -w "%{http_code}" \
  -X POST \
  -H 'Content-Type: application/json' \
  -d '{}' \
  "$BASE_URL/api/auth/login")"
if [[ "$auth_code" == "404" || "$auth_code" == "502" ]]; then
  echo "FAIL /api/auth/login is not routed to backend (HTTP $auth_code)"
  cat "$auth_tmp"
  rm -f "$auth_tmp"
  exit 1
fi
if grep -qi "<!doctype html>" "$auth_tmp"; then
  echo "FAIL /api/auth/login returned HTML fallback instead of backend JSON"
  cat "$auth_tmp"
  rm -f "$auth_tmp"
  exit 1
fi
if [[ "$auth_code" != "200" && "$auth_code" != "400" && "$auth_code" != "401" ]]; then
  echo "FAIL /api/auth/login returned unexpected HTTP $auth_code"
  cat "$auth_tmp"
  rm -f "$auth_tmp"
  exit 1
fi
echo "OK   /api/auth/login -> HTTP $auth_code (backend route reached)"
rm -f "$auth_tmp"

check_json_endpoint "/api/chats" "401" "authorization"

# Frontend shell sanity checks
index_tmp="$(mktemp)"
index_code="$(curl -sS -o "$index_tmp" -w "%{http_code}" "$BASE_URL/")"
if [[ "$index_code" != "200" ]]; then
  echo "FAIL / expected HTTP 200 got $index_code"
  rm -f "$index_tmp"
  exit 1
fi
if ! grep -qi "<html" "$index_tmp"; then
  echo "FAIL / did not return HTML frontend shell"
  cat "$index_tmp"
  rm -f "$index_tmp"
  exit 1
fi
rm -f "$index_tmp"

# Frontend bundle sanity: catch known bad host misconfiguration
# that causes browser DNS errors like ERR_NAME_NOT_RESOLVED.
js_tmp="$(mktemp)"
js_code="$(curl -sS -o "$js_tmp" -w "%{http_code}" "$BASE_URL/main.dart.js")"
if [[ "$js_code" == "200" ]]; then
  if grep -q "https://api/auth/login" "$js_tmp" || grep -q "http://api/auth/login" "$js_tmp"; then
    echo "FAIL frontend bundle contains invalid API host (https://api or http://api)"
    echo "Hint: set BACKEND_URL=/ (same service) or full backend origin (split services) and redeploy."
    rm -f "$js_tmp"
    exit 1
  fi
  echo "OK   /main.dart.js API host sanity"
fi
rm -f "$js_tmp"

echo "PASS Deployment checks succeeded for $BASE_URL"
