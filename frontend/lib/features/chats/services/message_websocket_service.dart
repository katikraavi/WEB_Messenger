import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:frontend/core/services/app_exception_logger.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Event types for WebSocket messages
enum WebSocketEventType {
  messageCreated, // Backend sends this for new messages
  messageReceived, // Backend sends this for read receipts
  messageEdited,
  messageDeleted,
  messageStatusChanged, // Message status updated (sent, delivered, read)
  chatArchived,
  chatUnarchived,
  invitationSent, // New invitation sent to user
  invitationAccepted, // User accepted an invitation
  invitationDeclined, // User declined an invitation
  invitationCancelled, // Sender cancelled an invitation
  ping,
  pong,
  unknown;

  factory WebSocketEventType.fromString(String value) {
    try {
      return WebSocketEventType.values.firstWhere((e) => e.name == value);
    } catch (e) {
      debugPrint('[WebSocketEventType] ⚠️  Unknown event type: $value');
      return unknown;
    }
  }
}

/// WebSocket event for real-time communication
class WebSocketEvent {
  final WebSocketEventType type;
  final String chatId;
  final Map<String, dynamic> data;

  WebSocketEvent({
    required this.type,
    required this.chatId,
    required this.data,
  });

  factory WebSocketEvent.fromJson(Map<String, dynamic> json) {
    // Backend sends type as top-level field
    final typeStr = json['type'] as String? ?? 'unknown';
    final type = WebSocketEventType.fromString(typeStr);

    // Backend doesn't include chatId in the message, so we extract it from data if available
    // Otherwise it will be set by the caller using _currentChatId
    String chatId = json['chatId'] as String? ?? '';

    // Extract chatId from data if not in top-level
    if (chatId.isEmpty && json['data'] is Map) {
      final data = json['data'] as Map<String, dynamic>;
      chatId = data['chatId'] as String? ?? '';
    }

    return WebSocketEvent(
      type: type,
      chatId: chatId,
      data: json['data'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'chatId': chatId,
    'data': data,
  };
}

/// Service for WebSocket real-time messaging
class MessageWebSocketService {
  static final MessageWebSocketService _instance = MessageWebSocketService._();

  factory MessageWebSocketService() {
    return _instance;
  }

  MessageWebSocketService._();

  WebSocketChannel? _webSocket;
  final _eventStreamController = StreamController<WebSocketEvent>.broadcast();
  final _typingIndicatorsController =
      StreamController<
        ({String userId, String chatId, bool isTyping})
      >.broadcast();

  String? _currentUserId;
  String? _currentChatId;
  Timer? _typingDebounceTimer;
  Timer? _heartbeatTimer;
  bool _isConnected = false;

  /// Stream of WebSocket events
  Stream<WebSocketEvent> get eventStream => _eventStreamController.stream;

  /// Stream of typing indicators
  Stream<({String userId, String chatId, bool isTyping})>
  get typingIndicators => _typingIndicatorsController.stream;

  /// Check if WebSocket is connected
  bool get isConnected => _isConnected;

  /// Connect to WebSocket server
  Future<void> connect({
    required String token,
    required String userId,
    String baseUrl = 'ws://localhost:8081',
  }) async {
    if (_isConnected) {
      debugPrint('[MessageWebSocket] Already connected');
      return;
    }

    try {
      _currentUserId = userId;
      final wsUrl = Uri.parse('$baseUrl/ws/messages?token=$token');

      debugPrint('[MessageWebSocket] 🔗 Attempting to connect to $wsUrl');
      _webSocket = WebSocketChannel.connect(wsUrl);

      debugPrint(
        '[MessageWebSocket] 🔗 WebSocket channel created, setting up listeners...',
      );

      // Listen for incoming messages
      _webSocket!.stream.listen(
        (message) {
          debugPrint('[MessageWebSocket] 📩 RAW DATA RECEIVED: $message');
          _handleMessage(message);
        },
        onError: (error) {
          debugPrint('[MessageWebSocket] ❌ Stream Error: $error');
          _isConnected = false;
        },
        onDone: () {
          debugPrint('[MessageWebSocket] ⚠️  Connection closed by server');
          _isConnected = false;
          _cleanup();
        },
      );

      _isConnected = true;
      debugPrint(
        '[MessageWebSocket] ✓ Connected successfully and listening for messages',
      );

      // Start heartbeat
      _startHeartbeat();
    } catch (e, st) {
      AppExceptionLogger.log(
        e,
        stackTrace: st,
        context: 'MessageWebSocketService.connect',
      );
      _isConnected = false;
      rethrow;
    }
  }

  /// Subscribe to a specific chat
  void subscribeToChat(String chatId) {
    _currentChatId = chatId;
    debugPrint('[MessageWebSocket] 📦 Subscribing to chat: $chatId');

    if (!_isConnected || _webSocket == null) {
      debugPrint(
        '[MessageWebSocket] ⚠️  Not connected, cannot subscribe to chat',
      );
      return;
    }

    try {
      _webSocket!.sink.add(jsonEncode({'type': 'subscribe', 'chatId': chatId}));
      debugPrint(
        '[MessageWebSocket] ✓ Sent subscribe message for chat: $chatId',
      );
    } catch (e) {
      debugPrint('[MessageWebSocket] ❌ Failed to send subscribe message: $e');
    }
  }

  /// Unsubscribe from current chat
  void unsubscribeFromChat() {
    _currentChatId = null;
    debugPrint('[MessageWebSocket] 📦 Unsubscribed from chat');
  }

  /// Send a typing indicator
  void sendTyping({required String chatId}) {
    if (!_isConnected || _webSocket == null) {
      print(
        '[MessageWebSocket] ⚠️  Not connected, cannot send typing indicator',
      );
      return;
    }

    try {
      final event = {
        'type': 'user_typing',
        'chatId': chatId,
        'data': {'userId': _currentUserId},
      };
      _webSocket!.sink.add(jsonEncode(event));
      debugPrint('[MessageWebSocket] 📤 Sent typing indicator');

      // Debounce: cancel previous timer and set new one
      _typingDebounceTimer?.cancel();
      _typingDebounceTimer = Timer(Duration(seconds: 3), () {
        sendStoppedTyping(chatId: chatId);
      });
    } catch (e) {
      debugPrint('[MessageWebSocket] ❌ Failed to send typing indicator: $e');
    }
  }

  /// Send stopped typing indicator
  void sendStoppedTyping({required String chatId}) {
    if (!_isConnected || _webSocket == null) return;

    try {
      final event = {
        'type': 'user_stopped_typing',
        'chatId': chatId,
        'data': {'userId': _currentUserId},
      };
      _webSocket!.sink.add(jsonEncode(event));
      debugPrint('[MessageWebSocket] 📤 Sent stopped typing indicator');
    } catch (e) {
      debugPrint('[MessageWebSocket] ❌ Failed to send stopped typing: $e');
    }
  }

  /// Disconnect from WebSocket
  Future<void> disconnect() async {
    try {
      _typingDebounceTimer?.cancel();
      _heartbeatTimer?.cancel();

      if (_webSocket != null) {
        await _webSocket!.sink.close();
      }

      _isConnected = false;
      _currentUserId = null;
      _currentChatId = null;

      debugPrint('[MessageWebSocket] 🔌 Disconnected');
    } catch (e, st) {
      AppExceptionLogger.log(
        e,
        stackTrace: st,
        context: 'MessageWebSocketService.disconnect',
      );
    }
  }

  /// Handle incoming WebSocket message
  void _handleMessage(dynamic message) {
    try {
      debugPrint(
        '[MessageWebSocket] 🔍 Processing message type: ${message.runtimeType}',
      );

      if (message is String) {
        final previewLength = message.length > 100 ? 100 : message.length;
        debugPrint(
          '[MessageWebSocket] 🔍 Parsing JSON: ${message.substring(0, previewLength)}...',
        );
        final json = jsonDecode(message) as Map<String, dynamic>;
        debugPrint('[MessageWebSocket] ✓ JSON decoded: $json');

        var event = WebSocketEvent.fromJson(json);
        debugPrint(
          '[MessageWebSocket] ✓ Event parsed: type=${event.type.name}, chatId=${event.chatId}',
        );

        // Use current chat ID if not in event
        if (event.chatId.isEmpty && _currentChatId != null) {
          event = WebSocketEvent(
            type: event.type,
            chatId: _currentChatId!,
            data: event.data,
          );
          debugPrint(
            '[MessageWebSocket] ✓ Updated event chatId to $_currentChatId',
          );
        }

        debugPrint(
          '[MessageWebSocket] 📨 Received ${event.type.name} for chat ${event.chatId}',
        );

        // Check if this is a typing indicator wrapped in messageCreated
        if (event.type == WebSocketEventType.messageCreated &&
            event.data['type'] == 'typing_indicator') {
          final isTyping = event.data['isTyping'] as bool? ?? true;
          debugPrint(
            '[MessageWebSocket] 🎹 TYPING_INDICATOR: userId=${event.data['userId']}, isTyping=$isTyping',
          );
          _typingIndicatorsController.add((
            userId: event.data['userId'] as String? ?? '',
            chatId: event.chatId,
            isTyping: isTyping,
          ));
          debugPrint('[MessageWebSocket] ✓ Added to typing indicators stream');
        } else if (event.type != WebSocketEventType.unknown &&
            event.type != WebSocketEventType.ping &&
            event.type != WebSocketEventType.pong) {
          // Emit real message events to stream (skip ping/pong and unknown)
          debugPrint(
            '[MessageWebSocket] 💬 Adding event to eventStream: ${event.type.name}',
          );
          _eventStreamController.add(event);
          debugPrint('[MessageWebSocket] ✓ Event added to stream');
        } else {
          debugPrint(
            '[MessageWebSocket] ⏭️  Skipping event: ${event.type.name}',
          );
        }
      } else {
        debugPrint(
          '[MessageWebSocket] ⚠️  Received non-string message: $message',
        );
      }
    } catch (e, st) {
      AppExceptionLogger.log(
        e,
        stackTrace: st,
        context: 'MessageWebSocketService._handleMessage',
      );
    }
  }

  /// Start heartbeat to keep connection alive
  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(Duration(seconds: 30), (_) {
      if (_isConnected && _webSocket != null) {
        try {
          _webSocket!.sink.add(jsonEncode({'type': 'ping'}));
        } catch (e, st) {
          AppExceptionLogger.log(
            e,
            stackTrace: st,
            context: 'MessageWebSocketService._startHeartbeat',
          );
        }
      }
    });
  }

  /// Cleanup resources
  void _cleanup() {
    _typingDebounceTimer?.cancel();
    _heartbeatTimer?.cancel();
  }

  /// Dispose service
  void dispose() {
    disconnect();
    _eventStreamController.close();
    _typingIndicatorsController.close();
  }
}
