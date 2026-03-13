class UserProfile {
  final String userId;
  final String username;
  final String email;
  final String? profilePictureUrl;
  final String aboutMe;
  final bool isDefaultProfilePicture;
  final bool isPrivateProfile;
  final DateTime? profileUpdatedAt;
  final DateTime createdAt;

  UserProfile({
    required this.userId,
    required this.username,
    required this.email,
    this.profilePictureUrl,
    this.aboutMe = '',
    this.isDefaultProfilePicture = true,
    this.isPrivateProfile = false,
    this.profileUpdatedAt,
    required this.createdAt,
  });

  /// Convert to JSON for API responses
  Map<String, dynamic> toJson() => {
    'userId': userId,
    'username': username,
    'email': email,
    'profilePictureUrl': profilePictureUrl,
    'aboutMe': aboutMe,
    'isDefaultProfilePicture': isDefaultProfilePicture,
    'isPrivateProfile': isPrivateProfile,
    'profileUpdatedAt': profileUpdatedAt?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
  };

  /// Create from JSON
  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    userId: json['userId'] as String? ?? json['user_id'] as String,
    username: json['username'] as String,
    email: json['email'] as String,
    profilePictureUrl: json['profilePictureUrl'] as String? ?? json['profile_picture_url'] as String?,
    aboutMe: json['aboutMe'] as String? ?? json['about_me'] as String? ?? '',
    isDefaultProfilePicture: json['isDefaultProfilePicture'] as bool? ?? json['is_default_profile_picture'] as bool? ?? true,
    isPrivateProfile: json['isPrivateProfile'] as bool? ?? json['is_private_profile'] as bool? ?? false,
    profileUpdatedAt: json['profileUpdatedAt'] != null 
      ? DateTime.parse(json['profileUpdatedAt'] as String)
      : (json['profile_updated_at'] != null 
        ? DateTime.parse(json['profile_updated_at'] as String)
        : null),
    createdAt: DateTime.parse(json['createdAt'] as String? ?? json['created_at'] as String),
  );

  /// Create a copy with modified fields
  UserProfile copyWith({
    String? userId,
    String? username,
    String? email,
    String? profilePictureUrl,
    String? aboutMe,
    bool? isDefaultProfilePicture,
    bool? isPrivateProfile,
    DateTime? profileUpdatedAt,
    DateTime? createdAt,
  }) => UserProfile(
    userId: userId ?? this.userId,
    username: username ?? this.username,
    email: email ?? this.email,
    profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
    aboutMe: aboutMe ?? this.aboutMe,
    isDefaultProfilePicture: isDefaultProfilePicture ?? this.isDefaultProfilePicture,
    isPrivateProfile: isPrivateProfile ?? this.isPrivateProfile,
    profileUpdatedAt: profileUpdatedAt ?? this.profileUpdatedAt,
    createdAt: createdAt ?? this.createdAt,
  );

  @override
  String toString() => 'UserProfile(userId: $userId, username: $username, private: $isPrivateProfile)';
}
