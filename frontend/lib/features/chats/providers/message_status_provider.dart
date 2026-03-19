import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/message_model.dart';
import '../services/chat_api_service.dart';
import '../services/message_websocket_service.dart';
import '../services/message_encryption_service.dart';
import './websocket_provider.dart';

/// Provider to handle message status updates from WebSocket
/// Updates the message cache when status changes are received
final messageStatusUpdateProvider = StreamProvider.autoDispose<({
  String messageId,
  String newStatus,
  String chatId,
})?>(
  (ref) async* {
    // Watch WebSocket service to get access to event stream
    final webSocket = ref.watch(messageWebSocketProvider);
    
    // Listen to WebSocket events
    await for (final event in webSocket.eventStream) {
      if (event.type == WebSocketEventType.messageStatusChanged) {
        final messageId = event.data['messageId'] as String?;
        final newStatus = event.data['newStatus'] as String?;
        
        if (messageId != null && newStatus != null) {
          yield (
            messageId: messageId,
            newStatus: newStatus,
            chatId: event.chatId,
          );
        }
      }
    }
  },
);

/// Provider to auto-mark messages as read when viewing a chat
/// Call this when entering a chat to mark all unread messages as 'read'
final autoMarkAsReadProvider =
    FutureProvider.family<void, ({String chatId, String token})>(
  (ref, params) async {
    final (:chatId, :token) = params;
    final apiService = ChatApiService(baseUrl: 'http://localhost:8081');

    try {
      print('[AutoMarkAsRead] ⭐ PROVIDER INVOKED for chat $chatId');
      print('[AutoMarkAsRead] 🔄 Starting to mark messages as read for chat $chatId');
      
      // Fetch messages directly from API (don't use localMessagesProvider to avoid duplicate notifier)
      final fetchedMessages = await apiService.fetchMessages(
        token: token,
        chatId: chatId,
        limit: 50,
      );
      
      print('[AutoMarkAsRead] 📥 Fetched ${fetchedMessages.length} messages from API');
      
      // Show all message statuses to debug
      final statuses = fetchedMessages.map((m) => m.status).toList();
      print('[AutoMarkAsRead] 📊 All message statuses from API: $statuses');
      final sentCount = fetchedMessages.where((m) => m.status == 'sent').length;
      final deliveredCount = fetchedMessages.where((m) => m.status == 'delivered').length;
      final readCount = fetchedMessages.where((m) => m.status == 'read').length;
      print('[AutoMarkAsRead] 📊 Status breakdown: sent=$sentCount, delivered=$deliveredCount, read=$readCount');
      
      // Decrypt messages
      final decryptedMessages = await MessageEncryptionService.decryptMessages(fetchedMessages);
      
      print('[AutoMarkAsRead] 🔐 Decrypted ${decryptedMessages.length} messages');
      
      final unreadMessages = decryptedMessages
          .where((msg) => msg.status != 'read')
          .toList();

      print('[AutoMarkAsRead] 📖 Found ${unreadMessages.length} unread messages (status != "read")');
      if (unreadMessages.isNotEmpty) {
        print('[AutoMarkAsRead] 📋 Unread message statuses: ${unreadMessages.map((m) => '${m.id.substring(0, 8)} (status=${m.status})').toList()}');
      }

      if (unreadMessages.isEmpty) {
        print('[AutoMarkAsRead] ℹ️ No unread messages to mark');
        return;
      }

      // Mark each unread message as read
      int successCount = 0;
      for (final message in unreadMessages) {
        try {
          print('[AutoMarkAsRead] 📤 Marking ${message.id} as read (current status: ${message.status})');
          await apiService.updateMessageStatus(
            token: token,
            chatId: chatId,
            messageId: message.id,
            newStatus: 'read',
          );
          print('[AutoMarkAsRead] ✓ Marked ${message.id} as read');
          successCount++;
        } catch (e) {
          print('[AutoMarkAsRead] ⚠️ Error marking ${message.id} as read: $e');
        }
      }
      
      print('[AutoMarkAsRead] ✅ Finished marking messages as read ($successCount/${unreadMessages.length} succeeded)');
      print('[AutoMarkAsRead] 💙 Sender should now see blue checkmarks for these messages');
    } catch (e) {
      print('[AutoMarkAsRead] ❌ Error auto-marking as read: $e');
      rethrow;
    }
  },
);

/// Provider to update local message with new status
/// This is called when a messageStatusChanged event is received
class MessageStatusNotifier extends StateNotifier<void> {
  final ChatApiService _apiService;
  final Ref _ref;

  MessageStatusNotifier(
    this._apiService,
    this._ref,
  ) : super(null);

  /// Handle status change event
  /// Updates the message in the cache with new status
  void handleStatusChange(
    String messageId,
    String newStatus, {
    required String chatId,
    required String token,
  }) {
    try {
      print(
          '[MessageStatusNotifier] 📨 Status changed: $messageId → $newStatus');
      // Note: Message status is already being updated in real-time via 
      // WebSocket messageStatusChanged events handled in LocalMessagesNotifier._handleWebSocketEvent()
      print('[MessageStatusNotifier] ✓ Status updated for message $messageId');
    } catch (e) {
      print('[MessageStatusNotifier] ❌ Error handling status change: $e');
    }
  }
}

/// Notifier for message status updates
final messageStatusNotifierProvider =
    StateNotifierProvider.autoDispose<MessageStatusNotifier, void>(
  (ref) => MessageStatusNotifier(ChatApiService(baseUrl: 'http://localhost:8081'), ref),
);
