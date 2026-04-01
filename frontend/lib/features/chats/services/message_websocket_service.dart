import 'dart:async';
import 'dart:convert';
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
  chatDeleted, // Chat was deleted by the other participant
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
        ({String userId, String username, String chatId, bool isTyping})
      >.broadcast();

  String? _currentUserId;
  String? _currentChatId;
  Timer? _typingDebounceTimer;
  Timer? _heartbeatTimer;
  bool _isConnected = false;

  /// Stream of WebSocket events
  Stream<WebSocketEvent> get eventStream => _eventStreamController.stream;

  /// Stream of typing indicators
  Stream<({String userId, String username, String chatId, bool isTyping})>
  get typingIndicators => _typingIndicatorsController.stream;

  /// Check if WebSocket is connected
  bool get isConnected => _isConnected;

  /// Connect to WebSocket server
  Future<void> connect({
    required String token,
    required String userId,
    String baseUrl = 'wss://web-messenger-cy3r.onrender.com',
  }) async {
    if (_isConnected) {
      return;
    }

    try {
      _currentUserId = userId;
      final wsUrl = Uri.parse('$baseUrl/api/ws/messages?token=$token');

      _webSocket = WebSocketChannel.connect(wsUrl);


      // Listen for incoming messages
      _webSocket!.stream.listen(
        (message) {
          _handleMessage(message);
        },
        onError: (error) {
          _isConnected = false;
        },
        onDone: () {
          _isConnected = false;
          _cleanup();
        },
      );

      _isConnected = true;

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

    if (!_isConnected || _webSocket == null) {
      return;
    }

    try {
      _webSocket!.sink.add(jsonEncode({'type': 'subscribe', 'chatId': chatId}));
    } catch (e, st) {
      AppExceptionLogger.log(
        e,
        stackTrace: st,
        context: 'MessageWebSocketService.subscribeToChat',
      );
    }
  }

  /// Unsubscribe from current chat
  void unsubscribeFromChat() {
    _currentChatId = null;
  }

  /// Send a typing indicator
  void sendTyping({required String chatId}) {
    if (!_isConnected || _webSocket == null) {
      return;
    }

    try {
      final event = {
        'type': 'user_typing',
        'chatId': chatId,
        'data': {'userId': _currentUserId},
      };
      _webSocket!.sink.add(jsonEncode(event));

      // Debounce: cancel previous timer and set new one
      _typingDebounceTimer?.cancel();
      _typingDebounceTimer = Timer(Duration(seconds: 3), () {
        sendStoppedTyping(chatId: chatId);
      });
    } catch (e, st) {
      AppExceptionLogger.log(
        e,
        stackTrace: st,
        context: 'MessageWebSocketService.sendTyping',
      );
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
    } catch (e, st) {
      AppExceptionLogger.log(
        e,
        stackTrace: st,
        context: 'MessageWebSocketService.sendStoppedTyping',
      );
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

      if (message is String) {
        final json = jsonDecode(message) as Map<String, dynamic>;

        var event = WebSocketEvent.fromJson(json);

        // Use current chat ID if not in event
        if ((event.chatId == null || event.chatId!.isEmpty) && _currentChatId != null) {
          event = WebSocketEvent(
            type: event.type,
            chatId: _currentChatId!,
            data: event.data,
          );
        }


        // Check if this is a typing indicator wrapped in messageCreated
        if (event.type == WebSocketEventType.messageCreated &&
            event.data['type'] == 'typing_indicator') {
          final isTyping = event.data['isTyping'] as bool? ?? true;
          _typingIndicatorsController.add((
            userId: event.data['userId'] as String? ?? '',
            username: event.data['username'] as String? ?? 'Unknown',
            chatId: event.chatId ?? '',
            isTyping: isTyping,
          ));
        } else if (event.type != WebSocketEventType.unknown &&
            event.type != WebSocketEventType.ping &&
            event.type != WebSocketEventType.pong) {
          // Emit real message events to stream (skip ping/pong and unknown)
          _eventStreamController.add(event);
        } else {
        }
      } else {
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
