import 'package:json_annotation/json_annotation.dart';

part 'message_model.g.dart';

/// Represents a single message within a chat
/// 
/// Message content is always stored encrypted (end-to-end encryption).
/// The encrypted_content is Base64-encoded ChaCha20-Poly1305 encrypted plaintext.
@JsonSerializable()
class Message {
  final String id;
  
  /// UUID of the chat this message belongs to
  @JsonKey(name: 'chat_id')
  final String chatId;
  
  /// UUID of the user who sent this message
  @JsonKey(name: 'sender_id')
  final String senderId;
  
  /// UUID of the intended recipient (for 1-to-1 messaging)
  @JsonKey(name: 'recipient_id')
  final String? recipientId;
  
  /// Sender's username (for display in UI)
  @JsonKey(name: 'sender_username')
  String? senderUsername;
  
  /// Sender's profile picture URL (for display in UI)
  @JsonKey(name: 'sender_avatar_url')
  String? senderAvatarUrl;
  
  /// Base64-encoded ChaCha20-Poly1305 encrypted message content
  /// Never store plaintext in database
  @JsonKey(name: 'encrypted_content')
  final String encryptedContent;
  
  /// Current delivery status: pending, sent, delivered, read
  @JsonKey(name: 'status')
  final String status;
  
  /// Message creation timestamp
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  
  /// When message was last edited (null if never edited)
  @JsonKey(name: 'edited_at')
  final DateTime? editedAt;
  
  /// When message was deleted (null if not deleted)
  @JsonKey(name: 'deleted_at')
  final DateTime? deletedAt;
  
  /// Whether this message is soft-deleted
  @JsonKey(name: 'is_deleted')
  final bool isDeleted;

  /// Decrypted plaintext (in-memory only, never persisted)
  /// This is populated after decryption by the service layer
  @JsonKey(ignore: true)
  String? decryptedContent;

  Message({
    required this.id,
    required this.chatId,
    required this.senderId,
    this.recipientId,
    required this.encryptedContent,
    this.status = 'sent',
    required this.createdAt,
    this.editedAt,
    this.deletedAt,
    this.isDeleted = false,
    this.decryptedContent,
  });

  /// JSON serialization factory
  factory Message.fromJson(Map<String, dynamic> json) => _$MessageFromJson(json);

  /// Create Message from Postgres query result row
  factory Message.fromPostgres(List row) {
    return Message(
      id: row[0] as String,
      chatId: row[1] as String,
      senderId: row[2] as String,
      encryptedContent: row[3] as String,
      status: row[6] as String? ?? 'sent',
      createdAt: row[7] as DateTime,
      editedAt: row[8] != null ? row[8] as DateTime : null,
      isDeleted: row.length > 10 && row[10] != null ? row[10] as bool : false,
      deletedAt: row.length > 9 && row[9] != null ? row[9] as DateTime : null,
    );
  }
  
  /// Convert to JSON (encrypted_content only, decryptedContent is never serialized)
  Map<String, dynamic> toJson() => _$MessageToJson(this);

  /// Check if this message was sent by the specified user
  bool sentByUser(String userId) => senderId == userId;
  
  /// Check if this message is deleted
  bool get deleted => isDeleted;
  
  /// Check if this message has been edited
  bool get edited => editedAt != null;

  /// Get display timestamp formatted for UI
  /// Shows time (HH:MM) for today's messages, shows date (M/D) for older messages
  String getDisplayTime() {
    final now = DateTime.now();
    if (createdAt.day == now.day && 
        createdAt.month == now.month && 
        createdAt.year == now.year) {
      return '${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}';
    }
    return '${createdAt.month}/${createdAt.day}';
  }

  @override
  String toString() => 'Message(id: $id, chatId: $chatId, sender: $senderId, '
      'recipient: $recipientId, status: $status, encrypted: ${encryptedContent.length} chars, '
      'created: ${createdAt.toIso8601String()}, deleted: $isDeleted)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Message &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          chatId == other.chatId &&
          senderId == other.senderId &&
          recipientId == other.recipientId &&
          encryptedContent == other.encryptedContent &&
          status == other.status &&
          createdAt == other.createdAt &&
          editedAt == other.editedAt &&
          deletedAt == other.deletedAt &&
          isDeleted == other.isDeleted;

  @override
  int get hashCode =>
      id.hashCode ^
      chatId.hashCode ^
      senderId.hashCode ^
      recipientId.hashCode ^
      encryptedContent.hashCode ^
      status.hashCode ^
      createdAt.hashCode ^
      editedAt.hashCode ^
      deletedAt.hashCode ^
      isDeleted.hashCode;
}
