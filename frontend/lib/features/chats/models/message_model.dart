/// Represents a single message within a chat (Frontend model)
/// 
/// This is the frontend model corresponding to the backend Message entity.
/// The encrypted_content is stored encrypted, while decryptedContent is used
/// after decryption by the message_encryption_service.
/// 
/// Also includes optimistic update fields for local state management:
/// - isSending: Whether message is being sent (for loading state)
/// - error: Error message if send failed (for error handling)
/// - decryptionError: Error if decryption failed
/// - mediaUrl: URL to media file if message has image/video (T077)
/// - mediaType: MIME type of media (T077)
class Message {
  final String id;
  final String chatId;
  final String senderId;
  final String? recipientId;
  final String? senderUsername;
  final String? senderAvatarUrl;
  final String encryptedContent;
  final String status; // sent, delivered, read
  final DateTime createdAt;
  final DateTime? editedAt;
  final DateTime? deletedAt;
  final bool isDeleted;
  final String? decryptedContent;
  final String? mediaUrl; // URL to media file (T077)
  final String? mediaType; // MIME type of media (T077)
  
  /// Whether message is currently being sent (optimistic update)
  final bool isSending;
  
  /// Error message if send failed
  final String? error;
  
  /// Error message if decryption failed
  final String? decryptionError;

  const Message({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.encryptedContent,
    required this.createdAt,
    this.recipientId,
    this.senderUsername,
    this.senderAvatarUrl,
    this.decryptedContent,
    this.status = 'sent',
    this.editedAt,
    this.deletedAt,
    this.isDeleted = false,
    this.mediaUrl,
    this.mediaType,
    this.isSending = false,
    this.error,
    this.decryptionError,
  });

  /// JSON deserialization factory
  factory Message.fromJson(Map<String, dynamic> json) {
    // Helper to parse timestamps as UTC, handling missing Z suffix
    DateTime parseUtcTimestamp(String timestamp) {
      // Ensure timestamp ends with Z for UTC designation
      if (!timestamp.endsWith('Z')) {
        timestamp += 'Z';
      }
      return DateTime.parse(timestamp);
    }
    
    return Message(
      id: json['id'] as String,
      chatId: (json['chat_id'] ?? json['chatId']) as String,
      senderId: (json['sender_id'] ?? json['senderId']) as String,
      encryptedContent: (json['encrypted_content'] ?? json['encryptedContent']) as String,
      createdAt: json['created_at'] != null 
        ? parseUtcTimestamp(json['created_at'] as String)
        : parseUtcTimestamp(json['createdAt'] as String),
      recipientId: (json['recipient_id'] ?? json['recipientId']) as String?,
      senderUsername: (json['sender_username'] ?? json['senderUsername']) as String?,
      senderAvatarUrl: (json['sender_avatar_url'] ?? json['senderAvatarUrl']) as String?,
      decryptedContent: (json['decrypted_content'] ?? json['decryptedContent']) as String?,
      mediaUrl: (json['media_url'] ?? json['mediaUrl']) as String?,
      mediaType: (json['media_type'] ?? json['mediaType']) as String?,
      status: json['status'] as String? ?? 'sent',
      editedAt: json['edited_at'] != null 
        ? parseUtcTimestamp(json['edited_at'] as String)
        : null,
      deletedAt: json['deleted_at'] != null
        ? parseUtcTimestamp(json['deleted_at'] as String)
        : null,
      isDeleted: json['is_deleted'] as bool? ?? false,
      decryptionError: json['decryptionError'] as String?,
    );
  }

  /// Serialize to JSON
  Map<String, dynamic> toJson() => {
    'id': id,
    'chat_id': chatId,
    'sender_id': senderId,
    'recipient_id': recipientId,
    'encrypted_content': encryptedContent,
    'status': status,
    'created_at': createdAt.toIso8601String(),
    'edited_at': editedAt?.toIso8601String(),
    'deleted_at': deletedAt?.toIso8601String(),
    'is_deleted': isDeleted,
    'sender_username': senderUsername,
    'sender_avatar_url': senderAvatarUrl,
    'decrypted_content': decryptedContent,
    'media_url': mediaUrl,
    'media_type': mediaType,
  };

  /// Create a copy with modified fields (for optimistic updates)
  Message copyWith({
    String? id,
    String? chatId,
    String? senderId,
    String? recipientId,
    String? senderUsername,
    String? senderAvatarUrl,
    String? encryptedContent,
    String? status,
    DateTime? createdAt,
    DateTime? editedAt,
    DateTime? deletedAt,
    bool? isDeleted,
    String? decryptedContent,
    String? mediaUrl,
    String? mediaType,
    bool? isSending,
    String? error,
    String? decryptionError,
  }) {
    return Message(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      recipientId: recipientId ?? this.recipientId,
      senderUsername: senderUsername ?? this.senderUsername,
      senderAvatarUrl: senderAvatarUrl ?? this.senderAvatarUrl,
      encryptedContent: encryptedContent ?? this.encryptedContent,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      editedAt: editedAt ?? this.editedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      decryptedContent: decryptedContent ?? this.decryptedContent,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaType: mediaType ?? this.mediaType,
      isSending: isSending ?? this.isSending,
      error: error ?? this.error,
      decryptionError: decryptionError ?? this.decryptionError,
    );
  }

  /// Check if this message was sent by the specified user
  bool sentByUser(String userId) => senderId == userId;

  /// Get display timestamp formatted for UI
  /// Shows time (HH:MM) for today's messages, date (M/D) for older messages
  String getDisplayTime() {
    final now = DateTime.now();
    if (createdAt.day == now.day && 
        createdAt.month == now.month && 
        createdAt.year == now.year) {
      return '${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}';
    }
    return '${createdAt.month}/${createdAt.day}';
  }

  /// Get display timestamp with date and time
  String getDisplayTimeWithDate() {
    return '${getDisplayTime()} - ${createdAt.year}';
  }

  /// Check if message has been decrypted (decryptedContent is not null)
  bool get isDecrypted => decryptedContent != null;

  /// Get the content to display (decrypted if available, otherwise encrypted placeholder)
  String getDisplayContent() {
    if (decryptionError != null) {
      return '[Decryption failed: $decryptionError]';
    }
    if (isDeleted) {
      return '[Message deleted]';
    }
    return isDecrypted ? decryptedContent! : '[Encrypted message]';
  }

  /// Check if message display is loading (sending or decrypting)
  bool get isLoading => isSending;

  /// Check if message display should show an error state
  bool get hasError => error != null || decryptionError != null;

  @override
  String toString() => 'Message(id: $id, from: $senderId, status: $status, '
      'isSending: $isSending, hasError: $hasError, '
      'edited: ${editedAt != null}, deleted: $isDeleted)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Message &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          status == other.status &&
          isDeleted == other.isDeleted &&
          isSending == other.isSending &&
          error == other.error;

  @override
  int get hashCode =>
      id.hashCode ^
      status.hashCode ^
      isDeleted.hashCode ^
      isSending.hashCode ^
      error.hashCode;
}
