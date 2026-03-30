import 'package:shelf/shelf.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';
import 'package:postgres/postgres.dart';

import '../services/websocket_service.dart';
import '../services/jwt_service.dart';
import '../services/auth_exception.dart';

typedef Connection = PostgreSQLConnection;

/// WebSocket handler for real-time message delivery
///
/// Simplified approach: Let shelf_web_socket handle the upgrade,
/// validate token AFTER upgrade, then handle messages
class WebSocketHandler {
  static final _webSocketService = WebSocketService();

  /// Create WebSocket handler with proper upgrade handling
  ///
  /// URL: GET /ws/messages?token=<jwt_token>
  static Handler createWebSocketHandler(Connection connection,
      {Request? request}) {
    return webSocketHandler((webSocket, protocol) {
      _handleWebSocketConnection(webSocket, connection, request);
    });
  }

  /// Handle WebSocket connection after upgrade
  static void _handleWebSocketConnection(
    WebSocketChannel webSocket,
    Connection connection,
    Request? request,
  ) {
    // Extract token from request URL (if available)
    String? token;
    String? userId;

    try {
      if (request != null) {
        token = request.url.queryParameters['token'];
      }

      if (token == null) {
        webSocket.sink.close(1008, 'Token required');
        return;
      }

      // Validate token
      try {
        final payload = JwtService.validateToken(token);
        userId = payload.userId;
      } on AuthException catch (e) {
        print('[WebSocket] ❌ Token validation failed: $e');
        webSocket.sink.close(1008, 'Invalid token');
        return;
      }

      _webSocketService.addUserConnection(userId, webSocket);

      // Handle incoming messages in background
      webSocket.stream.listen(
        (message) => _processMessage(webSocket, message, userId, connection),
        onError: (error) {
          print('[WebSocket] ❌ Connection error: $error');
        },
        onDone: () {
          if (userId != null) {
            _webSocketService.removeUserConnection(userId, webSocket);
          }
        },
      );
    } catch (e) {
      print('[WebSocket] ❌ Unexpected error: $e');
      try {
        webSocket.sink.close(1011, 'Server error');
      } catch (_) {}
    }
  }

  /// Process incoming WebSocket message
  static void _processMessage(
    WebSocketChannel webSocket,
    dynamic message,
    String? userId,
    Connection connection,
  ) {
    if (message is! String) return;

    try {
      final json = jsonDecode(message) as Map<String, dynamic>;
      final type = json['type'] as String?;

      if (type == null) {
        return;
      }

      // Special handling for ping (doesn't need chatId)
      if (type == 'ping') {
        webSocket.sink.add(jsonEncode({'type': 'pong'}));
        return;
      }

      // All other message types require chatId
      final chatId = json['chatId'] as String?;
      if (chatId == null) {
        return;
      }

      // Route by message type
      switch (type) {
        case 'subscribe':
          _webSocketService.addConnection(chatId, webSocket);
          break;

        case 'message.sent':
          final event = WebSocketEvent(
            type: WebSocketEventType.messageCreated,
            chatId: chatId,
            data: {'chatId': chatId, 'userId': userId, ...json['data'] ?? {}},
          );
          _webSocketService.broadcastToChat(chatId, event);
          break;

        case 'typing.start':
        case 'user_typing':
          // Fetch username async for typing indicator
          _fetchAndBroadcastTypingStart(webSocket, chatId, userId, connection);
          break;

        case 'typing.stop':
        case 'user_stopped_typing':
          // Fetch username async for typing indicator
          _fetchAndBroadcastTypingStop(webSocket, chatId, userId, connection);
          break;

        default:
          // Ignore unknown message types to keep logs clean.
          break;
      }
    } catch (e) {
      print('[WebSocket] ❌ Error processing message: $e');
    }
  }

  /// Fetch username and broadcast typing start event
  static void _fetchAndBroadcastTypingStart(
    WebSocketChannel webSocket,
    String chatId,
    String? userId,
    Connection connection,
  ) async {
    String? username;
    try {
      final userRows = await connection.query(
        'SELECT username FROM users WHERE id = @id LIMIT 1',
        substitutionValues: {'id': userId},
      );
      if (userRows.isNotEmpty) {
        username = userRows.first[0] as String?;
      }
    } catch (e) {
      print('[WebSocket] Error fetching username for typing indicator: $e');
    }
    
    final event = WebSocketEvent(
      type: WebSocketEventType.messageCreated,
      chatId: chatId,
      data: {
        'chatId': chatId,
        'type': 'typing_indicator',
        'userId': userId,
        'username': username ?? 'Unknown',
        'isTyping': true,
      },
    );
    _webSocketService.broadcastToChat(chatId, event);
  }

  /// Fetch username and broadcast typing stop event
  static void _fetchAndBroadcastTypingStop(
    WebSocketChannel webSocket,
    String chatId,
    String? userId,
    Connection connection,
  ) async {
    String? username;
    try {
      final userRows = await connection.query(
        'SELECT username FROM users WHERE id = @id LIMIT 1',
        substitutionValues: {'id': userId},
      );
      if (userRows.isNotEmpty) {
        username = userRows.first[0] as String?;
      }
    } catch (e) {
      print('[WebSocket] Error fetching username for typing indicator: $e');
    }
    
    final event = WebSocketEvent(
      type: WebSocketEventType.messageCreated,
      chatId: chatId,
      data: {
        'chatId': chatId,
        'type': 'typing_indicator',
        'userId': userId,
        'username': username ?? 'Unknown',
        'isTyping': false,
      },
    );
    _webSocketService.broadcastToChat(chatId, event);
  }
}
