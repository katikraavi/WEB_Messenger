import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/chat_model.dart';
import '../models/message_model.dart';

/// API client is handled internally via http package

/// Service for API calls related to chat operations
///
/// Handles HTTP communication with backend:
/// - Fetching active chats list
/// - Fetching message history with pagination
/// - All requests are authenticated with JWT token
class ChatApiService {
  final http.Client _httpClient;
  final String _baseUrl;

  ChatApiService({required String baseUrl, http.Client? httpClient})
    : _baseUrl = baseUrl,
      _httpClient = httpClient ?? http.Client();

  /// Fetch all active chats for the current user
  ///
  /// Parameters:
  /// - token: JWT authentication token
  /// - limit: Maximum number of chats to fetch (default: 50)
  /// - offset: Pagination offset (default: 0)
  ///
  /// Returns: List of Chat objects
  ///
  /// Throws:
  /// - FormatException: If response JSON is malformed
  /// - http.ClientException: If network request fails
  /// - Exception: If authorization fails (401) or server error (5xx)
  Future<List<Chat>> fetchChats({
    required String token,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/api/chats?limit=$limit&offset=$offset');

      print('[ChatApiService] 📡 Fetching chats from: $url');
      print(
        '[ChatApiService] Token: ${token.isNotEmpty ? 'present' : 'EMPTY'}',
      );

      final response = await _httpClient.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('[ChatApiService] Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('[ChatApiService] 📦 Raw response body: ${response.body}');

        final json = jsonDecode(response.body) as Map<String, dynamic>;
        print('[ChatApiService] 🔍 Decoded JSON keys: ${json.keys.toList()}');
        print('[ChatApiService] Total chats in response: ${json['total']}');

        final chatsList = (json['chats'] as List<dynamic>).map((chat) {
          print('[ChatApiService] 🔍 Processing chat object: $chat');
          try {
            // Ensure backend includes last_message_preview, last_message_timestamp, last_message_sender_avatar_url
            return Chat.fromJson(chat as Map<String, dynamic>);
          } catch (e) {
            print('[ChatApiService] ❌ Failed to parse chat: $e');
            print('[ChatApiService] Chat data: $chat');
            rethrow;
          }
        }).toList();
        print('[ChatApiService] ✅ Parsed ${chatsList.length} chats');
        return chatsList;
      } else if (response.statusCode == 401) {
        print('[ChatApiService] ❌ Unauthorized: Invalid or expired token');
        throw Exception('Unauthorized: Invalid or expired token');
      } else if (response.statusCode >= 500) {
        print('[ChatApiService] ❌ Server error: ${response.statusCode}');
        throw Exception('Server error: ${response.statusCode}');
      } else {
        print(
          '[ChatApiService] ❌ Failed to fetch chats: ${response.statusCode}',
        );
        print('[ChatApiService] Response body: ${response.body}');
        throw Exception('Failed to fetch chats: ${response.statusCode}');
      }
    } catch (e) {
      print('[ChatApiService] ❌ Exception in fetchChats: $e');
      rethrow;
    }
  }

  /// Fetch message history for a specific chat with pagination
  ///
  /// Parameters:
  /// - token: JWT authentication token
  /// - chatId: The chat ID to fetch messages from
  /// - limit: Maximum number of messages to fetch (default: 20, max: 100)
  /// - beforeCursor: Optional ISO8601 timestamp to fetch messages before (for cursor pagination)
  ///
  /// Returns: List of Message objects (encrypted_content included)
  ///
  /// Throws:
  /// - FormatException: If response JSON is malformed
  /// - http.ClientException: If network request fails
  /// - Exception: If authorization fails (401), user not participant (403), chat not found (404), or server error
  Future<List<Message>> fetchMessages({
    required String token,
    required String chatId,
    int limit = 20,
    DateTime? beforeCursor,
  }) async {
    try {
      final queryParams = {'limit': limit.toString()};

      if (beforeCursor != null) {
        queryParams['before'] = beforeCursor.toIso8601String();
      }

      final uri = Uri.parse(
        '$_baseUrl/api/chats/$chatId/messages',
      ).replace(queryParameters: queryParams);

      final response = await _httpClient.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final messagesList = (json['messages'] as List<dynamic>)
            .map((message) => Message.fromJson(message as Map<String, dynamic>))
            .toList();
        return messagesList;
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Invalid or expired token');
      } else if (response.statusCode == 403) {
        throw Exception('Forbidden: You are not a participant in this chat');
      } else if (response.statusCode == 404) {
        throw Exception('Not found: Chat does not exist');
      } else if (response.statusCode >= 500) {
        throw Exception('Server error: ${response.statusCode}');
      } else {
        throw Exception('Failed to fetch messages: ${response.statusCode}');
      }
    } catch (e) {
      print('[ChatApiService] Error fetching messages for chat $chatId: $e');
      rethrow;
    }
  }

  /// Fetch a single message by ID (for debugging/verification)
  ///
  /// Parameters:
  /// - token: JWT authentication token
  /// - messageId: The message ID to fetch
  ///
  /// Returns: Message object or null if not found
  Future<Message?> fetchMessage({
    required String token,
    required String messageId,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/api/messages/$messageId');

      final response = await _httpClient.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return Message.fromJson(json);
      } else if (response.statusCode == 404) {
        return null;
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized');
      } else {
        throw Exception('Failed to fetch message: ${response.statusCode}');
      }
    } catch (e) {
      print('[ChatApiService] Error fetching message $messageId: $e');
      rethrow;
    }
  }

  /// Verify chat exists and current user is a participant
  ///
  /// Parameters:
  /// - token: JWT authentication token
  /// - chatId: The chat ID to verify
  ///
  /// Returns: true if user is a participant, false otherwise
  ///
  /// Throws: Exception on network or server error
  Future<bool> verifyChatParticipant({
    required String token,
    required String chatId,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/api/chats/$chatId');

      final response = await _httpClient.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return true;
      } else if (response.statusCode == 403 || response.statusCode == 404) {
        return false;
      } else {
        throw Exception(
          'Failed to verify chat participation: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('[ChatApiService] Error verifying chat participation: $e');
      rethrow;
    }
  }

  /// Send a message to a chat
  ///
  /// Parameters:
  /// - token: JWT authentication token
  /// - chatId: The chat to send message to
  /// - encryptedContent: Base64-encoded encrypted message content
  /// - idempotencyKey: Optional key for idempotency (prevents duplicates)
  ///
  /// Returns: Message object with created ID and timestamp
  ///
  /// Throws:
  /// - Exception: If authorization fails (401), user not participant (403), validation fails (400), or server error
  Future<Message> sendMessage({
    required String token,
    required String chatId,
    required String encryptedContent,
    String? mediaUrl,
    String? mediaType,
    String? idempotencyKey,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/api/chats/$chatId/messages');

      final body = {'encrypted_content': encryptedContent};

      if (mediaUrl != null && mediaType != null) {
        body['media_url'] = mediaUrl;
        body['media_type'] = mediaType;
      }

      if (idempotencyKey != null) {
        body['idempotency_key'] = idempotencyKey;
      }

      final response = await _httpClient.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 201) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return Message.fromJson(json);
      } else if (response.statusCode == 400) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        throw Exception('Validation error: ${json['error']}');
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Invalid or expired token');
      } else if (response.statusCode == 403) {
        throw Exception('Forbidden: You are not a participant in this chat');
      } else if (response.statusCode == 404) {
        throw Exception('Not found: Chat does not exist');
      } else if (response.statusCode == 409) {
        throw Exception(
          'Conflict: Message already sent (duplicate idempotency key)',
        );
      } else if (response.statusCode >= 500) {
        throw Exception('Server error: ${response.statusCode}');
      } else {
        throw Exception('Failed to send message: ${response.statusCode}');
      }
    } catch (e) {
      print('[ChatApiService] Error sending message to chat $chatId: $e');
      rethrow;
    }
  }

  /// Archive a chat for the current user
  ///
  /// Parameters:
  /// - token: JWT authentication token
  /// - chatId: The chat ID to archive
  ///
  /// Returns: Updated Chat object
  ///
  /// Throws:
  /// - Exception: If authorization fails (401), chat not found (404), or server error
  Future<Chat> archiveChat({
    required String token,
    required String chatId,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/api/chats/$chatId/archive');

      print('[ChatApiService] 📌 Archiving chat: $chatId');

      final response = await _httpClient.put(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        print('[ChatApiService] ✅ Chat archived: $chatId');
        return Chat.fromJson(json);
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Invalid or expired token');
      } else if (response.statusCode == 404) {
        throw Exception('Chat not found');
      } else if (response.statusCode >= 500) {
        throw Exception('Server error: ${response.statusCode}');
      } else {
        throw Exception('Failed to archive chat: ${response.statusCode}');
      }
    } catch (e) {
      print('[ChatApiService] Error archiving chat $chatId: $e');
      rethrow;
    }
  }

  /// Unarchive a chat for the current user
  ///
  /// Parameters:
  /// - token: JWT authentication token
  /// - chatId: The chat ID to unarchive
  ///
  /// Returns: Updated Chat object
  ///
  /// Throws:
  /// - Exception: If authorization fails (401), chat not found (404), or server error
  Future<Chat> unarchiveChat({
    required String token,
    required String chatId,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/api/chats/$chatId/unarchive');

      print('[ChatApiService] 📌 Unarchiving chat: $chatId');

      final response = await _httpClient.put(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        print('[ChatApiService] ✅ Chat unarchived: $chatId');
        return Chat.fromJson(json);
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Invalid or expired token');
      } else if (response.statusCode == 404) {
        throw Exception('Chat not found');
      } else if (response.statusCode >= 500) {
        throw Exception('Server error: ${response.statusCode}');
      } else {
        throw Exception('Failed to unarchive chat: ${response.statusCode}');
      }
    } catch (e) {
      print('[ChatApiService] Error unarchiving chat $chatId: $e');
      rethrow;
    }
  }

  /// Fetch archived chats for the current user
  ///
  /// Parameters:
  /// - token: JWT authentication token
  ///
  /// Returns: List of archived Chat objects
  ///
  /// Throws:
  /// - Exception: If authorization fails (401) or server error
  Future<List<Chat>> fetchArchivedChats({required String token}) async {
    try {
      final url = Uri.parse('$_baseUrl/api/chats/archived');

      print('[ChatApiService] 📡 Fetching archived chats');

      final response = await _httpClient.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final chatsList = (json['chats'] as List<dynamic>)
            .map((chat) => Chat.fromJson(chat as Map<String, dynamic>))
            .toList();
        print('[ChatApiService] ✅ Fetched ${chatsList.length} archived chats');
        return chatsList;
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Invalid or expired token');
      } else if (response.statusCode >= 500) {
        throw Exception('Server error: ${response.statusCode}');
      } else {
        throw Exception(
          'Failed to fetch archived chats: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('[ChatApiService] Error fetching archived chats: $e');
      rethrow;
    }
  }

  /// Update message delivery status (T034, T035)
  ///
  /// Called when message is:
  /// - Received: status = 'delivered'
  /// - Read: status = 'read'
  ///
  /// Parameters:
  /// - token: JWT authentication token
  /// - chatId: The chat the message belongs to
  /// - messageId: The message ID to update
  /// - newStatus: New status ('delivered' or 'read')
  ///
  /// Throws:
  /// - Exception: If authorization fails, message not found, or server error
  /// Edit an existing message (T055, US4)
  ///
  /// Parameters:
  /// - chatId: The chat containing the message
  /// - messageId: The message to edit
  /// - newEncryptedContent: New Base64-encoded encrypted content
  ///
  /// Returns: Updated Message object
  ///
  /// Throws: Exception if message not found, authentication fails, or server error
  Future<Message> editMessage({
    required String token,
    required String chatId,
    required String messageId,
    required String newEncryptedContent,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/api/chats/$chatId/messages/$messageId');

      final body = {'encrypted_content': newEncryptedContent};

      print('[ChatApiService] 📝 Editing message: $messageId');

      final response = await _httpClient.put(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final messageData = jsonDecode(response.body) as Map<String, dynamic>;
        final editedMessage = Message.fromJson(messageData);
        print('[ChatApiService] ✅ Message edited successfully: $messageId');
        return editedMessage;
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Invalid or expired token');
      } else if (response.statusCode == 403) {
        throw Exception('Forbidden: You can only edit your own messages');
      } else if (response.statusCode == 404) {
        throw Exception('Message not found');
      } else if (response.statusCode >= 500) {
        throw Exception('Server error: ${response.statusCode}');
      } else {
        throw Exception('Failed to edit message: ${response.statusCode}');
      }
    } catch (e) {
      print('[ChatApiService] ❌ Error editing message: $e');
      rethrow;
    }
  }

  /// Delete a message (soft-delete)
  ///
  /// Parameters:
  /// - token: JWT auth token
  /// - chatId: ID of the chat containing the message
  /// - messageId: ID of the message to delete
  ///
  /// Returns: Future<void> (204 No Content response)
  ///
  /// Throws: Exception if message not found, authentication fails, or server error
  Future<void> deleteMessage({
    required String token,
    required String chatId,
    required String messageId,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/api/chats/$chatId/messages/$messageId');

      print('[ChatApiService] 🗑️ Deleting message: $messageId');

      final response = await _httpClient.delete(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 204) {
        print('[ChatApiService] ✅ Message deleted successfully: $messageId');
        return;
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Invalid or expired token');
      } else if (response.statusCode == 403) {
        throw Exception('Forbidden: You can only delete your own messages');
      } else if (response.statusCode == 404) {
        throw Exception('Message not found');
      } else if (response.statusCode >= 500) {
        throw Exception('Server error: ${response.statusCode}');
      } else {
        throw Exception('Failed to delete message: ${response.statusCode}');
      }
    } catch (e) {
      print('[ChatApiService] ❌ Error deleting message: $e');
      rethrow;
    }
  }

  Future<void> updateMessageStatus({
    required String token,
    required String chatId,
    required String messageId,
    required String newStatus,
  }) async {
    try {
      // This endpoint would be: PUT /api/chats/{chatId}/messages/{messageId}/status
      final url = Uri.parse('$_baseUrl/api/chats/$chatId/messages/status');

      final body = {'message_id': messageId, 'status': newStatus};

      print(
        '[ChatApiService] 📤 Updating message status: $messageId → $newStatus',
      );

      final response = await _httpClient.put(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        print(
          '[ChatApiService] ✅ Message status updated: $messageId → $newStatus',
        );
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Invalid or expired token');
      } else if (response.statusCode == 404) {
        throw Exception('Message not found');
      } else if (response.statusCode >= 500) {
        throw Exception('Server error: ${response.statusCode}');
      } else {
        print(
          '[ChatApiService] ⚠️ Status update returned ${response.statusCode}',
        );
        // Non-blocking - status update is best-effort
      }
    } catch (e) {
      print('[ChatApiService] ⚠️ Error updating message status: $e');
      // Non-blocking - status update is best-effort, don't rethrow
    }
  }

  /// Delete a chat (remove connection)
  ///
  /// Parameters:
  /// - token: JWT authentication token
  /// - chatId: ID of the chat to delete
  Future<void> deleteChat({
    required String token,
    required String chatId,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/api/chats/$chatId');

      print('[ChatApiService] 🗑️ Deleting chat: $chatId');

      final response = await _httpClient.delete(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 204 || response.statusCode == 200) {
        print('[ChatApiService] ✅ Chat deleted successfully: $chatId');
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Invalid or expired token');
      } else if (response.statusCode == 403) {
        final errorData = jsonDecode(response.body);
        throw Exception(
          'Forbidden: ${errorData['error'] ?? 'You are not a participant in this chat'}',
        );
      } else if (response.statusCode == 404) {
        throw Exception('Chat not found');
      } else if (response.statusCode >= 500) {
        throw Exception('Server error: ${response.statusCode}');
      } else {
        throw Exception('Failed to delete chat: ${response.statusCode}');
      }
    } catch (e) {
      print('[ChatApiService] ❌ Error deleting chat: $e');
      rethrow;
    }
  }

  /// Close the HTTP client and release resources
  void dispose() {
    _httpClient.close();
  }
}
