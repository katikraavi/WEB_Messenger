import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_model.dart';
import '../models/chat_member_model.dart';
import '../services/chat_service.dart';

/// Chat endpoints handler for chat and membership operations
class ChatEndpoints {
  static final _uuid = const Uuid();
  static final _chats = <String, Chat>{};
  static final _members = <String, List<ChatMember>>{};

  /// Route configuration
  static Router get router {
    final router = Router();
    router.post('/api/chats', _createChat);
    router.get('/api/chats/<chatId>', _getChat);
    router.post('/api/chats/<chatId>/members', _addMember);
    router.get('/api/chats/<chatId>/members', _getMembers);
    router.put('/api/chats/<chatId>/archive', _archiveChat);
    router.put('/api/chats/<chatId>/unarchive', _unarchiveChat);
    return router;
  }

  /// Create a new chat
  static Future<Response> _createChat(Request request) async {
    try {
      final chatId = _uuid.v4();
      final chat = ChatService.createChat(id: chatId);
      _chats[chatId] = chat;
      _members[chatId] = [];

      return Response.ok(
        _toJson(chat),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: '{"error": "Failed to create chat"}',
      );
    }
  }

  /// Get chat details
  static Future<Response> _getChat(Request request, String chatId) async {
    try {
      final chat = _chats[chatId];
      if (chat == null) {
        return Response.notFound('{"error": "Chat not found"}');
      }

      return Response.ok(
        _toJson(chat),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError();
    }
  }

  /// Add member to chat
  static Future<Response> _addMember(Request request, String chatId) async {
    try {
      final chat = _chats[chatId];
      if (chat == null) {
        return Response.notFound('{"error": "Chat not found"}');
      }

      final json = await request.readAsString();
      final body = _parseJson(json);
      final userId = body['user_id'] as String?;

      if (userId == null) {
        return Response.badRequest(
          body: '{"error": "Missing user_id"}',
        );
      }

      final member = ChatService.addMember(userId: userId, chatId: chatId);
      final membersList = _members[chatId] ??= [];
      membersList.add(member);

      return Response.ok(
        _memberToJson(member),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError();
    }
  }

  /// Get chat members
  static Future<Response> _getMembers(Request request, String chatId) async {
    try {
      final membersList = _members[chatId] ?? [];
      final active = ChatService.getActiveMembers(membersList);
      final json = _membersToJson(active);

      return Response.ok(
        json,
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError();
    }
  }

  /// Archive chat for user
  static Future<Response> _archiveChat(Request request, String chatId) async {
    try {
      final chat = _chats[chatId];
      if (chat == null) {
        return Response.notFound('{"error": "Chat not found"}');
      }

      final json = await request.readAsString();
      final body = _parseJson(json);
      final userId = body['user_id'] as String?;

      if (userId == null) {
        return Response.badRequest(body: '{"error": "Missing user_id"}');
      }

      final archived = ChatService.archiveChat(chat: chat, userId: userId);
      _chats[chatId] = archived;

      return Response.ok(
        _toJson(archived),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError();
    }
  }

  /// Unarchive chat for user
  static Future<Response> _unarchiveChat(Request request, String chatId) async {
    try {
      final chat = _chats[chatId];
      if (chat == null) {
        return Response.notFound('{"error": "Chat not found"}');
      }

      final json = await request.readAsString();
      final body = _parseJson(json);
      final userId = body['user_id'] as String?;

      if (userId == null) {
        return Response.badRequest(body: '{"error": "Missing user_id"}');
      }

      final unarchived = ChatService.unarchiveChat(chat: chat, userId: userId);
      _chats[chatId] = unarchived;

      return Response.ok(
        _toJson(unarchived),
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

  static String _toJson(Chat chat) {
    return '{"id":"${chat.id}","created_at":"${chat.createdAt.toIso8601String()}","archived_count":${chat.archivedByUserIds.length}}';
  }

  static String _memberToJson(ChatMember member) {
    return '{"user_id":"${member.userId}","chat_id":"${member.chatId}","joined_at":"${member.joinedAt.toIso8601String()}","active":${member.isActive}}';
  }

  static String _membersToJson(List<ChatMember> members) {
    final items = members.map(_memberToJson).join(',');
    return '[$items]';
  }
}
