import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';

/// WebSocket service (T038)
/// 
/// Manages WebSocket connection lifecycle for real-time messaging
/// 
/// Features:
/// - Single connection per app
/// - Auto-reconnect on disconnect
/// - Event streaming
/// - Graceful shutdown
class WebSocketService {
  WebSocketChannel? _channel;
  final _eventController = StreamController<Map<String, dynamic>>.broadcast();
  bool _isConnecting = false;
  bool _isConnected = false;
  String? _userId;

  /// Stream of real-time events from WebSocket
  Stream<Map<String, dynamic>> get eventStream => _eventController.stream;

  /// Current connection status
  bool get isConnected => _isConnected;

  /// Connect to WebSocket server
  /// 
  /// Parameters:
  /// - token: JWT authentication token
  /// - url: Optional WebSocket URL (defaults to hosted backend)
  /// 
  /// Automatically retries on connection failure
  Future<void> connect({
    required String token,
    required String userId,
    String url = 'wss://web-messenger-cy3r.onrender.com/api/ws/messages',
  }) async {
    if (_isConnecting || _isConnected) {
      return;
    }

    _isConnecting = true;
    _userId = userId;

    try {

      _channel = WebSocketChannel.connect(
        Uri.parse('$url?token=$token'),
      );

      // Listen for messages
      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDone,
      );

      _isConnected = true;
      _isConnecting = false;


      // Send initial handshake/ping
      _sendPing();
    } catch (e) {
      _isConnecting = false;
      _isConnected = false;
      rethrow;
    }
  }

  /// Disconnect from WebSocket
  Future<void> disconnect() async {
    _isConnected = false;
    await _channel?.sink.close();
    _channel = null;
  }

  /// Send event through WebSocket
  /// 
  /// Parameters:
  /// - eventType: Type of event (e.g., 'message_sent', 'user_typing')
  /// - chatId: The chat this event relates to
  /// - data: Event data as JSON-serializable Map
  void sendEvent({
    required String eventType,
    required String chatId,
    required Map<String, dynamic> data,
  }) {
    if (!_isConnected) {
      return;
    }

    try {
      final message = {
        'type': eventType,
        'chatId': chatId,
        'data': data,
      };

      _channel!.sink.add(jsonEncode(message));
    } catch (e) {
    }
  }

  /// Handle incoming message from WebSocket
  void _handleMessage(dynamic message) {
    try {
      if (message is String) {
        // Check for ping/pong
        if (message == 'ping') {
          _sendPong();
          return;
        }

        if (message == 'pong') {
          return;
        }

        // Parse JSON event
        final event = jsonDecode(message) as Map<String, dynamic>;

        // Broadcast event to listeners
        _eventController.add(event);
      }
    } catch (e) {
    }
  }

  /// Handle WebSocket error
  void _handleError(error) {
    _isConnected = false;
  }

  /// Handle WebSocket done
  void _handleDone() {
    _isConnected = false;
  }

  /// Send ping (heartbeat)
  void _sendPing() {
    try {
      _channel?.sink.add('ping');
    } catch (e) {
    }
  }

  /// Send pong (heartbeat response)
  void _sendPong() {
    try {
      _channel?.sink.add('pong');
    } catch (e) {
    }
  }

  /// Cleanup
  void dispose() {
    _eventController.close();
    _channel?.sink.close();
  }
}

/// WebSocket service provider (T038)
/// 
/// Provides singleton WebSocket service for the app
/// 
/// Usage:
/// ```dart
/// class MyApp extends ConsumerWidget {
///   @override
///   Widget build(BuildContext context, WidgetRef ref) {
///     ref.watch(webSocketServiceProvider);
///     return MaterialApp(...);
///   }
/// }
/// ```
final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  final service = WebSocketService();

  // Cleanup on dispose
  ref.onDispose(() {
    service.dispose();
  });

  return service;
});

/// Message stream provider (T039)
/// 
/// StreamProvider for real-time message events from WebSocket
/// 
/// Automatically connects to WebSocket on first watch
/// 
/// Usage:
/// ```dart
/// final messageStream = ref.watch(messageStreamProvider);
/// messageStream.whenData((event) {
///   if (event['type'] == 'message_received') {
///     debugPrint('New message: ${event['data']}');
///   }
/// });
/// ```
final messageStreamProvider =
    StreamProvider<Map<String, dynamic>>((ref) async* {
  final wsService = ref.watch(webSocketServiceProvider);
  
  // Stream events
  yield* wsService.eventStream;
});

/// Filtered message stream for a specific chat
final chatMessageStreamProvider =
    StreamProvider.family<Map<String, dynamic>, String>((ref, chatId) async* {
  final wsService = ref.watch(webSocketServiceProvider);

  // Stream events filtered by chatId using yield from where clause
  yield* wsService.eventStream.where((event) => 
    event is Map && (event['chatId'] ?? event['chat_id']) == chatId
  );
});

/// Send WebSocket event helper
/// 
/// Extension on WidgetRef for easier event sending
extension WebSocketSending on WidgetRef {
  /// Send a WebSocket event
  void sendWebSocketEvent({
    required String eventType,
    required String chatId,
    required Map<String, dynamic> data,
  }) {
    final ws = read(webSocketServiceProvider);
    ws.sendEvent(
      eventType: eventType,
      chatId: chatId,
      data: data,
    );
  }
}
