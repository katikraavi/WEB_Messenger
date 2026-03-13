/// Chat model representing a conversation thread (one-on-one or group)
class Chat {
  final String id; // UUID
  final DateTime createdAt;
  final List<String> archivedByUserIds; // UUID list

  Chat({
    required this.id,
    required this.createdAt,
    required this.archivedByUserIds,
  });

  /// Check if chat is archived for a specific user
  bool isArchivedBy(String userId) => archivedByUserIds.contains(userId);

  /// Archive chat for a user
  Chat archiveFor(String userId) {
    if (isArchivedBy(userId)) return this;
    return Chat(
      id: id,
      createdAt: createdAt,
      archivedByUserIds: [...archivedByUserIds, userId],
    );
  }

  /// Unarchive chat for a user
  Chat unarchiveFor(String userId) {
    if (!isArchivedBy(userId)) return this;
    return Chat(
      id: id,
      createdAt: createdAt,
      archivedByUserIds: archivedByUserIds.where((id) => id != userId).toList(),
    );
  }

  /// Serialize to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'created_at': createdAt.toIso8601String(),
      'archived_by_users': archivedByUserIds,
    };
  }

  /// Deserialize from JSON
  factory Chat.fromJson(Map<String, dynamic> json) {
    return Chat(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      archivedByUserIds: List<String>.from(json['archived_by_users'] as List),
    );
  }

  @override
  String toString() => 'Chat(id=$id, createdAt=$createdAt, archived_count=${archivedByUserIds.length})';
}
