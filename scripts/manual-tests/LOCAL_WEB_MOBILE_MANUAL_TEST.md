# Local Manual Test: Web View + Mobile View

## 1) Start backend and database
From workspace root:
./start.sh

Wait until health is up:
curl http://localhost:8081/health

## 2) Web view (desktop browser)
From frontend folder:
./run_web.sh

This starts Flutter web on http://localhost:5000

## 3) Web mobile view (browser responsive mode)
Open Chrome DevTools on the web app page:
- Press F12
- Toggle device toolbar (Ctrl+Shift+M)
- Test at least these presets:
  - iPhone 14 Pro
  - Pixel 7
  - iPad Mini

## 4) Native Android mobile view
From frontend folder:
./run_android_three.sh debug

If you want one emulator only, use normal Flutter run:
flutter run -d emulator-5554

## 5) Manual E2E checks to perform on both web + mobile
1. Login as alice@example.com and bob@example.com in separate clients.
2. Send image from Alice to Bob.
3. Send video from Alice to Bob.
4. Open each media item from Bob side and confirm it loads.
5. Change Alice profile picture.
6. Verify updated avatar appears in:
   - profile screen
   - chat list
   - message list bubble/avatar
7. Send a new text message after avatar change and verify Bob sees new avatar.

## 6) Quick API spot checks during manual test
Login (example):
curl -X POST http://localhost:8081/api/auth/login -H "Content-Type: application/json" --data-raw '{"email":"bob@example.com","password":"bob123"}'

Search by username (must use q):
curl "http://localhost:8081/api/search/username?q=alice" -H "Authorization: Bearer <TOKEN>"

## 7) Notes
- Search endpoint parameter is q, not query.
- If web upload hits Firebase CORS in browser, app fallback path should still allow upload through backend endpoints.
- For strict automation after manual run, execute:
  bash /tmp/local_e2e_media_profile.sh
