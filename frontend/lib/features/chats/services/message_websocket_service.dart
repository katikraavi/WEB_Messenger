import 'dart:async';
import 'dart:convert';
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
      print('[WebSocketEventType] ⚠️  Unknown event type: $value');
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
      print('[MessageWebSocket] Already connected');
      return;
    }

    try {
      _currentUserId = userId;
      final wsUrl = Uri.parse('$baseUrl/ws/messages?token=$token');

      print('[MessageWebSocket] 🔗 Attempting to connect to $wsUrl');
      _webSocket = WebSocketChannel.connect(wsUrl);

      print('[MessageWebSocket] 🔗 WebSocket channel created, setting up listeners...');

      // Listen for incoming messages
      _webSocket!.stream.listen(
        (message) {
          print('[MessageWebSocket] 📩 RAW DATA RECEIVED: $message');
          _handleMessage(message);
        },
        onError: (error) {
          print('[MessageWebSocket] ❌ Stream Error: $error');
          _isConnected = false;
        },
        onDone: () {
          print('[MessageWebSocket] ⚠️  Connection closed by server');
          _isConnected = false;
          _cleanup();
        },
      );

      _isConnected = true;
      print('[MessageWebSocket] ✓ Connected successfully and listening for messages');

      // Start heartbeat
      _startHeartbeat();
    } catch (e) {
      print('[MessageWebSocket] ❌ Failed to connect: $e');
      _isConnected = false;
      rethrow;
    }
  }

  /// Subscribe to a specific chat
  void subscribeToChat(String chatId) {
    _currentChatId = chatId;
    print('[MessageWebSocket] 📦 Subscribing to chat: $chatId');
    
    if (!_isConnected || _webSocket == null) {
      print('[MessageWebSocket] ⚠️  Not connected, cannot subscribe to chat');
      return;
    }
    
    try {
      _webSocket!.sink.add(jsonEncode({
        'type': 'subscribe',
        'chatId': chatId,
      }));
      print('[MessageWebSocket] ✓ Sent subscribe message for chat: $chatId');
    } catch (e) {
      print('[MessageWebSocket] ❌ Failed to send subscribe message: $e');
    }
  }

  /// Unsubscribe from current chat
  void unsubscribeFromChat() {
    _currentChatId = null;
    print('[MessageWebSocket] 📦 Unsubscribed from chat');
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
      print('[MessageWebSocket] 📤 Sent typing indicator');

      // Debounce: cancel previous timer and set new one
      _typingDebounceTimer?.cancel();
      _typingDebounceTimer = Timer(Duration(seconds: 3), () {
        sendStoppedTyping(chatId: chatId);
      });
    } catch (e) {
      print('[MessageWebSocket] ❌ Failed to send typing indicator: $e');
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
      print('[MessageWebSocket] 📤 Sent stopped typing indicator');
    } catch (e) {
      print('[MessageWebSocket] ❌ Failed to send stopped typing: $e');
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

      print('[MessageWebSocket] 🔌 Disconnected');
    } catch (e) {
      print('[MessageWebSocket] ❌ Error disconnecting: $e');
    }
  }

  /// Handle incoming WebSocket message
  void _handleMessage(dynamic message) {
    try {
      print('[MessageWebSocket] 🔍 Processing message type: ${message.runtimeType}');
      
      if (message is String) {
        final previewLength = message.length > 100 ? 100 : message.length;
        print('[MessageWebSocket] 🔍 Parsing JSON: ${message.substring(0, previewLength)}...');
        final json = jsonDecode(message) as Map<String, dynamic>;
        print('[MessageWebSocket] ✓ JSON decoded: $json');
        
        var event = WebSocketEvent.fromJson(json);
        print('[MessageWebSocket] ✓ Event parsed: type=${event.type.name}, chatId=${event.chatId}');

        // Use current chat ID if not in event
        if (event.chatId.isEmpty && _currentChatId != null) {
          event = WebSocketEvent(
            type: event.type,
            chatId: _currentChatId!,
            data: event.data,
          );
          print('[MessageWebSocket] ✓ Updated event chatId to $_currentChatId');
        }

        print('[MessageWebSocket] 📨 Received ${event.type.name} for chat ${event.chatId}');

        // Check if this is a typing indicator wrapped in messageCreated
        if (event.type == WebSocketEventType.messageCreated &&
            event.data['type'] == 'typing_indicator') {
          final isTyping = event.data['isTyping'] as bool? ?? true;
          print('[MessageWebSocket] 🎹 TYPING_INDICATOR: userId=${event.data['userId']}, isTyping=$isTyping');
          _typingIndicatorsController.add((
            userId: event.data['userId'] as String? ?? '',
            chatId: event.chatId,
            isTyping: isTyping,
          ));
          print('[MessageWebSocket] ✓ Added to typing indicators stream');
        } else if (event.type != WebSocketEventType.unknown &&
            event.type != WebSocketEventType.ping &&
            event.type != WebSocketEventType.pong) {
          // Emit real message events to stream (skip ping/pong and unknown)
          print('[MessageWebSocket] 💬 Adding event to eventStream: ${event.type.name}');
          _eventStreamController.add(event);
          print('[MessageWebSocket] ✓ Event added to stream');
        } else {
          print('[MessageWebSocket] ⏭️  Skipping event: ${event.type.name}');
        }
      } else {
        print('[MessageWebSocket] ⚠️  Received non-string message: $message');
      }
    } catch (e, st) {
      print('[MessageWebSocket] ❌ Error handling message: $e');
      print('[MessageWebSocket] Stack trace: $st');
    }
  }

  /// Start heartbeat to keep connection alive
  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(Duration(seconds: 30), (_) {
      if (_isConnected && _webSocket != null) {
        try {
          _webSocket!.sink.add(jsonEncode({'type': 'ping'}));
        } catch (e) {
          print('[MessageWebSocket] ❌ Heartbeat failed: $e');
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
