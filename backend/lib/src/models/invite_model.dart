import 'enums.dart';

/// Invite model representing a friend/connection invitation
class Invite {
  final String id; // UUID
  final String senderId;
  final String receiverId;
  final InviteStatus status;
  final DateTime createdAt;
  final DateTime? respondedAt;

  Invite({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.status,
    required this.createdAt,
    this.respondedAt,
  });

  /// Check if invitation is pending
  bool get isPending => status == InviteStatus.pending;

  /// Check if invitation is accepted
  bool get isAccepted => status == InviteStatus.accepted;

  /// Check if invitation is declined
  bool get isDeclined => status == InviteStatus.declined;

  /// Get response time (if responded)
  Duration? get responseTime {
    if (respondedAt == null) return null;
    return respondedAt!.difference(createdAt);
  }

  /// Serialize to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'status': status.toDbString(),
      'created_at': createdAt.toIso8601String(),
      'responded_at': respondedAt?.toIso8601String(),
    };
  }

  /// Deserialize from JSON
  factory Invite.fromJson(Map<String, dynamic> json) {
    return Invite(
      id: json['id'] as String,
      senderId: json['sender_id'] as String,
      receiverId: json['receiver_id'] as String,
      status: InviteStatusExtension.fromString(json['status'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      respondedAt: json['responded_at'] != null ? DateTime.parse(json['responded_at'] as String) : null,
    );
  }

  /// Create copy with modifications
  Invite copyWith({
    InviteStatus? status,
    DateTime? respondedAt,
  }) {
    return Invite(
      id: id,
      senderId: senderId,
      receiverId: receiverId,
      status: status ?? this.status,
      createdAt: createdAt,
      respondedAt: respondedAt ?? (status != null ? DateTime.now() : this.respondedAt),
    );
  }

  @override
  String toString() => 'Invite(id=$id, from=$senderId, to=$receiverId, status=${status.toDbString()})';
}
