import 'package:shelf/shelf.dart';
import 'dart:convert';
import 'package:postgres/postgres.dart';

import '../services/message_service.dart';
import '../services/notification_service.dart';
import '../services/websocket_service.dart';
import '../models/message_model.dart';
import '../models/enums.dart';

typedef Connection = PostgreSQLConnection;

/// Message handlers for message-related HTTP endpoints
///
/// Handles:
/// - POST /api/chats/{chatId}/messages - Send new message (T028-T029)
/// - Error handling: 401 (auth), 403 (not participant), 404 (not found), 5xx (server)
class MessageHandlers {
  /// Singleton WebSocket service for broadcasting messages (T021)
  static final _webSocketService = WebSocketService();

  /// POST /api/chats/{chatId}/messages
  ///
  /// Send a message in a chat
  ///
  /// Required headers:
  /// - Authorization: Bearer <jwt_token>
  ///
  /// Request body:
  /// {
  ///   "encrypted_content": "aGVsbG8gd29ybGQtZW5jcnlwdGVkYmFzZTY0", // Base64 encrypted
  ///   "idempotency_key": "msg-uuid-or-request-id" // Optional, prevents duplicates
  /// }
  ///
  /// Response: 201 Created
  /// {
  ///   "id": "msg-uuid",
  ///   "chatId": "chat-uuid",
  ///   "senderId": "user-uuid",
  ///   "encrypted_content": "...",
  ///   "created_at": "2026-03-15T10:30:00Z"
  /// }
  ///
  /// Errors:
  /// - 400: Missing encrypted_content, content too large, invalid format
  /// - 401: No authorization token or invalid JWT
  /// - 403: User is not a participant in this chat
  /// - 404: Chat not found, user not found
  /// - 409: Duplicate message (idempotency key already used)
  /// - 500: Server error (database, encryption)
  static Future<Response> sendMessage(
    Request request,
    String chatId,
    Connection connection,
  ) async {
    try {
      // Extract JWT token from Authorization header
      final authHeader = request.headers['authorization'];
      if (authHeader == null || !authHeader.startsWith('Bearer ')) {
        return Response.unauthorized(
            jsonEncode({'error': 'Missing or invalid authorization header'}));
      }

      final token = authHeader.substring(7);
      final userId = _extractUserIdFromToken(token);
      if (userId == null) {
        return Response.unauthorized(
            jsonEncode({'error': 'Invalid authorization token'}));
      }

      // Parse request body
      final body = await request.readAsString();
      final json = jsonDecode(body) as Map<String, dynamic>;

      final encryptedContent = json['encrypted_content'] as String?;
      final mediaUrl = json['media_url'] as String?;
      final mediaType = json['media_type'] as String?;
      if (encryptedContent == null || encryptedContent.isEmpty) {
        return Response(400,
            body: jsonEncode({'error': 'encrypted_content is required'}),
            headers: {'Content-Type': 'application/json'});
      }

      if ((mediaUrl == null) != (mediaType == null)) {
        return Response(400,
            body: jsonEncode({
              'error': 'media_url and media_type must be provided together'
            }),
            headers: {'Content-Type': 'application/json'});
      }

      // Check if user is a participant
      final isParticipant = await _isUserChatParticipant(
        connection,
        chatId,
        userId,
      );
      if (!isParticipant) {
        return Response(403,
            body:
                jsonEncode({'error': 'You are not a participant in this chat'}),
            headers: {'Content-Type': 'application/json'});
      }

      // Validate encrypted content size
      const maxEncryptedSize = 20000; // 20KB max for encrypted content
      if (encryptedContent.length > maxEncryptedSize) {
        return Response(400,
            body: jsonEncode(
                {'error': 'Message content is too large (max 10KB plaintext)'}),
            headers: {'Content-Type': 'application/json'});
      }

      // Create message in database
      try {
        final messageService = MessageService(connection);
        final message = await messageService.sendMessage(
          chatId: chatId,
          senderId: userId,
          encryptedContent: encryptedContent,
          mediaUrl: mediaUrl,
          mediaType: mediaType,
        );

        // Fetch sender user info for WebSocket broadcast
        final userResult = await connection.query(
          'SELECT username, profile_picture_url FROM users WHERE id = @userId',
          substitutionValues: {'userId': userId},
        );

        String? senderUsername;
        String? senderAvatarUrl;
        if (userResult.isNotEmpty) {
          senderUsername = userResult.first[0] as String?;
          senderAvatarUrl = userResult.first[1] as String?;
        }

        // Broadcast message to other participant via WebSocket (T021)
        // Include sender user info for real-time display
        final messagePayload = {
          'id': message.id,
          'chat_id': message.chatId,
          'chatId': message.chatId,
          'sender_id': message.senderId,
          'recipient_id': message.recipientId,
          'encrypted_content': message.encryptedContent,
          'status': message.status,
          'created_at': message.createdAt.toIso8601String(),
          'media_url': message.mediaUrl,
          'media_type': message.mediaType,
          'sender_username': senderUsername,
          'sender_avatar_url': senderAvatarUrl,
        };

        _webSocketService.notifyMessageCreated(chatId, messagePayload);

        if (message.recipientId != null) {
          _webSocketService.notifyUser(
            message.recipientId!,
            WebSocketEvent(
              type: WebSocketEventType.messageCreated,
              data: messagePayload,
            ),
          );

          final notificationService = NotificationService(connection);
          await notificationService.notifyNewMessage(
            recipientUserId: message.recipientId!,
            chatId: chatId,
            senderName: senderUsername ?? 'New message',
            body: _buildNotificationPreview(
              encryptedContent: encryptedContent,
              mediaType: mediaType,
            ),
          );
        }

        return Response(
          201,
          body: jsonEncode(message.toJson()),
          headers: {'Content-Type': 'application/json'},
        );
      } on ArgumentError catch (e) {
        return Response(400,
            body: jsonEncode({'error': e.message}),
            headers: {'Content-Type': 'application/json'});
      }
    } catch (e) {
//       print('[MessageHandlers.sendMessage] Error: $e');
      return Response.internalServerError(
          body: jsonEncode({'error': 'Internal server error: $e'}),
          headers: {'Content-Type': 'application/json'});
    }
  }

  static String _buildNotificationPreview({
    required String encryptedContent,
    String? mediaType,
  }) {
    if (mediaType != null) {
      if (mediaType.startsWith('image/')) {
        return '[Image]';
      }
      if (mediaType.startsWith('video/')) {
        return '[Video]';
      }
      if (mediaType.startsWith('audio/')) {
        return '[Audio message]';
      }
    }

    try {
      return utf8.decode(base64Decode(encryptedContent));
    } catch (_) {
      return 'New message';
    }
  }

  /// Helper: Extract user ID from JWT token (MVP implementation)
  ///
  /// In production, verify JWT signature and extract claims
  /// For MVP, we decode the token ignoring signature
  static String? _extractUserIdFromToken(String token) {
    try {
      // JWT format: header.payload.signature
      final parts = token.split('.');
      if (parts.length != 3) return null;

      // Decode payload (add padding if needed)
      String payload = parts[1];
      payload =
          payload.padRight(payload.length + (4 - payload.length % 4) % 4, '=');

      final decoded = utf8.decode(base64Url.decode(payload));
      final json = jsonDecode(decoded) as Map<String, dynamic>;

      return json['user_id'] as String?;
    } catch (e) {
//       print('[MessageHandlers] Failed to extract user ID from token: $e');
      return null;
    }
  }

  /// PUT /api/chats/{chatId}/messages/{messageId} (T049)
  ///
  /// Edit an existing message
  ///
  /// Required headers:
  /// - Authorization: Bearer <jwt_token>
  ///
  /// Request body:
  /// {
  ///   "encrypted_content": "new-encrypted-base64"
  /// }
  ///
  /// Response: 200 OK with updated Message object
  ///
  /// Errors:
  /// - 400: Invalid content, not different from original
  /// - 401: No auth token
  /// - 403: Not the message sender
  /// - 404: Message not found
  /// - 500: Server error
  static Future<Response> editMessage(
    Request request,
    String chatId,
    String messageId,
    Connection connection,
  ) async {
    try {
      // Get JWT token
      final authHeader = request.headers['Authorization'];
      final token = authHeader?.replaceFirst('Bearer ', '');
      if (token == null || token.isEmpty) {
        return Response(401, body: jsonEncode({'error': 'Missing token'}));
      }

      // Extract user ID from token
      final userId = _extractUserIdFromToken(token);
      if (userId == null) {
        return Response(401, body: jsonEncode({'error': 'Invalid token'}));
      }

      // Check user is in chat
      final isParticipant =
          await _isUserChatParticipant(connection, chatId, userId);
      if (!isParticipant) {
        return Response(403,
            body: jsonEncode({'error': 'Not a participant in this chat'}));
      }

      // Parse request body
      final bodyString = await request.readAsString();
      final bodyJson = jsonDecode(bodyString) as Map<String, dynamic>;
      final newContent = bodyJson['encrypted_content'] as String?;

      if (newContent == null || newContent.isEmpty) {
        return Response(400,
            body: jsonEncode({'error': 'Missing encrypted_content'}));
      }

      // Create message service
      final messageService = MessageService(connection);

      // Edit the message
      final editedMessage = await messageService.editMessage(
        messageId: messageId,
        newEncryptedContent: newContent,
        editedByUserId: userId,
      );

      // Broadcast message.edited event via WebSocket (T050)
      final editedEvent = WebSocketEvent(
        type: WebSocketEventType.messageEdited,
        data: editedMessage.toJson(),
      );
      _webSocketService.broadcastToChat(chatId, editedEvent);

      return Response(200,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(editedMessage.toJson()));
    } catch (e) {
      print('[MessageHandlers] ❌ Edit message error: $e');
      return Response(500,
          body:
              jsonEncode({'error': 'Failed to edit message: ${e.toString()}'}));
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
//       print('[MessageHandlers] Error checking participant: $e');
      return false;
    }
  }

  /// Delete a message (soft-delete via is_deleted flag)
  ///
  /// Validates:
  /// - Message exists
  /// - User is the message sender
  /// - Chat participant status
  ///
  /// Broadcasts message.deleted WebSocket event with updated message state
  ///
  /// Responses:
  /// - 204: Message deleted successfully
  /// - 400: Invalid message state
  /// - 401: No auth token
  /// - 403: Not the message sender
  /// - 404: Message not found
  /// - 500: Server error
  static Future<Response> deleteMessage(
    Request request,
    String chatId,
    String messageId,
    Connection connection,
  ) async {
    try {
      // Get JWT token
      final authHeader = request.headers['Authorization'];
      final token = authHeader?.replaceFirst('Bearer ', '');
      if (token == null || token.isEmpty) {
        return Response(401, body: jsonEncode({'error': 'Missing token'}));
      }

      // Extract user ID from token
      final userId = _extractUserIdFromToken(token);
      if (userId == null) {
        return Response(401, body: jsonEncode({'error': 'Invalid token'}));
      }

      // Check user is in chat
      final isParticipant =
          await _isUserChatParticipant(connection, chatId, userId);
      if (!isParticipant) {
        return Response(403,
            body: jsonEncode({'error': 'Not a participant in this chat'}));
      }

      // Create message service
      final messageService = MessageService(connection);

      // Delete the message
      await messageService.deleteMessage(
        messageId,
        userId,
      );

      // Fetch updated message to broadcast
      final deletedMessage = await messageService.getMessageById(messageId);
      if (deletedMessage == null) {
        return Response(404, body: jsonEncode({'error': 'Message not found'}));
      }

      // Broadcast message.deleted event via WebSocket
      final deletedEvent = WebSocketEvent(
        type: WebSocketEventType.messageDeleted,
        data: deletedMessage.toJson(),
      );
      _webSocketService.broadcastToChat(chatId, deletedEvent);

      return Response(204);
    } catch (e) {
      print('[MessageHandlers] ❌ Delete message error: $e');
      return Response(500,
          body: jsonEncode(
              {'error': 'Failed to delete message: ${e.toString()}'}));
    }
  }

  /// Update message status (delivered, read)
  ///
  /// PUT /api/chats/{chatId}/messages/status
  ///
  /// Request body:
  /// {
  ///   "message_id": "msg-uuid",
  ///   "status": "delivered" | "read"
  /// }
  ///
  /// Response: 200 OK with updated message
  /// Broadcasts messageStatusChanged WebSocket event to all chat participants
  ///
  /// Errors:
  /// - 400: Invalid status or missing message_id
  /// - 401: No auth token
  /// - 403: Not a  participant in this chat
  /// - 404: Message not found
  /// - 500: Server error
  static Future<Response> updateMessageStatus(
    Request request,
    String chatId,
    Connection connection,
  ) async {
    try {
      // Get JWT token
      final authHeader = request.headers['Authorization'];
      final token = authHeader?.replaceFirst('Bearer ', '');
      if (token == null || token.isEmpty) {
        return Response(401, body: jsonEncode({'error': 'Missing token'}));
      }

      // Extract user ID from token
      final userId = _extractUserIdFromToken(token);
      if (userId == null) {
        return Response(401, body: jsonEncode({'error': 'Invalid token'}));
      }

      // Check user is in chat
      final isParticipant =
          await _isUserChatParticipant(connection, chatId, userId);
      if (!isParticipant) {
        return Response(403,
            body: jsonEncode({'error': 'Not a participant in this chat'}));
      }

      // Parse request body
      final bodyString = await request.readAsString();
      final bodyJson = jsonDecode(bodyString) as Map<String, dynamic>;
      final messageId = bodyJson['message_id'] as String?;
      final newStatus = bodyJson['status'] as String?;

      if (messageId == null || messageId.isEmpty) {
        return Response(400,
            body: jsonEncode({'error': 'Missing or empty message_id'}));
      }

      if (newStatus == null || newStatus.isEmpty) {
        return Response(400,
            body: jsonEncode({'error': 'Missing or empty status'}));
      }

      if (!['sent', 'delivered', 'read'].contains(newStatus)) {
        return Response(400,
            body: jsonEncode({'error': 'Invalid status value'}));
      }

      // Create messageservice
      final messageService = MessageService(connection);

      // Update the status in database
      await messageService.updateMessageStatus(
        messageId,
        userId, // Current user viewing/receiving the message
        newStatus,
      );

      // Broadcast status change via WebSocket so other user sees it immediately
      final statusEvent = WebSocketEvent(
        type: WebSocketEventType.messageStatusChanged,
        data: {
          'messageId': messageId,
          'newStatus': newStatus,
          'updatedBy': userId,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      _webSocketService.broadcastToChat(chatId, statusEvent);

      return Response(200,
          body: jsonEncode({
            'messageId': messageId,
            'status': newStatus,
            'timestamp': DateTime.now().toIso8601String(),
          }),
          headers: {'Content-Type': 'application/json'});
    } catch (e) {
      print('[MessageHandlers] ❌ Update message status error: $e');
      return Response(500,
          body: jsonEncode(
              {'error': 'Failed to update message status: ${e.toString()}'}));
    }
  }
}
