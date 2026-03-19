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
/// - Heartbeat/keep-alive ping/pong (T035)
/// - Error handling and graceful disconnection
/// 
/// WebSocket message format (JSON):
/// {
///   "type": "message_sent|message_received|user_typing|archive_status",
///   "chatId": "chat-uuid",
///   "data": {...}
/// }
class WebSocketHandler {
  static final _webSocketService = WebSocketService();

  /// Handle WebSocket upgrade request and authenticated connection
  /// 
  /// URL: GET /ws/messages?token=<jwt_token>
  /// 
  /// Requires: Valid JWT token in query parameters or Authorization header
  /// 
  /// After upgrade, server sends heartbeat ping every 30 seconds (T035)
  static Handler createWebSocketHandler(Connection connection) {
    return webSocketHandler((webSocket, protocol) async {
      String? userId;
      String? currentChatId;
        final token = _extractTokenFromHeaders(webSocket) ??
            _extractTokenFromUrl(webSocket);
        if (token == null) {
          print('[WebSocket] ❌ No token provided, closing connection');
          await webSocket.sink.close(
            1008, // Policy Violation
            'Authentication token required',
          );
          return;
        }

        String? userId;
        try {
          final payload = JwtService.validateToken(token);
          userId = payload.userId;
          print('[WebSocket] ✓ Authenticated user: $userId');
        } on AuthException catch (e) {
          print('[WebSocket] ❌ Authentication failed: $e');
          await webSocket.sink.close(1008, 'Invalid token');
          return;
        }

        // Add connection to WebSocket service
        _webSocketService.addConnection(userId, webSocket);
        print('[WebSocket] ✓ Connection established for user: $userId');

        // Start heartbeat (T035)
        var lastPongTime = DateTime.now();
        var heartbeatInterval = DateTime.now();

        // Handle incoming messages (T033)
        await for (final message in webSocket.stream) {
          try {
            if (message is String) {
              final json = jsonDecode(message) as Map<String, dynamic>;
              final eventType = json['type'] as String?;
              final chatId = json['chatId'] as String?;

              if (eventType == null || chatId == null) {
                print(
                    '[WebSocket] ⚠️  Invalid message format: missing type or chatId');
                continue;
              }

              // Verify user is a participant in this chat
              final isParticipant = await _isUserChatParticipant(
                connection,
                chatId,
                userId,
              );
              if (!isParticipant) {
                print(
                    '[WebSocket] ⚠️  User $userId not participant in chat $chatId');
                continue;
              }

              // Route to appropriate handler
              switch (eventType) {
                case 'message_sent':
                  print(
                      '[WebSocket] Message sent in chat $chatId from user $userId');
                  // Extract message data
                  final data = json['data'] as Map<String, dynamic>?;
                  if (data != null) {
                    // Broadcast to other participant (T033)
                    await _broadcastMessageToChat(
                      chatId,
                      userId,
                      'message_received',
                      data,
                    );
                  }
                  break;

                case 'user_typing':
                  print(
                      '[WebSocket] User typing indicator in chat $chatId from user $userId');
                  // Broadcast typing indicator
                  final data = json['data'] as Map<String, dynamic>?;
                  if (data != null) {
                    await _broadcastMessageToChat(
                      chatId,
                      userId,
                      'user_typing',
                      data,
                    );
                  }
                  break;

                case 'archive_status':
                  print(
                      '[WebSocket] Archive status changed in chat $chatId from user $userId');
                  // Broadcast archive status to other participant
                  final data = json['data'] as Map<String, dynamic>?;
                  if (data != null) {
                    await _broadcastMessageToChat(
                      chatId,
                      userId,
                      'archive_status',
                      data,
                    );
                  }
                  break;

                case 'pong':
                  lastPongTime = DateTime.now();
                  print('[WebSocket] ✓ Pong received from user: $userId');
                  break;

                default:
                  print('[WebSocket] ⚠️  Unknown event type: $eventType');
              }
            }
          } catch (e) {
            print('[WebSocket] ❌ Error processing message: $e');
          }

          // Check for heartbeat timeout (send ping if needed)
          if (DateTime.now().difference(heartbeatInterval).inSeconds >= 30) {
            try {
              webSocket.sink.add('ping');
              heartbeatInterval = DateTime.now();
              print('[WebSocket] Ping sent to user: $userId');
            } catch (e) {
              print('[WebSocket] ❌ Error sending ping: $e');
              break;
            }
          }
        }
      } on AuthException catch (e) {
        print('[WebSocket] ❌ Auth error: $e');
      } catch (e) {
        print('[WebSocket] ❌ Unexpected error: $e');
      } finally {
        // Remove connection when socket closes
        if (userId != null) {
          _webSocketService.removeConnection(userId, webSocket);
          print('[WebSocket] ✓ Connection closed for user: $userId');
        }
      }
    });
  }

  /// Helper: Extract JWT token from WebSocket headers (if available)
  static String? _extractTokenFromHeaders(WebSocketChannel socket) {
    try {
      // In shelf_web_socket, we might not have direct access to headers
      // Try to get from protocol or similar
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Helper: Extract JWT token from WebSocket URL query parameters
  /// 
  /// URL format: ws://localhost:8081/ws/messages?token=eyJhbGc...
  static String? _extractTokenFromUrl(WebSocketChannel socket) {
    try {
      // This would need to be passed in from the handler
      // For now, return null and let auth happen via Authorization header
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Helper: Check if user is a participant in a chat
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

  /// Helper: Broadcast message to all connections in a chat (T033)
  /// 
  /// Broadcasts to all active WebSocket connections for both participants
  static Future<void> _broadcastMessageToChat(
    String chatId,
    String senderUserId,
    String eventType,
    Map<String, dynamic> data,
  ) async {
    try {
      final broadcastMessage = {
        'type': eventType,
        'chatId': chatId,
        'senderId': senderUserId,
        'timestamp': DateTime.now().toIso8601String(),
        ...data,
      };

      final json = jsonEncode(broadcastMessage);
      print('[WebSocket] Broadcasting: $eventType in chat $chatId');

      // The WebSocketService will handle routing to both participants
      await _webSocketService.broadcastToChatAsync(chatId, json);
    } catch (e) {
      print('[WebSocketHandler] Error broadcasting message: $e');
    }
  }
}
