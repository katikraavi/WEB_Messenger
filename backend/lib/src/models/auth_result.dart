/// Data transfer object for authentication API responses
class AuthResult {
  /// Unique identifier for the authenticated user
  final String userId;

  /// User's email address
  final String email;

  /// User's chosen username
  final String username;

  /// JWT session token (optional - only for login/register, not for other endpoints)
  final String? token;

  /// Creates an [AuthResult] with user information and optional token
  AuthResult({
    required this.userId,
    required this.email,
    required this.username,
    this.token,
  });

  /// Converts [AuthResult] to JSON map (excludes sensitive token from general responses)
  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'email': email,
      'username': username,
      if (token != null) 'token': token,
    };
  }

  /// Creates [AuthResult] from JSON map
  factory AuthResult.fromJson(Map<String, dynamic> json) {
    return AuthResult(
      userId: json['user_id'] as String,
      email: json['email'] as String,
      username: json['username'] as String,
      token: json['token'] as String?,
    );
  }

  @override
  String toString() => 'AuthResult(userId: $userId, email: $email, username: $username)';
}
