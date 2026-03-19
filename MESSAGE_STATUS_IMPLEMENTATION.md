# Message Status System Implementation Guide

## System Overview

Real-time message status tracking with three states:
- **sent** ✓ - Message delivered to server
- **delivered** ✓✓ - Message received by recipient  
- **read** ✓✓ (blue) - Message opened/viewed by recipient

---

## What's Implemented

### ✅ Backend

1. **Database Schema** (`migrations/005_create_messages_table.dart`)
   - `message.status` field with ENUM('sent', 'delivered', 'read')
   - `message_delivery_status` table for per-recipient tracking
   - Columns: `status`, `delivered_at`, `read_at`

2. **Message Models**
   - `message_model.dart` - Status field included
   - `message_status_model.dart` - Per-recipient tracking

3. **Message Service** (`lib/src/services/message_service.dart`)
   - `updateMessageStatus()` method to update database
   - Handles transitions: sent → delivered → read

4. **WebSocket Events**
   - Added `messageStatusChanged` event type to `WebSocketEventType` enum
   - Backend broadcasts status changes to all chat participants

5. **HTTP Endpoints**
   - `PUT /api/chats/{chatId}/messages/status` - NEW handler added
   - Updates status and broadcasts via WebSocket

### ✅ Frontend

1. **Message Models** (`chats/models/message_model.dart`)
   - Status field (3 states: sent, delivered, read)

2. **UI Indicators** (`chats/widgets/message_status_indicator.dart`)
   - ✓ icon (gray) for sent
   - ✓✓ icon (gray) for delivered
   - ✓✓ icon (blue) for read
   - Animated transitions between states

3. **Message Bubble** (`chats/widgets/message_bubble.dart`)
   - Displays status indicator for sent messages
   - Shows "(edited)" marker for edited messages

4. **Providers Created**
   - `message_status_provider.dart` - NEW file
     - `messageStatusUpdateProvider` - Listens for WebSocket status changes
     - `autoMarkAsReadProvider` - Auto-marks messages as read when viewing chat
     - `MessageStatusNotifier` - Handles status change events

5. **Auto-Mark as Delivered**
   - Already implemented in `receive_messages_provider.dart`
   - When message received: Auto-calls `_markMessageDelivered()`

---

## How It Works - Data Flow

### 1. Sending Messages
```
User sends → Frontend encrypts → POST /api/messages
Backend stores with status='sent' → WebSocket broadcasts messageCreated
Frontend receives → Adds to messages list → Shows ✓ indicator
```

### 2. Recipient Receives (Auto-Delivered)
```
Recipient opens chat → WebSocket receives messageCreated
Frontend auto-calls PUT /api/messages/status with "delivered"
Backend updates database → Broadcasts messageStatusChanged event
Sender's app receives event → Shows ✓✓ indicator
```

### 3. Recipient Reads (Auto-Read) - INCOMPLETE
```
Recipient views chat (enters ChatDetailScreen) → Should trigger autoMarkAsReadProvider
App calls PUT /api/messages/status with "read" for all unread messages
Backend updates database → Broadcasts messageStatusChanged event
Sender's app receives event → Shows ✓✓ (blue) indicator
```

### 4. Status Changes via WebSocket - INCOMPLETE
```
Backend broadcasts messageStatusChanged event with:
{
  "type": "messageStatusChanged",
  "data": {
    "messageId": "uuid",
    "newStatus": "read",
    "updatedBy": "user-uuid",
    "timestamp": "2026-03-17T..."
  }
}
Frontend messageStatusUpdateProvider listens → Invalidates message cache → UI updates
```

---

## What Still Needs Completion

### Task 1: Wire Auto-Read Functionality (**MEDIUM**)
**File**: `frontend/lib/features/chats/screens/chat_detail_screen.dart`

Add to ChatDetailScreen's `didChangeDependencies()`:
```dart
@override
void didChangeDependencies() {
  super.didChangeDependencies();
  
  Future.microtask(() {
    if (mounted) {
      final token = ref.read(authProvider)?.token ?? '';
      if (token.isNotEmpty) {
        ref.read(autoMarkAsReadProvider((widget.chatId, token)));
      }
    }
  });
}
```

### Task 2: Listen for Status Changes (**MEDIUM**)
**File**: `frontend/lib/features/chats/screens/chat_detail_screen.dart` (build method)

In the build method, add:
```dart
// Listen for message status changes from WebSocket
final statusUpdates = ref.watch(messageStatusUpdateProvider);
statusUpdates.whenData((update) {
  if (update != null) {
    ref.read(messageStatusNotifierProvider.notifier).handleStatusChange(
      messageId: update.messageId,
      newStatus: update.newStatus,
      chatId: widget.chatId,
      token: token,
    );
  }
});
```

### Task 3: Backend Endpoint Registration (**MEDIUM**)
**File**: `backend/lib/src/endpoints/chat_endpoints.dart` (or create new file)

Register the new endpoint:
```dart
router.put('/api/chats/<chatId>/messages/status', 
  (request, chatId) async {
    final connection = await _getConnection(); // Get DB connection
    return await MessageHandlers.updateMessageStatus(
      request,
      chatId,
      connection,
    );
  }
);
```

Or import connection management and adjust accordingly for your code structure.

### Task 4: Verify WebSocket Broadcasting (**SMALL**)
**File**: `backend/lib/src/handlers/message_handlers.dart` (already added)

Verify the `updateMessageStatus()` method is:
- ✅ Updating database via `messageService.updateMessageStatus()`
- ✅ Broadcasting via `_webSocketService.broadcastToChat()`
- ✅ Sending correct event type: `messageStatusChanged`

### Task 5: Test End-to-End (**SMALL**)
Scenario:
1. Open chat in Emulator A (alice)
2. Open same chat in Emulator B (bob)
3. Bob sends message → Alice should see ✓
4. Alice views message → Bob should see ✓✓ (gray)
5. Alice continues viewing → Bob should see ✓✓ (blue)

**What to watch in logs**:
- `[MessageWebSocket] 📨 Received messageStatusChanged` - Status change received
- `[AutoMarkAsRead] ✓ Marked {messageId} as read` - Auto-read triggered
- `[MessageStatusNotifier] ✓ Updated message cache` - Cache updated

---

## Database Schema Reference

### message_delivery_status Table
```sql
CREATE TABLE message_delivery_status (
  id UUID PRIMARY KEY,
  message_id UUID NOT NULL,
  recipient_id UUID NOT NULL,
  status VARCHAR(20) DEFAULT 'sent',  -- sent, delivered, read
  delivered_at TIMESTAMP,  -- When marked as delivered
  read_at TIMESTAMP,       -- When marked as read
  updated_at TIMESTAMP,
  UNIQUE(message_id, recipient_id)
);
```

---

## API Endpoint Details

### Update Message Status
```
PUT /api/chats/{chatId}/messages/status

Request:
{
  "message_id": "uuid",
  "status": "delivered" | "read"
}

Response: 200 OK
{
  "messageId": "uuid",
  "status": "delivered",
  "timestamp": "2026-03-17T..."
}
```

---

## WebSocket Events

### Message Status Changed Event
```json
{
  "type": "messageStatusChanged",
  "data": {
    "messageId": "msg-uuid",
    "newStatus": "read",
    "updatedBy": "user-uuid",
    "timestamp": "2026-03-17T10:30:00Z"
  },
  "timestamp": "2026-03-17T10:30:00Z"
}
```

---

## Configuration Checklist

- [ ] Task 1: Add didChangeDependencies() to ChatDetailScreen
- [ ] Task 2: Add statusUpdates listener to ChatDetailScreen.build()
- [ ] Task 3: Register PUT endpoint in backend router
- [ ] Task 4: Verify WebSocket broadcasting in updateMessageStatus()
- [ ] Task 5: Test end-to-end message status flow

---

## Running the Complete System

```bash
# Terminal 1: Backend
cd backend
dart bin/server.dart

# Terminal 2: Frontend (Emulator A)
cd frontend
flutter run -d linux

# Terminal 3: Frontend (Emulator B)  
cd frontend
flutter run -d linux
```

**Test Flow**:
1. Login as alice in Terminal 2
2. Login as bob in Terminal 3
3. Start chat between them
4. With bob's app visible, alice sends a message
5. Watch for ✓ indicator
6. With alice's app visible, bob views the message
7. Watch alice's app for ✓✓ (blue) indicator

---

## Troubleshooting

### Message shows ✓ but never changes to ✓✓

1. **Check logs** for `[AutoMarkAsRead]` - If not appearing, didChangeDependencies() not called
2. **Backend endpoint** - Verify PUT endpoint is registered correctly
3. **WebSocket** - Check for `[MessageWebSocket] 📨 Received messageStatusChanged`
4. **API response** - Curl test the API:
   ```bash
   curl -X PUT http://localhost:8081/api/chats/chat-uuid/messages/status \
     -H 'Authorization: Bearer token' \
     -H 'Content-Type: application/json' \
     -d '{"message_id":"msg-uuid","status":"read"}'
   ```

### Status changes not broadcasting

1. **Check** `_webSocketService.broadcastToChat()` is called
2. **Verify** `messageStatusChanged` event type is in enum
3. **Restart** backend to pick up code changes

---

## Performance Notes

- Status updates trigger full message cache invalidation (acceptable for 1-to-1 chats)
- For group chats, consider updating individual message in cache instead
- WebSocket broadcasts only to participants in the chat

---

## Future Enhancements

1. **Typing Indicators** - Show "user is typing..." status  
2. **Read Receipts** - Show "seen at" timestamp
3. **Bulk Mark as Read** - Mark all messages in chat as read with one API call
4. **Status Icons** - Custom icons/animations per status
5. **Auto-Scroll** - Keep chat scrolled to latest message
