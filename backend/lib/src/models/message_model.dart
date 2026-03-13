import 'enums.dart';

/// Message model representing a single message in a chat
class Message {
  final String id; // UUID
  final String chatId;
  final String senderId;
  final String encryptedContent;
  final String? mediaUrl;
  final String? mediaType;
  final MessageStatus status;
  final DateTime createdAt;
  final DateTime? editedAt;

  Message({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.encryptedContent,
    this.mediaUrl,
    this.mediaType,
    required this.status,
    required this.createdAt,
    this.editedAt,
  });

  /// Check if message has been edited
  bool get isEdited => editedAt != null;

  /// Get time since creation
  Duration get ageSinceCreation => DateTime.now().difference(createdAt);

  /// Serialize to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chat_id': chatId,
      'sender_id': senderId,
      'encrypted_content': encryptedContent,
      'media_url': mediaUrl,
      'media_type': mediaType,
      'status': status.toDbString(),
      'created_at': createdAt.toIso8601String(),
      'edited_at': editedAt?.toIso8601String(),
    };
  }

  /// Deserialize from JSON
  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      chatId: json['chat_id'] as String,
      senderId: json['sender_id'] as String,
      encryptedContent: json['encrypted_content'] as String,
      mediaUrl: json['media_url'] as String?,
      mediaType: json['media_type'] as String?,
      status: MessageStatusExtension.fromString(json['status'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      editedAt: json['edited_at'] != null ? DateTime.parse(json['edited_at'] as String) : null,
    );
  }

  /// Create copy with modifications
  Message copyWith({
    String? encryptedContent,
    MessageStatus? status,
    DateTime? editedAt,
  }) {
    return Message(
      id: id,
      chatId: chatId,
      senderId: senderId,
      encryptedContent: encryptedContent ?? this.encryptedContent,
      mediaUrl: mediaUrl,
      mediaType: mediaType,
      status: status ?? this.status,
      createdAt: createdAt,
      editedAt: editedAt ?? (encryptedContent != null ? DateTime.now() : this.editedAt),
    );
  }

  @override
  String toString() => 'Message(id=$id, sender=$senderId, status=${status.toDbString()}, edited=$isEdited)';
}
