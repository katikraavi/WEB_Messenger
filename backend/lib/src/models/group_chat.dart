/// Group chat aggregate models for multi-member conversations.
class GroupChat {
  final String id;
  final String name;
  final String? createdBy;
  final DateTime createdAt;
  final bool isPublic;

  GroupChat({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.createdAt,
    required this.isPublic,
  });

  factory GroupChat.fromMap(Map<String, dynamic> map) {
    return GroupChat(
      id: map['id'] as String,
      name: map['name'] as String,
      createdBy: map['created_by'] as String?,
      createdAt: map['created_at'] as DateTime,
      isPublic: (map['is_public'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'created_by': createdBy,
    'created_at': createdAt,
    'is_public': isPublic,
  };
}

class GroupMember {
  final String id;
  final String groupId;
  final String userId;
  final String role;
  final DateTime joinedAt;

  GroupMember({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.role,
    required this.joinedAt,
  });

  factory GroupMember.fromMap(Map<String, dynamic> map) {
    return GroupMember(
      id: map['id'] as String,
      groupId: map['group_id'] as String,
      userId: map['user_id'] as String,
      role: (map['role'] as String?) ?? 'member',
      joinedAt: map['joined_at'] as DateTime,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'group_id': groupId,
    'user_id': userId,
    'role': role,
    'joined_at': joinedAt,
  };
}

class GroupInvite {
  final String id;
  final String groupId;
  final String senderId;
  final String receiverId;
  final String status;
  final DateTime createdAt;

  GroupInvite({
    required this.id,
    required this.groupId,
    required this.senderId,
    required this.receiverId,
    required this.status,
    required this.createdAt,
  });

  factory GroupInvite.fromMap(Map<String, dynamic> map) {
    return GroupInvite(
      id: map['id'] as String,
      groupId: map['group_id'] as String,
      senderId: map['sender_id'] as String,
      receiverId: map['receiver_id'] as String,
      status: (map['status'] as String?) ?? 'pending',
      createdAt: map['created_at'] as DateTime,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'group_id': groupId,
    'sender_id': senderId,
    'receiver_id': receiverId,
    'status': status,
    'created_at': createdAt,
  };
}
