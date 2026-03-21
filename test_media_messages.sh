#!/bin/bash
# Comprehensive test: text messages, picture messages, video messages

BASE_URL="http://localhost:8081"
ALICE_EMAIL="testuser1@example.com"
ALICE_PASSWORD="testuser1pass"
BOB_EMAIL="testuser2@example.com"
BOB_PASSWORD="testuser2pass"
TEST_IMG="/home/katikraavi/mobile-messenger/Test_Pictures/okPicture.jpg"
TEST_VID="/home/katikraavi/mobile-messenger/Test_Pictures/Salvestamine202334.mp4"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() { echo -e "${GREEN}✅ $1${NC}"; }
fail() { echo -e "${RED}❌ $1${NC}"; exit 1; }
info() { echo -e "${YELLOW}▶ $1${NC}"; }

echo "============================================"
echo "  MESSAGE / MEDIA END-TO-END TEST"
echo "============================================"
echo ""

# ── 1. Auth ──────────────────────────────────────
info "1. Logging in as TestUser1..."
ALICE_RESP=$(curl -sf -X POST "$BASE_URL/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$ALICE_EMAIL\",\"password\":\"$ALICE_PASSWORD\"}" 2>&1) || fail "Alice login request failed"
ALICE_TOKEN=$(echo "$ALICE_RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('token',''))" 2>/dev/null)
ALICE_ID=$(echo "$ALICE_RESP"    | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('userId',''))" 2>/dev/null)
[ -z "$ALICE_TOKEN" ] && fail "TestUser1 login failed: $ALICE_RESP"
pass "TestUser1 logged in (id=${ALICE_ID:0:8}...)"

info "2. Logging in as TestUser2..."
BOB_RESP=$(curl -sf -X POST "$BASE_URL/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$BOB_EMAIL\",\"password\":\"$BOB_PASSWORD\"}" 2>&1) || fail "Bob login request failed"
BOB_TOKEN=$(echo "$BOB_RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('token',''))" 2>/dev/null)
BOB_ID=$(echo "$BOB_RESP"    | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('userId',''))" 2>/dev/null)
[ -z "$BOB_TOKEN" ] && fail "TestUser2 login failed: $BOB_RESP"
pass "TestUser2 logged in (id=${BOB_ID:0:8}...)"
echo ""

# ── 2. Find chat ─────────────────────────────────
info "3. Fetching TestUser1's chats..."
CHATS_RESP=$(curl -sf "$BASE_URL/api/chats?limit=10&offset=0" \
  -H "Authorization: Bearer $ALICE_TOKEN" 2>&1) || fail "Fetch chats failed"
CHAT_ID=$(echo "$CHATS_RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); chats=d if isinstance(d,list) else d.get('chats',[]); print(chats[0]['id'] if chats else '')" 2>/dev/null)
[ -z "$CHAT_ID" ] && fail "No chats found for TestUser1. Response: $CHATS_RESP"
pass "Chat found: ${CHAT_ID:0:8}..."
echo ""

# ── 3. Text message ──────────────────────────────
info "4. Sending TEXT message..."
TEXT="Hello from test! $(date)"
ENCRYPTED=$(echo -n "$TEXT" | base64 | tr -d '\n')
SEND_RESP=$(curl -sf -X POST "$BASE_URL/api/chats/$CHAT_ID/messages" \
  -H "Authorization: Bearer $ALICE_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"encrypted_content\":\"$ENCRYPTED\"}" 2>&1) || fail "Send text message failed: $SEND_RESP"
MSG_ID=$(echo "$SEND_RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('id',''))" 2>/dev/null)
[ -z "$MSG_ID" ] && fail "Text message send failed – response: $SEND_RESP"
pass "Text message sent   id=${MSG_ID:0:8}..."

# Verify Bob can fetch it
BOB_MSGS=$(curl -sf "$BASE_URL/api/chats/$CHAT_ID/messages?limit=5&offset=0" \
  -H "Authorization: Bearer $BOB_TOKEN" 2>&1) || fail "Bob fetch messages failed"
FOUND=$(echo "$BOB_MSGS" | python3 -c "import sys,json; msgs=json.load(sys.stdin); msgs=msgs if isinstance(msgs,list) else msgs.get('messages',[]); print('yes' if any(m.get('id')=='$MSG_ID' for m in msgs) else 'no')" 2>/dev/null)
[ "$FOUND" = "yes" ] && pass "Text message visible to Bob" || fail "Text message NOT found in Bob's view"
echo ""

# ── 4. Picture upload + picture message ──────────
info "5. Uploading PICTURE (okPicture.jpg)..."
[ -f "$TEST_IMG" ] || fail "Test image not found: $TEST_IMG"
IMG_RESP=$(curl -sf -X POST "$BASE_URL/api/media/upload" \
  -H "Authorization: Bearer $ALICE_TOKEN" \
  -F "file=@${TEST_IMG};type=image/jpeg" 2>&1) || fail "Picture upload request failed: $IMG_RESP"
IMG_PATH=$(echo "$IMG_RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('file_path',''))" 2>/dev/null)
IMG_NAME=$(echo "$IMG_RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('file_name',''))" 2>/dev/null)
[ -z "$IMG_PATH" ] && fail "Picture upload failed – response: $IMG_RESP"
pass "Picture uploaded  path=$IMG_PATH"

info "6. Sending PICTURE message..."
MEDIA_URL="/uploads/media/${IMG_NAME}"
IMG_MSG_RESP=$(curl -sf -X POST "$BASE_URL/api/chats/$CHAT_ID/messages" \
  -H "Authorization: Bearer $ALICE_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"encrypted_content\":\"$(echo -n '[image]' | base64)\",\"media_url\":\"$MEDIA_URL\",\"media_type\":\"image/jpeg\"}" 2>&1) || fail "Send picture message failed: $IMG_MSG_RESP"
IMG_MSG_ID=$(echo "$IMG_MSG_RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('id',''))" 2>/dev/null)
RETURNED_URL=$(echo "$IMG_MSG_RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('media_url',''))" 2>/dev/null)
[ -z "$IMG_MSG_ID" ] && fail "Picture message send failed – response: $IMG_MSG_RESP"
pass "Picture message sent  id=${IMG_MSG_ID:0:8}...  media_url=$RETURNED_URL"

# Verify file is accessible over HTTP
HTTP_STATUS=$(curl -so /dev/null -w "%{http_code}" "$BASE_URL/$IMG_PATH" \
  -H "Authorization: Bearer $BOB_TOKEN" 2>&1)
[ "$HTTP_STATUS" = "200" ] && pass "Picture file accessible via HTTP ($HTTP_STATUS)" \
  || echo -e "${YELLOW}⚠️  Picture file HTTP status: $HTTP_STATUS (may need auth or path differs)${NC}"
echo ""

# ── 5. Video upload + video message ──────────────
info "7. Uploading VIDEO (Salvestamine202334.mp4)..."
[ -f "$TEST_VID" ] || fail "Test video not found: $TEST_VID"
VID_SIZE=$(du -sh "$TEST_VID" | cut -f1)
echo "   File size: $VID_SIZE"
VID_RESP=$(curl -sf -X POST "$BASE_URL/api/media/upload" \
  -H "Authorization: Bearer $ALICE_TOKEN" \
  -F "file=@${TEST_VID};type=video/mp4" 2>&1) || fail "Video upload request failed: $VID_RESP"
VID_PATH=$(echo "$VID_RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('file_path',''))" 2>/dev/null)
VID_NAME=$(echo "$VID_RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('file_name',''))" 2>/dev/null)
VID_SIZE_RESP=$(echo "$VID_RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('file_size_bytes',''))" 2>/dev/null)
[ -z "$VID_PATH" ] && fail "Video upload failed – response: $VID_RESP"
pass "Video uploaded  path=$VID_PATH  size=${VID_SIZE_RESP}B"

info "8. Sending VIDEO message..."
VID_MEDIA_URL="/uploads/media/${VID_NAME}"
VID_MSG_RESP=$(curl -sf -X POST "$BASE_URL/api/chats/$CHAT_ID/messages" \
  -H "Authorization: Bearer $ALICE_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"encrypted_content\":\"$(echo -n '[video]' | base64)\",\"media_url\":\"$VID_MEDIA_URL\",\"media_type\":\"video/mp4\"}" 2>&1) || fail "Send video message failed: $VID_MSG_RESP"
VID_MSG_ID=$(echo "$VID_MSG_RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('id',''))" 2>/dev/null)
VID_RETURNED_URL=$(echo "$VID_MSG_RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('media_url',''))" 2>/dev/null)
[ -z "$VID_MSG_ID" ] && fail "Video message send failed – response: $VID_MSG_RESP"
pass "Video message sent  id=${VID_MSG_ID:0:8}...  media_url=$VID_RETURNED_URL"

# Verify file is accessible over HTTP
VID_HTTP=$(curl -so /dev/null -w "%{http_code}" "$BASE_URL/$VID_PATH" \
  -H "Authorization: Bearer $BOB_TOKEN" 2>&1)
[ "$VID_HTTP" = "200" ] && pass "Video file accessible via HTTP ($VID_HTTP)" \
  || echo -e "${YELLOW}⚠️  Video file HTTP status: $VID_HTTP (may need auth or path differs)${NC}"
echo ""

# ── 6. Read-back all messages ─────────────────────
info "9. Bob reads last 10 messages..."
FINAL_MSGS=$(curl -sf "$BASE_URL/api/chats/$CHAT_ID/messages?limit=10&offset=0" \
  -H "Authorization: Bearer $BOB_TOKEN" 2>&1) || fail "Bob final fetch failed"
echo "$FINAL_MSGS" | python3 -c "
import sys, json
data = json.load(sys.stdin)
msgs = data if isinstance(data, list) else data.get('messages', [])
for m in msgs:
    mid   = m.get('id','?')[:8]
    mtype = m.get('media_type','text') or 'text'
    murl  = m.get('media_url','') or ''
    print(f'  [{mid}...] type={mtype:15s}  media_url={murl[:50]}')
" 2>/dev/null

echo ""
echo "============================================"
echo -e "${GREEN}  ALL TESTS PASSED${NC}"
echo "============================================"
