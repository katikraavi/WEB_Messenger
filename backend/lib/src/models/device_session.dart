/// Device-scoped session used for selective logout.
class DeviceSession {
  final String id;
  final String userId;
  final String deviceId;
  final String? deviceName;
  final String tokenHash;
  final DateTime createdAt;
  final DateTime lastSeenAt;

  DeviceSession({
    required this.id,
    required this.userId,
    required this.deviceId,
    required this.deviceName,
    required this.tokenHash,
    required this.createdAt,
    required this.lastSeenAt,
  });

  factory DeviceSession.fromMap(Map<String, dynamic> map) {
    return DeviceSession(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      deviceId: map['device_id'] as String,
      deviceName: map['device_name'] as String?,
      tokenHash: map['token_hash'] as String,
      createdAt: map['created_at'] as DateTime,
      lastSeenAt: map['last_seen_at'] as DateTime,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'user_id': userId,
    'device_id': deviceId,
    'device_name': deviceName,
    'token_hash': tokenHash,
    'created_at': createdAt,
    'last_seen_at': lastSeenAt,
  };
}
