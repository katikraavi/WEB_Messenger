import '../models/enums.dart';
import '../models/message_model.dart';

/// MessageService handles message operations including encryption integration
class MessageService {
  /// Create a new message
  static Message createMessage({
    required String id,
    required String chatId,
    required String senderId,
    required String encryptedContent,
    String? mediaUrl,
    String? mediaType,
  }) {
    return Message(
      id: id,
      chatId: chatId,
      senderId: senderId,
      encryptedContent: encryptedContent,
      mediaUrl: mediaUrl,
      mediaType: mediaType,
      status: MessageStatus.sent,
      createdAt: DateTime.now(),
    );
  }

  /// Mark message as delivered
  static Message markDelivered(Message message) {
    return message.copyWith(status: MessageStatus.delivered);
  }

  /// Mark message as read
  static Message markRead(Message message) {
    return message.copyWith(status: MessageStatus.read);
  }

  /// Edit message content
  static Message editMessage({
    required Message message,
    required String newEncryptedContent,
  }) {
    return message.copyWith(
      encryptedContent: newEncryptedContent,
      editedAt: DateTime.now(),
    );
  }

  /// Check if message can be edited (within 15 minutes)
  static bool canEdit(Message message) {
    const editWindow = Duration(minutes: 15);
    return DateTime.now().difference(message.createdAt) < editWindow;
  }

  /// Check if message can be deleted (within 24 hours)
  static bool canDelete(Message message) {
    const deleteWindow = Duration(hours: 24);
    return DateTime.now().difference(message.createdAt) < deleteWindow;
  }

  /// Filter messages by status
  static List<Message> filterByStatus(
    List<Message> messages,
    MessageStatus status,
  ) {
    return messages.where((m) => m.status == status).toList();
  }

  /// Get messages with media
  static List<Message> getMessagesWithMedia(List<Message> messages) {
    return messages.where((m) => m.mediaUrl != null).toList();
  }

  /// Sort messages by creation date (oldest first)
  static List<Message> sortByDate(List<Message> messages) {
    final sorted = [...messages];
    sorted.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return sorted;
  }
}
