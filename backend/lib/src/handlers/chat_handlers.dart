import 'package:shelf/shelf.dart';
import 'dart:convert';
import 'package:postgres/postgres.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';
import '../services/chat_service.dart';

/// HTTP handlers for chat-related endpoints
/// 
/// Implements:
/// - GET /api/chats - Fetch active chats for current user
/// - GET /api/chats/{chatId}/messages - Fetch message history with pagination
class ChatHandlers {
  final PostgreSQLConnection connection;

  ChatHandlers(this.connection);

  /// Middleware to extract and verify JWT token from request
  /// 
  /// Adds userId to request context if token is valid.
  /// Returns 401 Unauthorized if token is missing or invalid.
  Handler authMiddleware(Handler innerHandler) {
    return (Request request) async {
      try {
        final authHeader = request.headers['authorization'];
        if (authHeader == null || !authHeader.startsWith('Bearer ')) {
          return Response.unauthorized(
            jsonEncode({'error': 'Missing or invalid authorization header'}),
          );
        }

        // Extract token (format: "Bearer <token>")
        final token = authHeader.substring(7);

        // TODO: Validate JWT token and extract userId
        // For now, we'll assume token validation is handled elsewhere
        // In production, decode and verify JWT here
        
        // Add userId to request context (this is a simplified approach)
        // In production, extract userId from JWT payload
        final userId = request.context['userId'];
        if (userId == null) {
          return Response.unauthorized(
            jsonEncode({'error': 'Unable to extract user ID from token'}),
          );
        }

        return innerHandler(request);
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'error': 'Authentication error: $e'}),
        );
      }
    };
  }

  /// Handler: GET /api/chats
  /// 
  /// Fetches all active (unarchived) chats for the current user.
  /// Sorted by created_at DESC (most recent first).
  /// 
  /// Query parameters:
  /// - limit: Maximum number of chats (default: 50)
  /// - offset: Skip first N chats for pagination (default: 0)
  /// 
  /// Returns:
  /// - 200 OK: List of chat objects
  /// - 401 Unauthorized: Missing or invalid token
  /// - 500 Internal Server Error: Database error
  Future<Response> getChats(Request request) async {
    try {
      // Extract userId from request context
      // Note: This should be set by the auth middleware
      final userId = request.context['userId'] as String?;
      if (userId == null) {
        print('[ChatHandlers] ❌ User not authenticated');
        return Response.unauthorized(
          jsonEncode({'error': 'User not authenticated'}),
        );
      }

      print('[ChatHandlers] 📡 Fetching chats for user: $userId');

      // Get query parameters
      final limit = int.tryParse(request.url.queryParameters['limit'] ?? '50') ?? 50;
      final offset = int.tryParse(request.url.queryParameters['offset'] ?? '0') ?? 0;

      print('[ChatHandlers] Pagination: limit=$limit, offset=$offset');

      // Use ChatService to fetch active chats
      final chatService = ChatService(connection);
      final chats = await chatService.getActiveChats(userId);

      print('[ChatHandlers] ✅ Fetched ${chats.length} chats from service');

      // Apply pagination
      final paginated = chats.skip(offset).take(limit).toList();

      print('[ChatHandlers] 📦 Paginated to ${paginated.length} chats');

      // Convert to JSON
      final chatJsonList = [for (final chat in paginated) chat.toJson()];
      
      print('[ChatHandlers] 📤 Chat JSON samples:');
      for (int i = 0; i < chatJsonList.take(2).length; i++) {
        print('[ChatHandlers]   Chat $i: ${chatJsonList[i]}');
      }

      final response = {
        'chats': chatJsonList,
        'total': chats.length,
        'limit': limit,
        'offset': offset,
      };

      final jsonResponse = jsonEncode(response);
      print('[ChatHandlers] ✅ Response size: ${jsonResponse.length} bytes');

      return Response.ok(
        jsonResponse,
        headers: {'content-type': 'application/json'},
      );
    } catch (e, st) {
      print('[ChatHandlers] ❌ Error fetching chats: $e');
      print('[ChatHandlers] Stack trace: $st');
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to fetch chats: $e'}),
      );
    }
  }

  /// Handler: GET /api/chats/{chatId}/messages
  /// 
  /// Fetches message history for a specific chat with cursor-based pagination.
  /// 
  /// Path parameters:
  /// - chatId: The chat ID
  /// 
  /// Query parameters:
  /// - limit: Number of messages to fetch (default: 20, max: 100)
  /// - before: ISO8601 timestamp to fetch messages before this time (for cursor pagination)
  /// 
  /// Returns:
  /// - 200 OK: List of message objects (encrypted_content included)
  /// - 400 Bad Request: Invalid parameters
  /// - 401 Unauthorized: Missing or invalid token
  /// - 403 Forbidden: User is not a participant in this chat
  /// - 404 Not Found: Chat not found
  /// - 500 Internal Server Error: Database error
  Future<Response> getMessages(Request request, String chatId) async {
    try {
      // Extract userId from request context
      final userId = request.context['userId'] as String?;
      if (userId == null) {
        return Response.unauthorized(
          jsonEncode({'error': 'User not authenticated'}),
        );
      }

      // Validate parameters
      final limit = int.tryParse(request.url.queryParameters['limit'] ?? '20') ?? 20;
      if (limit < 1 || limit > 100) {
        return Response(400, body: jsonEncode({'error': 'limit must be between 1 and 100'}));
      }

      // Parse optional before cursor (for pagination)
      DateTime? beforeCursor;
      final beforeStr = request.url.queryParameters['before'];
      if (beforeStr != null) {
        try {
          beforeCursor = DateTime.parse(beforeStr);
        } catch (e) {
          return Response(400, body: jsonEncode({'error': 'Invalid before parameter: must be ISO8601'}));
        }
      }

      // Verify user is a participant in this chat
      final chatService = ChatService(connection);
      final chat = await chatService.getChatById(chatId);
      if (chat == null) {
        return Response(404, body: jsonEncode({'error': 'Chat not found'}));
      }

      if (!chat.isParticipant(userId)) {
        return Response(403, body: jsonEncode({'error': 'User is not a participant in this chat'}));
      }

      // Fetch messages
      final messages = await chatService.getMessages(chatId, limit: limit, beforeCursor: beforeCursor);

      // For MVP: Frontend will decrypt the encrypted_content on the client side
      // Just pass through the messages as-is
      final response = {
        'messages': [for (final message in messages) message.toJson()],
        'count': messages.length,
        'limit': limit,
      };

      return Response.ok(
        jsonEncode(response),
        headers: {'content-type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to fetch messages: $e'}),
      );
    }
  }
}
