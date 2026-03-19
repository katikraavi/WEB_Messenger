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
/// Handles:
/// - Upgrade HTTP connection to WebSocket (T032)
/// - Parse and validate incoming events (T033)
/// - Broadcast messages to both chat participants (T033)
/// - Error handling and graceful disconnection
/// 
/// WebSocket message format (JSON):
/// {
///   "type": "subscribe|message.sent|typing.start|typing.stop",
///   "chatId": "chat-uuid",
///   "data": {...}
/// }
class WebSocketHandler {
  static final _webSocketService = WebSocketService();
  
  /// Cached token from server.dart (hacky but works with shelf limitations)
  static String? _cachedToken;

  /// Handle WebSocket upgrade request and authenticated connection
  /// 
  /// URL: GET /ws/messages?token=<jwt_token>
  static Handler createWebSocketHandler(Connection connection, {String? token}) {
    // Store token for use in handler callback
    _cachedToken = token;
    
    return webSocketHandler((webSocket, protocol) {
      _handleWebSocketConnection(webSocket, connection);
    });
  }

  /// Handle individual WebSocket connection
  static Future<void> _handleWebSocketConnection(
    WebSocketChannel webSocket,
    Connection connection,
  ) async {
    String? userId;
    String? currentChatId;

    try {
      // Use pre-validated token from server.dart
      final token = _cachedToken;
      if (token == null) {
        print('[WebSocket] ❌ No token provided, closing connection');
        await webSocket.sink.close(1008, 'Authentication token required');
        return;
      }

      // Validate JWT token
      try {
        final payload = JwtService.validateToken(token);
        userId = payload.userId;
        print('[WebSocket] ✓ Authenticated user: $userId');
      } on AuthException catch (e) {
        print('[WebSocket] ❌ Authentication failed: $e');
        await webSocket.sink.close(1008, 'Invalid token');
        return;
      }

      // Listen for incoming messages
      await for (final message in webSocket.stream) {
        if (message is! String) continue;

        try {
          final json = jsonDecode(message) as Map<String, dynamic>;
          final eventType = json['type'] as String?;
          final chatId = json['chatId'] as String?;

          if (eventType == null || chatId == null) {
            print('[WebSocket] ⚠️  Missing event type or chatId in message: $message');
            continue;
          }

          // Verify user is a participant in this chat (on first message)
          if (currentChatId != chatId) {
            final isParticipant = await _isUserChatParticipant(
              connection,
              chatId,
              userId,
            );
            if (!isParticipant) {
              print('[WebSocket] ⚠️  User $userId not a participant in chat $chatId');
              continue;
            }
            currentChatId = chatId;
          }

          // Route the message based on type
          switch (eventType) {
            case 'subscribe':
              _webSocketService.addConnection(chatId, webSocket);
              print('[WebSocket] 📦 Subscribed to chat: $chatId');
              break;

            case 'message.sent':
              // Broadcast message event to all connections in this chat
              final event = WebSocketEvent(
                type: WebSocketEventType.messageCreated,
                data: {'userId': userId, ...json['data'] ?? {}},
              );
              await _webSocketService.broadcastToChatAsync(chatId, event);
              print('[WebSocket] 📨 Broadcasted message in chat $chatId from user $userId');
              break;

            case 'typing.start':
              // Broadcast typing indicator
              final event = WebSocketEvent(
                type: WebSocketEventType.messageCreated,
                data: {
                  'type': 'typing_indicator',
                  'userId': userId,
                  'isTyping': true,
                  ...json['data'] ?? {},
                },
              );
              await _webSocketService.broadcastToChatAsync(chatId, event);
              print('[WebSocket] ✍️  Typing indicator for user $userId in chat $chatId');
              break;

            case 'typing.stop':
              // Broadcast typing stopped
              final event = WebSocketEvent(
                type: WebSocketEventType.messageCreated,
                data: {
                  'type': 'typing_indicator',
                  'userId': userId,
                  'isTyping': false,
                  ...json['data'] ?? {},
                },
              );
              await _webSocketService.broadcastToChatAsync(chatId, event);
              print('[WebSocket] Typing stopped for user $userId in chat $chatId');
              break;

            default:
              print('[WebSocket] ⚠️  Unknown event type: $eventType');
          }
        } catch (e) {
          print('[WebSocket] ❌ Error processing message: $e');
        }
      }
    } catch (e) {
      print('[WebSocket] ❌ Connection error: $e');
    }
  }

  /// Extract JWT token from WebSocket URL
  /// shelf_web_socket passes the original request URL
  static String? _extractTokenFromRequest(WebSocketChannel socket) {
    try {
      // shelf_web_socket limitations - we'll need to pass token via storage
      // For now, try to extract from protocol headers if available
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Check if user is a participant in a chat
  static Future<bool> _isUserChatParticipant(
    Connection connection,
    String chatId,
    String userId,
  ) async {
    try {
      final result = await connection.query(
        r'SELECT EXISTS('
        r'  SELECT 1 FROM chats '
        r'  WHERE id = @chatId AND ('
        r'    participant_1_id = @userId OR participant_2_id = @userId'
        r'  )'
        r') as is_participant',
        substitutionValues: {'chatId': chatId, 'userId': userId},
      );

      if (result.isEmpty) return false;
      final row = result.first.toColumnMap();
      return row['is_participant'] as bool? ?? false;
    } catch (e) {
      print('[WebSocketHandler] Error checking participant: $e');
      return false;
    }
  }
}
