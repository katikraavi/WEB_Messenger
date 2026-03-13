/// Custom exception for authentication-related errors
class AuthException implements Exception {
  /// Human-readable error message
  final String message;

  /// Machine-readable error classification
  /// Possible values: 'invalid_credentials', 'user_exists', 'weak_password', 'server_error', 'invalid_email_format', 'token_expired', 'token_invalid'
  final String code;

  /// Creates an [AuthException] with a message and optional error code
  AuthException(this.message, {this.code = 'server_error'});

  @override
  String toString() => 'AuthException($code): $message';
}
