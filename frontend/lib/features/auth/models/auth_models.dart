/// Registration request model
class RegistrationRequest {
  final String email;
  final String username;
  final String password;
  final String? fullName;

  RegistrationRequest({
    required this.email,
    required this.username,
    required this.password,
    this.fullName,
  });

  Map<String, dynamic> toJson() => {
    'email': email,
    'username': username,
    'password': password,
    'full_name': fullName,
  };

  factory RegistrationRequest.fromJson(Map<String, dynamic> json) =>
      RegistrationRequest(
        email: json['email'] as String,
        username: json['username'] as String,
        password: json['password'] as String,
        fullName: json['full_name'] as String?,
      );
}

/// Login request model
class LoginRequest {
  final String email;
  final String password;

  LoginRequest({
    required this.email,
    required this.password,
  });

  Map<String, dynamic> toJson() => {
    'email': email,
    'password': password,
  };

  factory LoginRequest.fromJson(Map<String, dynamic> json) => LoginRequest(
    email: json['email'] as String,
    password: json['password'] as String,
  );
}

/// Authentication response model
class AuthResponse {
  final String userId;
  final String email;
  final String username;
  final String? token;
  final String? devVerificationToken;

  AuthResponse({
    required this.userId,
    required this.email,
    required this.username,
    this.token,
    this.devVerificationToken,
  });

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'email': email,
    'username': username,
    'token': token,
  };

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    // Handle different field name variations and provide defaults
    final userId = json['user_id'] ?? json['userId'] ?? '';
    final email = json['email'] ?? '';
    final username = json['username'] ?? '';
    final token = json['token'];
    final devVerificationToken = json['dev_verification_token'] as String?;

    // Validate required fields
    if (userId.isEmpty || email.isEmpty || username.isEmpty) {
      throw FormatException('Invalid auth response: missing required fields');
    }

    return AuthResponse(
      userId: userId as String,
      email: email as String,
      username: username as String,
      token: token as String?,
      devVerificationToken: devVerificationToken,
    );
  }
}

/// Validation error model
class ValidationError {
  final String field;
  final String message;

  ValidationError({
    required this.field,
    required this.message,
  });

  @override
  String toString() => '$field: $message';
}

/// User model (current logged-in user)
class User {
  final String userId;
  final String email;
  final String username;
  final String? fullName;

  User({
    required this.userId,
    required this.email,
    required this.username,
    this.fullName,
  });

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'email': email,
    'username': username,
    'full_name': fullName,
  };

  factory User.fromJson(Map<String, dynamic> json) => User(
    userId: json['user_id'] as String,
    email: json['email'] as String,
    username: json['username'] as String,
    fullName: json['full_name'] as String?,
  );
}
