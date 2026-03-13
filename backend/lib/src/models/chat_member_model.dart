/// ChatMember model representing a user's membership in a chat
class ChatMember {
  final String userId;
  final String chatId;
  final DateTime joinedAt;
  final DateTime? leftAt;

  ChatMember({
    required this.userId,
    required this.chatId,
    required this.joinedAt,
    this.leftAt,
  });

  /// Check if member is currently active (hasn't left)
  bool get isActive => leftAt == null;

  /// Get member status
  String get status => isActive ? 'active' : 'left';

  /// Serialize to JSON
  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'chat_id': chatId,
      'joined_at': joinedAt.toIso8601String(),
      'left_at': leftAt?.toIso8601String(),
    };
  }

  /// Deserialize from JSON
  factory ChatMember.fromJson(Map<String, dynamic> json) {
    return ChatMember(
      userId: json['user_id'] as String,
      chatId: json['chat_id'] as String,
      joinedAt: DateTime.parse(json['joined_at'] as String),
      leftAt: json['left_at'] != null ? DateTime.parse(json['left_at'] as String) : null,
    );
  }

  @override
  String toString() => 'ChatMember(userId=$userId, chatId=$chatId, active=$isActive)';
}
