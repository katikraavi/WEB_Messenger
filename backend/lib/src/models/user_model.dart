/// User model representing a system user with authentication and profile
class User {
  final String id; // UUID
  final String email;
  final String username;
  final String passwordHash;
  final bool emailVerified;
  final String? profilePictureUrl;
  final String? aboutMe;
  final DateTime createdAt;

  User({
    required this.id,
    required this.email,
    required this.username,
    required this.passwordHash,
    required this.emailVerified,
    this.profilePictureUrl,
    this.aboutMe,
    required this.createdAt,
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
      'created_at': createdAt.toIso8601String(),
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
      createdAt: DateTime.parse(json['created_at'] as String),
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
  }) {
    return User(
      id: id,
      email: email ?? this.email,
      username: username ?? this.username,
      passwordHash: passwordHash ?? this.passwordHash,
      emailVerified: emailVerified ?? this.emailVerified,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      aboutMe: aboutMe ?? this.aboutMe,
      createdAt: createdAt,
    );
  }

  @override
  String toString() => 'User(id=$id, email=$email, username=$username)';
}
