import '../models/chat_model.dart';
import '../models/chat_member_model.dart';

/// ChatService manages chat creation, membership, and archival operations
class ChatService {
  /// Create a new chat
  static Chat createChat({
    required String id,
  }) {
    return Chat(
      id: id,
      createdAt: DateTime.now(),
      archivedByUserIds: [],
    );
  }

  /// Add a member to a chat
  static ChatMember addMember({
    required String userId,
    required String chatId,
  }) {
    return ChatMember(
      userId: userId,
      chatId: chatId,
      joinedAt: DateTime.now(),
    );
  }

  /// Remove a member from a chat
  static ChatMember removeMember({
    required ChatMember member,
  }) {
    return ChatMember(
      userId: member.userId,
      chatId: member.chatId,
      joinedAt: member.joinedAt,
      leftAt: DateTime.now(),
    );
  }

  /// Archive chat for a user
  static Chat archiveChat({
    required Chat chat,
    required String userId,
  }) {
    return chat.archiveFor(userId);
  }

  /// Unarchive chat for a user
  static Chat unarchiveChat({
    required Chat chat,
    required String userId,
  }) {
    return chat.unarchiveFor(userId);
  }

  /// Check if user is member of chat
  static bool isMember({
    required List<ChatMember> members,
    required String userId,
    required String chatId,
  }) {
    try {
      final member = members.firstWhere(
        (m) => m.userId == userId && m.chatId == chatId && m.isActive,
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get active members of a chat
  static List<ChatMember> getActiveMembers(List<ChatMember> members) {
    return members.where((m) => m.isActive).toList();
  }
}
