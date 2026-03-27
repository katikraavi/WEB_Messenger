/// Represents a 1:1 conversation between two users (Frontend model)
/// 
/// This is the frontend model corresponding to the backend Chat entity.
/// Includes helper methods for UI operations.
class Chat {
  final String id;
  final String participant1Id;
  final String participant2Id;
  final bool isParticipant1Archived;
  final bool isParticipant2Archived;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? lastMessagePreview; // Preview text or media indicator
  final DateTime? lastMessageTimestamp; // For ordering
  final String? lastMessageSenderAvatarUrl; // For avatar preview
  final String? lastMessageStatus; // For unread/bold logic
  final String chatType;
  final String? displayName;
  final int? memberCount;
  final List<String>? participantNames;
  final String? myRole;

  const Chat({
    required this.id,
    required this.participant1Id,
    required this.participant2Id,
    required this.isParticipant1Archived,
    required this.isParticipant2Archived,
    required this.createdAt,
    required this.updatedAt,
    this.lastMessagePreview,
    this.lastMessageTimestamp,
    this.lastMessageSenderAvatarUrl,
    this.lastMessageStatus,
    this.chatType = 'direct',
    this.displayName,
    this.memberCount,
    this.participantNames,
    this.myRole,
  });

  /// JSON deserialization factory
  factory Chat.fromJson(Map<String, dynamic> json) {
    return Chat(
      id: json['id'] as String,
      participant1Id: json['participant_1_id'] as String? ?? json['participant1Id'] as String,
      participant2Id: json['participant_2_id'] as String? ?? json['participant2Id'] as String,
      isParticipant1Archived: json['is_participant_1_archived'] as bool? ?? 
                              json['isParticipant1Archived'] as bool? ?? false,
      isParticipant2Archived: json['is_participant_2_archived'] as bool? ?? 
                              json['isParticipant2Archived'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String? ?? json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String? ?? json['updatedAt'] as String),
      lastMessagePreview: json['last_message_preview'] as String?,
      lastMessageTimestamp: json['last_message_timestamp'] != null
        ? DateTime.parse(json['last_message_timestamp'] as String)
        : null,
      lastMessageSenderAvatarUrl: json['last_message_sender_avatar_url'] as String?,
      lastMessageStatus: json['last_message_status'] as String?,
      chatType: json['chat_type'] as String? ?? 'direct',
      displayName: json['display_name'] as String?,
      memberCount: json['member_count'] as int?,
      participantNames: (json['participant_names'] as List<dynamic>?)
          ?.whereType<String>()
          .map((name) => name.trim())
          .where((name) => name.isNotEmpty)
          .toList(),
      myRole: json['my_role'] as String?,
    );
  }

  /// Serialize to JSON
  Map<String, dynamic> toJson() => {
    'id': id,
    'participant_1_id': participant1Id,
    'participant_2_id': participant2Id,
    'is_participant_1_archived': isParticipant1Archived,
    'is_participant_2_archived': isParticipant2Archived,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'last_message_preview': lastMessagePreview,
    'last_message_timestamp': lastMessageTimestamp?.toIso8601String(),
    'last_message_sender_avatar_url': lastMessageSenderAvatarUrl,
    'last_message_status': lastMessageStatus,
    'chat_type': chatType,
    'display_name': displayName,
    'member_count': memberCount,
    'participant_names': participantNames,
    'my_role': myRole,
  };

  bool get isGroup => chatType == 'group';

  /// Get the other participant's ID for the current user
  String getOtherId(String currentUserId) {
    if (isGroup) {
      return participant2Id;
    }
    if (currentUserId == participant1Id) return participant2Id;
    if (currentUserId == participant2Id) return participant1Id;
    throw ArgumentError('Current user $currentUserId is not in this chat');
  }

  /// Check if the current user has archived this chat
  bool isArchivedForUser(String userId) {
    if (userId == participant1Id) return isParticipant1Archived;
    if (userId == participant2Id) return isParticipant2Archived;
    return false;
  }

  /// Check if current user is a participant in this chat
  bool isParticipant(String userId) {
    return userId == participant1Id || userId == participant2Id;
  }
}
