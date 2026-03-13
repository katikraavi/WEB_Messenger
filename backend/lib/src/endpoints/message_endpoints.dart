import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';
import '../models/enums.dart';
import '../models/message_model.dart';
import '../services/message_service.dart';
import '../services/encryption_service.dart';

/// Message endpoints handler for sending and managing messages
class MessageEndpoints {
  static final _uuid = const Uuid();
  static final _messages = <String, Message>{};

  /// Route configuration
  static Router get router {
    final router = Router();
    router.post('/api/messages', _sendMessage);
    router.get('/api/messages/<messageId>', _getMessage);
    router.put('/api/messages/<messageId>/status', _updateStatus);
    router.put('/api/messages/<messageId>', _editMessage);
    router.delete('/api/messages/<messageId>', _deleteMessage);
    router.get('/api/chats/<chatId>/messages', _getChatMessages);
    return router;
  }

  /// Send a new message
  static Future<Response> _sendMessage(Request request) async {
    try {
      final json = await request.readAsString();
      final body = _parseJson(json);

      final chatId = body['chat_id'] as String?;
      final senderId = body['sender_id'] as String?;
      final content = body['content'] as String?;
      final mediaUrl = body['media_url'] as String?;
      final mediaType = body['media_type'] as String?;

      if (chatId == null || senderId == null || content == null) {
        return Response.badRequest(
          body: '{"error": "Missing required fields"}',
        );
      }

      // Encrypt content
      final encryptedContent = await EncryptionService.encryptContent(content);

      final messageId = _uuid.v4();
      final message = MessageService.createMessage(
        id: messageId,
        chatId: chatId,
        senderId: senderId,
        encryptedContent: encryptedContent,
        mediaUrl: mediaUrl,
        mediaType: mediaType,
      );

      _messages[messageId] = message;

      return Response.ok(
        _toJson(message),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: '{"error": "Failed to send message: $e"}',
      );
    }
  }

  /// Get message details
  static Future<Response> _getMessage(Request request, String messageId) async {
    try {
      final message = _messages[messageId];
      if (message == null) {
        return Response.notFound('{"error": "Message not found"}');
      }

      return Response.ok(
        _toJson(message),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError();
    }
  }

  /// Update message status (delivered, read)
  static Future<Response> _updateStatus(Request request, String messageId) async {
    try {
      final message = _messages[messageId];
      if (message == null) {
        return Response.notFound('{"error": "Message not found"}');
      }

      final json = await request.readAsString();
      final body = _parseJson(json);
      final statusStr = body['status'] as String?;

      if (statusStr == null) {
        return Response.badRequest(body: '{"error": "Missing status"}');
      }

      final status = MessageStatusExtension.fromString(statusStr);
      final updated = message.copyWith(status: status);
      _messages[messageId] = updated;

      return Response.ok(
        _toJson(updated),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError();
    }
  }

  /// Edit message content
  static Future<Response> _editMessage(Request request, String messageId) async {
    try {
      final message = _messages[messageId];
      if (message == null) {
        return Response.notFound('{"error": "Message not found"}');
      }

      if (!MessageService.canEdit(message)) {
        return Response(403, body: '{"error": "Message cannot be edited"}');
      }

      final json = await request.readAsString();
      final body = _parseJson(json);
      final content = body['content'] as String?;

      if (content == null) {
        return Response.badRequest(body: '{"error": "Missing content"}');
      }

      final encryptedContent = await EncryptionService.encryptContent(content);
      final updated = MessageService.editMessage(
        message: message,
        newEncryptedContent: encryptedContent,
      );
      _messages[messageId] = updated;

      return Response.ok(
        _toJson(updated),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError();
    }
  }

  /// Delete message
  static Future<Response> _deleteMessage(Request request, String messageId) async {
    try {
      final message = _messages[messageId];
      if (message == null) {
        return Response.notFound('{"error": "Message not found"}');
      }

      if (!MessageService.canDelete(message)) {
        return Response(403, body: '{"error": "Message cannot be deleted"}');
      }

      _messages.remove(messageId);
      return Response.ok('{"status":"deleted"}',
          headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError();
    }
  }

  /// Get all messages in a chat
  static Future<Response> _getChatMessages(Request request, String chatId) async {
    try {
      final messages = _messages.values
          .where((m) => m.chatId == chatId)
          .toList();
      
      final sorted = MessageService.sortByDate(messages);
      final json = _messagesToJson(sorted);

      return Response.ok(
        json,
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError();
    }
  }

  static Map<String, dynamic> _parseJson(String json) {
    try {
      return Map<String, dynamic>.from(Uri.splitQueryString(json));
    } catch (_) {
      return {};
    }
  }

  static String _toJson(Message message) {
    return '{"id":"${message.id}","chat_id":"${message.chatId}","sender_id":"${message.senderId}","status":"${message.status.toDbString()}","created_at":"${message.createdAt.toIso8601String()}","edited":${message.isEdited}}';
  }

  static String _messagesToJson(List<Message> messages) {
    final items = messages.map(_toJson).join(',');
    return '[$items]';
  }
}
