/// User Profile data model
/// 
/// Represents a user's public profile information including personal details
/// and profile picture. Used for displaying profile information and managing
/// profile edits.

class UserProfile {
  /// Unique user identifier (UUID)
  final String userId;

  /// User's chosen username (3-32 characters, editable)
  /// Duplicates allowed - users identified by userId not username uniqueness
  final String username;

  /// URL to user's profile picture (HTTPS)
  /// Null if using default avatar
  final String? profilePictureUrl;

  /// User's bio/about me text (0-500 characters, optional)
  final String aboutMe;

  /// Whether the profile is private (visible to contacts only in future)
  /// Default: false (public)
  final bool isPrivateProfile;

  /// Whether using default profile picture (no custom upload yet)
  final bool isDefaultProfilePicture;

  /// Profile last modification timestamp
  final DateTime? updatedAt;

  /// Creates a [UserProfile] instance
  const UserProfile({
    required this.userId,
    required this.username,
    this.profilePictureUrl,
    this.aboutMe = '',
    this.isPrivateProfile = false,
    this.isDefaultProfilePicture = true,
    this.updatedAt,
  });

  /// Creates a copy of this [UserProfile] with specified fields replaced
  UserProfile copyWith({
    String? userId,
    String? username,
    String? profilePictureUrl,
    String? aboutMe,
    bool? isPrivateProfile,
    bool? isDefaultProfilePicture,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      userId: userId ?? this.userId,
      username: username ?? this.username,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      aboutMe: aboutMe ?? this.aboutMe,
      isPrivateProfile: isPrivateProfile ?? this.isPrivateProfile,
      isDefaultProfilePicture: isDefaultProfilePicture ?? this.isDefaultProfilePicture,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Serializes [UserProfile] to JSON Map
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'username': username,
      'profilePictureUrl': profilePictureUrl,
      'aboutMe': aboutMe,
      'isPrivateProfile': isPrivateProfile,
      'isDefaultProfilePicture': isDefaultProfilePicture,
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  /// Deserializes [UserProfile] from JSON Map
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId: (json['userId'] ?? json['id']) as String,
      username: json['username'] as String,
      profilePictureUrl: json['profilePictureUrl'] as String?,
      aboutMe: json['aboutMe'] as String? ?? '',
      isPrivateProfile: json['isPrivateProfile'] as bool? ?? false,
      isDefaultProfilePicture: json['isDefaultProfilePicture'] as bool? ?? true,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt'] as String) : null,
    );
  }

  @override
  String toString() => 'UserProfile(userId: $userId, username: $username)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfile &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          username == other.username &&
          profilePictureUrl == other.profilePictureUrl &&
          aboutMe == other.aboutMe &&
          isPrivateProfile == other.isPrivateProfile &&
          isDefaultProfilePicture == other.isDefaultProfilePicture &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode =>
      userId.hashCode ^
      username.hashCode ^
      profilePictureUrl.hashCode ^
      aboutMe.hashCode ^
      isPrivateProfile.hashCode ^
      isDefaultProfilePicture.hashCode ^
      updatedAt.hashCode;
}
