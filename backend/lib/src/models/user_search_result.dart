import 'dart:convert';

/// Result from user search query
class UserSearchResult {
  final String userId;
  final String username;
  final String email;
  final String? profilePictureUrl;
  final bool isPrivateProfile;

  UserSearchResult({
    required this.userId,
    required this.username,
    required this.email,
    this.profilePictureUrl,
    required this.isPrivateProfile,
  });

  /// Serialize to JSON for API response
  Map<String, dynamic> toJson() => {
        'userId': userId,
        'username': username,
        'email': email,
        'profilePictureUrl': profilePictureUrl,
        'isPrivateProfile': isPrivateProfile,
      };

  /// Deserialize from database row
  factory UserSearchResult.fromRow(Map<String, dynamic> row) {
    return UserSearchResult(
      userId: row['id'] as String,
      username: row['username'] as String,
      email: row['email'] as String,
      profilePictureUrl: row['profile_picture_url'] as String?,
      isPrivateProfile: row['is_private_profile'] as bool? ?? false,
    );
  }

  @override
  String toString() =>
      'UserSearchResult(userId: $userId, username: $username, email: $email)';
}
