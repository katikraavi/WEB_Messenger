import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:frontend/core/services/api_client.dart';

/// Service for making HTTP requests to password recovery endpoints
class PasswordRecoveryService {
  final String baseUrl;
  final http.Client httpClient;

  PasswordRecoveryService({
    String? baseUrl,
    http.Client? httpClient,
  }) : baseUrl = baseUrl ?? ApiClient.getBaseUrl(),
       httpClient = httpClient ?? http.Client();

  /// Request password reset email
  Future<PasswordRecoveryResponse> requestPasswordReset({
    required String email,
  }) async {
    try {
      final response = await httpClient.post(
        Uri.parse('$baseUrl/auth/password-reset/request'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return PasswordRecoveryResponse.success(
          message: data['message'] ?? 'Password reset email sent',
        );
      } else if (response.statusCode == 404) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return PasswordRecoveryResponse.error(
          message: data['error'] ?? 'No account found with that email address.',
        );
      } else if (response.statusCode == 429) {
        // Rate limited
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return PasswordRecoveryResponse.rateLimited(
          message: data['error'] ?? 'Too many requests',
          retryAfterSeconds: data['resetTime'] != null
              ? int.tryParse(data['resetTime'].toString().split('T').first)
              : null,
        );
      } else {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return PasswordRecoveryResponse.error(
          message: data['error'] ?? 'Failed to send reset email',
        );
      }
    } catch (e) {
      return PasswordRecoveryResponse.error(
        message: 'Network error: ${e.toString()}',
      );
    }
  }

  /// Reset password with token
  Future<PasswordRecoveryResponse> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    try {
      final response = await httpClient.post(
        Uri.parse('$baseUrl/auth/password-reset/confirm'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'token': token,
          'newPassword': newPassword,
        }),
      );

      if (response.statusCode == 200) {
        return PasswordRecoveryResponse.success(
          message: 'Password reset successfully',
        );
      } else if (response.statusCode == 400) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final errors = (data['errors'] as List?)?.cast<String>() ?? [];

        if (data['error'] != null && data['error'].contains('expired')) {
          return PasswordRecoveryResponse.tokenExpired(
            message: data['error'],
          );
        }

        return PasswordRecoveryResponse.validationError(
          message: data['error'] ?? 'Validation failed',
          validationErrors: errors,
        );
      } else {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return PasswordRecoveryResponse.error(
          message: data['error'] ?? 'Password reset failed',
        );
      }
    } catch (e) {
      return PasswordRecoveryResponse.error(
        message: 'Network error: ${e.toString()}',
      );
    }
  }
}

/// Response from password recovery endpoints
class PasswordRecoveryResponse {
  final bool success;
  final String message;
  final PasswordRecoveryStatus status;
  final List<String> validationErrors;
  final int? retryAfterSeconds;

  PasswordRecoveryResponse({
    required this.success,
    required this.message,
    required this.status,
    this.validationErrors = const [],
    this.retryAfterSeconds,
  });

  factory PasswordRecoveryResponse.success({
    required String message,
  }) {
    return PasswordRecoveryResponse(
      success: true,
      message: message,
      status: PasswordRecoveryStatus.success,
    );
  }

  factory PasswordRecoveryResponse.error({
    required String message,
  }) {
    return PasswordRecoveryResponse(
      success: false,
      message: message,
      status: PasswordRecoveryStatus.error,
    );
  }

  factory PasswordRecoveryResponse.rateLimited({
    required String message,
    int? retryAfterSeconds,
  }) {
    return PasswordRecoveryResponse(
      success: false,
      message: message,
      status: PasswordRecoveryStatus.rateLimited,
      retryAfterSeconds: retryAfterSeconds,
    );
  }

  factory PasswordRecoveryResponse.tokenExpired({
    required String message,
  }) {
    return PasswordRecoveryResponse(
      success: false,
      message: message,
      status: PasswordRecoveryStatus.tokenExpired,
    );
  }

  factory PasswordRecoveryResponse.validationError({
    required String message,
    required List<String> validationErrors,
  }) {
    return PasswordRecoveryResponse(
      success: false,
      message: message,
      status: PasswordRecoveryStatus.validationError,
      validationErrors: validationErrors,
    );
  }
}

enum PasswordRecoveryStatus {
  success,
  error,
  rateLimited,
  tokenExpired,
  validationError,
}
