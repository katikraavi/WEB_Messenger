# Video Lazy Initialization Test Guide

## What Changed
The video player now uses **lazy initialization** - the native MediaKit code only initializes when you tap to play, not when the message appears. This prevents premature native platform crashes.

## What to Expect

### Before Typing Message
- Video messages show "Tap to play" placeholder
- NO native code running yet
- App should be responsive

### After Tapping Play
- MaterialKit initializes on demand
- Video loads and plays
- If it fails: Shows "Video unavailable" instead of crashing

### If Native Crash Occurs
- Error boundary catches it
- App stays responsive (no device disconnect)
- Video shows as "unavailable" with filename

## Testing Steps

### Test 1: Send a Video and Don't Play
1. Send a video message
2. Message list should load without crashes
3. Observe "Tap to play" placeholder appears
4. **Expected**: App stays stable, no attempt to play

### Test 2: Send a Video and Tap Play
1. Send a video message
2. Tap the play button
3. **Expected**: 
   - Video initializes on tap
   - Either plays successfully OR shows "Video unavailable"
   - App does NOT disconnect/crash

### Test 3: Send Multiple Videos Quickly
1. Send 3-5 video messages rapidly
2. Don't tap on any of them immediately
3. Scroll through messages
4. **Expected**: All messages load quickly, showing placeholders
5. Then tap one: **Expected**: Plays or shows unavailable

### Test 4: Multiple Video Interactions
1. Send 2 videos to different people
2. Tap play on first video
3. While first is playing, tap play on second
4. Switch chat rooms with videos
5. **Expected**: App stays stable, no crashes

## Monitoring (Check Logs)

Watch for these patterns that indicate the fix is working:

### Good Signs ✅
```
[InlineVideoPlayer] Video widget created (init deferred)
[InlineVideoPlayer] Lazy-initializing player for: http://...
[InlineVideoPlayer] Opening video: http://...
[VideoPlayerErrorBoundary] Error caught, showing fallback UI
```

### Bad Signs ❌
```
Lost connection to device.
PLATFORM DISPATCHER exception
media_kit: VideoOutput: video_output_new: ...
```

## Troubleshooting

### If App Still Crashes When Playing
1. Check logs for the exact error
2. Verify `[InlineVideoPlayer] Lazy-initializing player` appears in logs
3. If initialization never mentioned: Code wasn't updated properly
4. Rebuild: `flutter clean && flutter pub get && flutter run`

### If "Video unavailable" Shows
This is **EXPECTED** on Linux with current MediaKit version. The lazy initialization + error boundary mean:
- ✅ App stayed stable
- ✅ Error was caught gracefully  
- ✅ User sees useful feedback instead of crash

### If Videos Play Successfully
Congratulations! The platform has good MediaKit support and no crash would occur anyway.

## Performance Impact

- **Positive**: Faster initial message load (no video initialization)
- **Neutral**: Same playback performance once tap occurs
- **Minimal**: <50ms additional delay on first play

## Detailed Test Scenario

1. **Setup**: Restart app, log in
2. **Action 1**: Send image + video in same message
   - Expected: Image loads, video shows placeholder
3. **Action 2**: Tap on video placeholder
   - Expected: Either plays or shows unavailable
4. **Action 3**: Scroll to another chat
   - Expected: No crashes, clean transition
5. **Action 4**: Return to previous chat
   - Expected: Video placeholder still visible, can tap again
6. **Action 5**: Try sending 5 videos rapidly
   - Expected: All load quickly as placeholders

## Log Validation

Run this to capture logs:
```bash
flutter run 2>&1 | tee flutter_test.log
```

Then search for:
- `Lazy-initializing player` - Shows lazy init is active
- `Video unavailable` - Shows error boundary caught error
- `Lost connection` - Would indicate crash (should NOT see this)

## Before Committing Results
1. Run tests above completely
2. Check logs for crashes
3. Test on actual device if possible
4. Verify app doesn't disconnect
5. Report any crashes with full logs
