import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/auth_models.dart';

/// Custom exception for authentication errors
class AuthException implements Exception {
  final String message;
  final String? code;

  AuthException(this.message, {this.code});

  @override
  String toString() => message;
}

/// Frontend authentication service
/// 
/// Handles API communication with the backend for registration, login, and session validation
class AuthService {
  static const String _baseUrl = 'http://localhost:8081';

  /// Get the base URL (can be overridden for testing)
  static String get baseUrl => _baseUrl;

  /// Register a new user
  /// 
  /// Throws [AuthException] on error
  static Future<AuthResponse> register(RegistrationRequest request) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(request.toJson()),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw AuthException('Request timeout - check your connection'),
      );

      if (response.statusCode == 201) {
        try {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          return AuthResponse.fromJson(data);
        } catch (parseError) {
          print('[AuthService] Error parsing register response: $parseError');
          print('[AuthService] Response body: ${response.body}');
          throw AuthException('Invalid server response - please try again', code: 'parse_error');
        }
      } else if (response.statusCode == 400) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final details = data['details'] as List<dynamic>?;
        final error = details?.isNotEmpty == true ? details!.first : data['error'];
        throw AuthException(error?.toString() ?? 'Validation failed', code: 'validation_error');
      } else if (response.statusCode == 409) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        throw AuthException(data['error'] as String? ?? 'User already exists', code: 'user_exists');
      } else {
        throw AuthException('Server error - please try again later', code: 'server_error');
      }
    } on AuthException {
      rethrow;
    } catch (e) {
      print('[AuthService] Register network error: $e');
      throw AuthException('Network error - check your connection', code: 'network_error');
    }
  }

  /// Login with email and password
  /// 
  /// Throws [AuthException] on error
  static Future<AuthResponse> login(LoginRequest request) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(request.toJson()),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw AuthException('Request timeout - check your connection'),
      );

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          return AuthResponse.fromJson(data);
        } catch (parseError) {
          print('[AuthService] Error parsing login response: $parseError');
          print('[AuthService] Response body: ${response.body}');
          throw AuthException('Invalid server response - please try again', code: 'parse_error');
        }
      } else if (response.statusCode == 400) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        throw AuthException(data['error'] as String? ?? 'Validation failed', code: 'validation_error');
      } else if (response.statusCode == 401) {
        throw AuthException('Invalid email or password', code: 'invalid_credentials');
      } else if (response.statusCode == 409) {
        throw AuthException('User already exists', code: 'user_exists');
      } else if (response.statusCode == 429) {
        throw AuthException('Too many login attempts. Try again later.', code: 'rate_limit');
      } else {
        throw AuthException('Server error - please try again later', code: 'server_error');
      }
    } on AuthException {
      rethrow;
    } catch (e) {
      print('[AuthService] Login network error: $e');
      throw AuthException('Network error - check your connection', code: 'network_error');
    }
  }

  /// Validate current session (requires token)
  static Future<User> validateSession(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw AuthException('Request timeout'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return User.fromJson(data);
      } else if (response.statusCode == 401) {
        throw AuthException('Session expired or invalid', code: 'unauthorized');
      } else {
        throw AuthException('Failed to validate session', code: 'server_error');
      }
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException('Network error - check your connection');
    }
  }

  /// Logout (requires token)
  static Future<void> logout(String token) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/logout'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw AuthException('Request timeout'),
      );

      if (response.statusCode != 200) {
        throw AuthException('Failed to logout', code: 'logout_failed');
      }
    } catch (e) {
      print('Logout error: $e');
      // Don't throw on logout - just log it
    }
  }

  /// Client-side email validation
  static bool validateEmail(String email) {
    final regex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return regex.hasMatch(email);
  }

  /// Client-side username validation
  /// Username must be 3-20 characters, alphanumeric + underscore
  static bool validateUsername(String username) {
    if (username.length < 3 || username.length > 20) return false;
    final regex = RegExp(r'^[a-zA-Z0-9_]+$');
    return regex.hasMatch(username);
  }

  /// Validate password strength
  /// Requirements: 8+ chars, lowercase, uppercase, digit, special char
  static List<String> validatePassword(String password) {
    final errors = <String>[];
    
    if (password.length < 8) {
      errors.add('Password must be at least 8 characters');
    }
    if (!password.contains(RegExp(r'[a-z]'))) {
      errors.add('Password must contain a lowercase letter');
    }
    if (!password.contains(RegExp(r'[A-Z]'))) {
      errors.add('Password must contain an uppercase letter');
    }
    if (!password.contains(RegExp(r'[0-9]'))) {
      errors.add('Password must contain a digit');
    }
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      errors.add('Password must contain a special character');
    }
    
    return errors;
  }
}
