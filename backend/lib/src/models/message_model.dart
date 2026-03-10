/// Message Data Model
/// Represents a message in a chat conversation

class MessageModel {
  final String messageId;
  final String senderUserId;
  final String conversationId;
  final String content;
  final DateTime timestamp;
  
  MessageModel({
    required this.messageId,
    required this.senderUserId,
    required this.conversationId,
    required this.content,
    required this.timestamp,
  });
}
