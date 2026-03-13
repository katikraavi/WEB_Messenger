class User {
  final String userId;
  final String email;
  final String username;
  final bool emailVerified;
  final DateTime createdAt;
  final String? profilePictureUrl;
  final String aboutMe;
  final bool isDefaultProfilePicture;
  final bool isPrivateProfile;
  final DateTime? profileUpdatedAt;

  User({
    required this.userId,
    required this.email,
    required this.username,
    required this.emailVerified,
    required this.createdAt,
    this.profilePictureUrl,
    this.aboutMe = '',
    this.isDefaultProfilePicture = true,
    this.isPrivateProfile = false,
    this.profileUpdatedAt,
  });

  /// Create from JSON
  factory User.fromJson(Map<String, dynamic> json) => User(
    userId: json['userId'] as String? ?? json['user_id'] as String,
    email: json['email'] as String,
    username: json['username'] as String,
    emailVerified: json['emailVerified'] as bool? ?? json['email_verified'] as bool? ?? false,
    createdAt: DateTime.parse(json['createdAt'] as String? ?? json['created_at'] as String),
    profilePictureUrl: json['profilePictureUrl'] as String? ?? json['profile_picture_url'] as String?,
    aboutMe: json['aboutMe'] as String? ?? json['about_me'] as String? ?? '',
    isDefaultProfilePicture: json['isDefaultProfilePicture'] as bool? ?? json['is_default_profile_picture'] as bool? ?? true,
    isPrivateProfile: json['isPrivateProfile'] as bool? ?? json['is_private_profile'] as bool? ?? false,
    profileUpdatedAt: json['profileUpdatedAt'] != null
        ? DateTime.parse(json['profileUpdatedAt'] as String)
        : (json['profile_updated_at'] != null
            ? DateTime.parse(json['profile_updated_at'] as String)
            : null),
  );

  /// Convert to JSON
  Map<String, dynamic> toJson() => {
    'userId': userId,
    'email': email,
    'username': username,
    'emailVerified': emailVerified,
    'createdAt': createdAt.toIso8601String(),
    'profilePictureUrl': profilePictureUrl,
    'aboutMe': aboutMe,
    'isDefaultProfilePicture': isDefaultProfilePicture,
    'isPrivateProfile': isPrivateProfile,
    'profileUpdatedAt': profileUpdatedAt?.toIso8601String(),
  };

  /// Create a copy with modified fields
  User copyWith({
    String? userId,
    String? email,
    String? username,
    bool? emailVerified,
    DateTime? createdAt,
    String? profilePictureUrl,
    String? aboutMe,
    bool? isDefaultProfilePicture,
    bool? isPrivateProfile,
    DateTime? profileUpdatedAt,
  }) =>
      User(
        userId: userId ?? this.userId,
        email: email ?? this.email,
        username: username ?? this.username,
        emailVerified: emailVerified ?? this.emailVerified,
        createdAt: createdAt ?? this.createdAt,
        profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
        aboutMe: aboutMe ?? this.aboutMe,
        isDefaultProfilePicture: isDefaultProfilePicture ?? this.isDefaultProfilePicture,
        isPrivateProfile: isPrivateProfile ?? this.isPrivateProfile,
        profileUpdatedAt: profileUpdatedAt ?? this.profileUpdatedAt,
      );

  @override
  String toString() => 'User(userId: $userId, username: $username, email: $email)';
}
