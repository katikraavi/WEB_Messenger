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
    FutureProvider.family<void, ({String chatId, String token, String currentUserId})>(
  (ref, params) async {
    final (:chatId, :token, :currentUserId) = params;
    final apiService = ChatApiService(baseUrl: 'http://localhost:8081');

    try {
      
      // Fetch messages directly from API (don't use localMessagesProvider to avoid duplicate notifier)
      final fetchedMessages = await apiService.fetchMessages(
        token: token,
        chatId: chatId,
        limit: 50,
      );
      
      
      // Show all message statuses to debug
      final statuses = fetchedMessages.map((m) => m.status).toList();
      final sentCount = fetchedMessages.where((m) => m.status == 'sent').length;
      final deliveredCount = fetchedMessages.where((m) => m.status == 'delivered').length;
      final readCount = fetchedMessages.where((m) => m.status == 'read').length;
      
      // Decrypt messages
      final decryptedMessages = await MessageEncryptionService.decryptMessages(fetchedMessages);
      
      
      final unreadMessages = decryptedMessages
          .where((msg) => msg.status != 'read' && msg.senderId != currentUserId)
          .toList();

      if (unreadMessages.isNotEmpty) {
      }

      if (unreadMessages.isEmpty) {
        return;
      }

      // Mark each unread message as read
      int successCount = 0;
      for (final message in unreadMessages) {
        try {
          await apiService.updateMessageStatus(
            token: token,
            chatId: chatId,
            messageId: message.id,
            newStatus: 'read',
          );
          successCount++;
        } catch (e) {
        }
      }
      
    } catch (e) {
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
      // Note: Message status is already being updated in real-time via 
      // WebSocket messageStatusChanged events handled in LocalMessagesNotifier._handleWebSocketEvent()
    } catch (e) {
    }
  }
}

/// Notifier for message status updates
final messageStatusNotifierProvider =
    StateNotifierProvider.autoDispose<MessageStatusNotifier, void>(
  (ref) => MessageStatusNotifier(ChatApiService(baseUrl: 'http://localhost:8081'), ref),
);
