/// Chat Conversation Data Model
/// Represents a chat conversation between users

class ChatModel {
  final String conversationId;
  final List<String> participantUserIds;
  final DateTime createdAt;
  
  ChatModel({
    required this.conversationId,
    required this.participantUserIds,
    required this.createdAt,
  });
}
