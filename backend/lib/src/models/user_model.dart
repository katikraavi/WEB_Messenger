/// User model representing a system user with authentication and profile
class User {
  final String id; // UUID
  final String email;
  final String username;
  final String passwordHash;
  final bool emailVerified;
  final String? profilePictureUrl;
  final String? aboutMe;
  final bool isPrivateProfile;
  final DateTime createdAt;
  final DateTime? profileUpdatedAt;

  User({
    required this.id,
    required this.email,
    required this.username,
    required this.passwordHash,
    required this.emailVerified,
    this.profilePictureUrl,
    this.aboutMe,
    this.isPrivateProfile = false,
    required this.createdAt,
    this.profileUpdatedAt,
  });

  /// Serialize to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'password_hash': passwordHash,
      'email_verified': emailVerified,
      'profile_picture_url': profilePictureUrl,
      'about_me': aboutMe,
      'is_private_profile': isPrivateProfile,
      'created_at': createdAt.toIso8601String(),
      'profile_updated_at': profileUpdatedAt?.toIso8601String(),
    };
  }

  /// Deserialize from JSON
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      username: json['username'] as String,
      passwordHash: json['password_hash'] as String,
      emailVerified: json['email_verified'] as bool,
      profilePictureUrl: json['profile_picture_url'] as String?,
      aboutMe: json['about_me'] as String?,
      isPrivateProfile: json['is_private_profile'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      profileUpdatedAt: json['profile_updated_at'] != null 
          ? DateTime.parse(json['profile_updated_at'] as String)
          : null,
    );
  }

  /// Deserialize from database row (column map)
  factory User.fromDatabase(Map<String, dynamic> row) {
    return User(
      id: row['id'] as String,
      email: row['email'] as String,
      username: row['username'] as String,
      passwordHash: row['password_hash'] as String,
      emailVerified: row['email_verified'] as bool? ?? false,
      profilePictureUrl: row['profile_picture_url'] as String?,
      aboutMe: row['about_me'] as String?,
      isPrivateProfile: row['is_private_profile'] as bool? ?? false,
      createdAt: row['created_at'] is DateTime 
          ? row['created_at'] as DateTime
          : DateTime.parse(row['created_at'] as String),
      profileUpdatedAt: row['profile_updated_at'] != null
          ? row['profile_updated_at'] is DateTime
              ? row['profile_updated_at'] as DateTime
              : DateTime.parse(row['profile_updated_at'] as String)
          : null,
    );
  }

  /// Create copy with modifications
  User copyWith({
    String? email,
    String? username,
    String? passwordHash,
    bool? emailVerified,
    String? profilePictureUrl,
    String? aboutMe,
    bool? isPrivateProfile,
    DateTime? profileUpdatedAt,
  }) {
    return User(
      id: id,
      email: email ?? this.email,
      username: username ?? this.username,
      passwordHash: passwordHash ?? this.passwordHash,
      emailVerified: emailVerified ?? this.emailVerified,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      aboutMe: aboutMe ?? this.aboutMe,
      isPrivateProfile: isPrivateProfile ?? this.isPrivateProfile,
      createdAt: createdAt,
      profileUpdatedAt: profileUpdatedAt ?? this.profileUpdatedAt,
    );
  }

  @override
  String toString() => 'User(id=$id, email=$email, username=$username)';
}
