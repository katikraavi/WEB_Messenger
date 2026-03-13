import 'package:http/http.dart' as http;
import 'dart:convert';

/// Service for making HTTP requests to email verification endpoints
class EmailVerificationService {
  final String baseUrl;
  final http.Client httpClient;

  EmailVerificationService({
    this.baseUrl = 'http://localhost:8081',
    http.Client? httpClient,
  }) : httpClient = httpClient ?? http.Client();

  /// Request verification email to be sent
  /// Returns EmailVerificationResponse with success/error info
  Future<EmailVerificationResponse> sendVerificationEmail({
    required String email,
    String? userId,
    String? authToken,
  }) async {
    try {
      final response = await httpClient.post(
        Uri.parse('$baseUrl/auth/verify-email/send'),
        headers: {
          'Content-Type': 'application/json',
          if (authToken != null) 'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({'email': email, 'userId': userId ?? ''}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return EmailVerificationResponse.success(
          message: data['message'] ?? 'Verification email sent',
          responseData: data,
        );
      } else if (response.statusCode == 429) {
        // Rate limited
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return EmailVerificationResponse.rateLimited(
          message: data['error'] ?? 'Too many requests',
          remainingAttempts: data['remainingAttempts'] ?? 0,
          resetTimeSeconds: data['resetTime'] != null 
              ? int.tryParse(data['resetTime'].toString().split('T').first) 
              : null,
        );
      } else {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return EmailVerificationResponse.error(
          message: data['error'] ?? 'Failed to send verification email',
        );
      }
    } catch (e) {
      return EmailVerificationResponse.error(
        message: 'Network error: ${e.toString()}',
      );
    }
  }

  /// Verify email with token
  /// Returns true if verification successful
  Future<EmailVerificationResponse> verifyEmail({
    required String token,
  }) async {
    try {
      final response = await httpClient.post(
        Uri.parse('$baseUrl/auth/verify-email/confirm'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'token': token}),
      );

      if (response.statusCode == 200) {
        return EmailVerificationResponse.success(
          message: 'Email verified successfully',
        );
      } else if (response.statusCode == 400) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final error = data['error'] ?? 'Invalid or expired token';
        
        if (error.contains('expired')) {
          return EmailVerificationResponse.tokenExpired(
            message: error,
          );
        }
        return EmailVerificationResponse.error(message: error);
      } else {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return EmailVerificationResponse.error(
          message: data['error'] ?? 'Verification failed',
        );
      }
    } catch (e) {
      return EmailVerificationResponse.error(
        message: 'Network error: ${e.toString()}',
      );
    }
  }
}

/// Response from email verification endpoints
class EmailVerificationResponse {
  final bool success;
  final String message;
  final EmailVerificationStatus status;
  final int? remainingAttempts;
  final int? resetTimeSeconds;
  final String? devToken; // Development mode token for manual verification
  final String? devLink; // Development mode verification link

  EmailVerificationResponse({
    required this.success,
    required this.message,
    required this.status,
    this.remainingAttempts,
    this.resetTimeSeconds,
    this.devToken,
    this.devLink,
  });

  factory EmailVerificationResponse.success({
    required String message,
    Map<String, dynamic>? responseData,
  }) {
    return EmailVerificationResponse(
      success: true,
      message: message,
      status: EmailVerificationStatus.success,
      devToken: responseData?['token'] as String?,
      devLink: responseData?['verificationLink'] as String?,
    );
  }

  factory EmailVerificationResponse.error({
    required String message,
  }) {
    return EmailVerificationResponse(
      success: false,
      message: message,
      status: EmailVerificationStatus.error,
    );
  }

  factory EmailVerificationResponse.rateLimited({
    required String message,
    required int remainingAttempts,
    int? resetTimeSeconds,
  }) {
    return EmailVerificationResponse(
      success: false,
      message: message,
      status: EmailVerificationStatus.rateLimited,
      remainingAttempts: remainingAttempts,
      resetTimeSeconds: resetTimeSeconds,
    );
  }

  factory EmailVerificationResponse.tokenExpired({
    required String message,
  }) {
    return EmailVerificationResponse(
      success: false,
      message: message,
      status: EmailVerificationStatus.tokenExpired,
    );
  }
}

enum EmailVerificationStatus {
  success,
  error,
  rateLimited,
  tokenExpired,
}
