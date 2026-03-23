import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../models/message_model.dart';
import '../../../core/services/websocket_service.dart';
import '../services/chat_api_service.dart';

/// Phase 4: Receive Messages & Read Receipts (T032-T035)
/// 
/// Handles receiving messages from other users via WebSocket,.
/// automatically marking them as delivered/read, and updating the UI.

/// Message received event
class MessageReceivedEvent {
  final Message message;
  final String chatId;
  final String senderId;

  MessageReceivedEvent({
    required this.message,
    required this.chatId,
    required this.senderId,
  });
}

/// Service for listening to incoming messages via WebSocket (T032-T033)
class ReceiveMessagesListener {
  final WebSocketService _webSocketService;
  final ChatApiService _apiService;
  final String _currentUserId;
  final String _token;
  
  // Stream controller for message received events
  final _messageReceivedController = StreamController<MessageReceivedEvent>.broadcast();

  Stream<MessageReceivedEvent> get messageReceivedStream => 
      _messageReceivedController.stream;

  ReceiveMessagesListener({
    required WebSocketService webSocketService,
    required ChatApiService apiService,
    required String currentUserId,
    required String token,
  })  : _webSocketService = webSocketService,
        _apiService = apiService,
        _currentUserId = currentUserId,
        _token = token {
    _setupListeners();
  }

  /// Setup WebSocket event listeners (T032, T047, T064)
  /// 
  /// Handles: message creation, read receipts, typing, edit, delete
  void _setupListeners() {

    // Listen for all events
    _webSocketService.eventStream.listen((event) {
      final eventType = event['type'];
      
      if (eventType == 'messageCreated' || eventType == 'message.created') {
        _handleMessageCreated(event);
      } else if (eventType == 'messageRead') {
        _handleMessageRead(event);
      } else if (eventType == 'user_typing' || eventType == 'typing.start') {
        _handleTypingStart(event);
      } else if (eventType == 'typing.stop') {
        _handleTypingStop(event);
      } else if (eventType == 'message.edited') {
        _handleMessageEdited(event);
      } else if (eventType == 'message.deleted') {
        _handleMessageDeleted(event);
      }
    });
  }
  
  /// Handle incoming typing.start event (T047)
  void _handleTypingStart(Map<String, dynamic> event) {
    try {
      // Event will be handled by app_initialization_service which routes to typing_indicator_provider
    } catch (e) {
    }
  }
  
  /// Handle incoming typing.stop event (T047)
  void _handleTypingStop(Map<String, dynamic> event) {
    try {
      // Event will be handled by app_initialization_service which routes to typing_indicator_provider
    } catch (e) {
    }
  }

  /// Handle incoming messageCreated event from WebSocket (T033)
  /// 
  /// This is called when the recipient receives a message from another user.
  /// Flow:
  /// 1. Parse the event and create Message object
  /// 2. If message not for current user, ignore
  /// 3. If message for current user:
  ///    a. Emit messageReceivedStream event
  ///    b. Auto-mark as delivered (T034)
  ///    c. Cache message locally
  Future<void> _handleMessageCreated(Map<String, dynamic> event) async {
    try {

      // Extract message data from event
      final messageData = event['data'] as Map<String, dynamic>?;
      if (messageData == null) {
        return;
      }

      // Parse message
      final message = Message.fromJson(messageData);
      final chatId = event['chatId'] ?? message.chatId;

      // Only process if message is for current user
      if (message.recipientId != _currentUserId) {
        return;
      }


      // Emit message received event
      _messageReceivedController.add(
        MessageReceivedEvent(
          message: message,
          chatId: chatId,
          senderId: message.senderId,
        ),
      );

      // Auto-mark message as delivered
      await _markMessageDelivered(message.id, chatId);

    } catch (e, st) {
    }
  }

  /// Mark message as delivered (T034)
  /// 
  /// Sends request to backend to update message_delivery_status
  /// to 'delivered' when recipient receives the message
  Future<void> _markMessageDelivered(String messageId, String chatId) async {
    try {

      // Call API to update status
      await _apiService.updateMessageStatus(
        token: _token,
        chatId: chatId,
        messageId: messageId,
        newStatus: 'delivered',
      );

    } catch (e) {
      // Non-blocking - don't rethrow, message still displays
    }
  }

  /// Handle messageRead event (T035)
  /// 
  /// Called when user comes online and messages are marked as read
  Future<void> _handleMessageRead(Map<String, dynamic> event) async {
    try {

      // For now, just log - actual read receipt handling in Phase 4+
      // This would trigger UI update to show ✓✓ blue checkmark
    } catch (e) {
    }
  }

  /// Handle message.edited event (T064)
  /// 
  /// Called when a message is edited by the sender.
  /// Triggers cache invalidation for message list refresh.
  void _handleMessageEdited(Map<String, dynamic> event) {
    try {

      // Extract message data
      final messageData = event['data'] as Map<String, dynamic>?;
      if (messageData == null) {
        return;
      }

      final message = Message.fromJson(messageData);
      
      // Cache invalidation happens through messagesWithCacheProvider watching WebSocket
      // The providers will automatically refresh when receive_messages_provider is notified
    } catch (e) {
    }
  }

  /// Handle message.deleted event (T064)
  /// 
  /// Called when a message is deleted by the sender.
  /// Triggers cache invalidation for message list refresh.
  void _handleMessageDeleted(Map<String, dynamic> event) {
    try {

      // Extract message data
      final messageData = event['data'] as Map<String, dynamic>?;
      if (messageData == null) {
        return;
      }

      final message = Message.fromJson(messageData);
      
      // Cache invalidation happens through messagesWithCacheProvider watching WebSocket
      // The providers will automatically refresh when receive_messages_provider is notified
    } catch (e) {
    }
  }

  /// Cleanup
  void dispose() {
    _messageReceivedController.close();
  }
}

/// DEPRECATED: Use messageEventStreamProvider from websocket_provider.dart instead
/// This provider is kept for backward compatibility but is no longer actively used
/// 
/// The new WebSocket-based implementation provides better real-time messaging
final receiveMessagesListenerProvider = Provider<ReceiveMessagesListener?>((ref) {
  // Deprecated - WebSocket is now used for real-time messaging
  // See messageEventStreamProvider in websocket_provider.dart
  return null;
});

/// DEPRECATED: Use messageEventStreamProvider from websocket_provider.dart instead
/// This provider is kept for backward compatibility but is no longer actively used
/// 
/// The new WebSocket-based implementation provides better real-time messaging
final receiveMessageStreamProvider = StreamProvider<MessageReceivedEvent?>((ref) async* {
  // Deprecated - WebSocket is now used for real-time messaging
  // See messageEventStreamProvider in websocket_provider.dart
  yield null;
});
