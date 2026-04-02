import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import '../services/email_service.dart';
import '../services/rate_limit_service.dart';
import '../services/password_reset_service.dart';
import '../services/password_hasher.dart';

/// Handler for initiating password reset
/// 
/// POST /auth/password-reset/request
/// Request: { "email": "user@example.com" }
/// Response: { "success": true, "message": "Reset email sent" }
Future<Response> requestPasswordReset(
  Request request,
  EmailService emailService,
  RateLimitService rateLimitService,
  PasswordResetService passwordResetService,
) async {
  try {
    // Parse request
    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;
    final email = (data['email'] as String?)?.trim().toLowerCase();

    if (email == null || email.isEmpty) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Email is required'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    // Validate email format (basic)
    if (!email.contains('@')) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Invalid email format'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    // Check rate limit on attempts (5 per hour)
    if (await rateLimitService.isRateLimited('password_reset:$email')) {
      final resetTime = await rateLimitService.getResetTime('password_reset:$email');
      final remaining = await rateLimitService.getRemainingAttempts('password_reset:$email');
      
      return Response(
        429,
        body: jsonEncode({
          'error': 'Too many reset attempts. Please try again later.',
          'remainingAttempts': remaining,
          'resetTime': resetTime?.toIso8601String(),
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }

    // Record attempt for rate limiting
    await rateLimitService.recordAttempt('password_reset:$email');

    final userResult = await passwordResetService.connection.query(
      'SELECT id, username FROM "users" WHERE email = @email LIMIT 1',
      substitutionValues: {'email': email},
    );

    if (userResult.isEmpty) {
      return Response(
        404,
        body: jsonEncode({
          'error': 'No account found for this email.',
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }

    final user = userResult.first.toColumnMap();
    final userId = user['id'] as String;
    final userName = (user['username'] as String?) ?? email.split('@').first;

    // Generate token and send email
    final token = await passwordResetService.createResetToken(userId);

    final configuredAppBaseUrl = Platform.environment['APP_BASE_URL']?.trim();
    final appBaseUrl =
      (configuredAppBaseUrl != null && configuredAppBaseUrl.isNotEmpty)
        ? configuredAppBaseUrl
        : '${request.requestedUri.scheme}://${request.requestedUri.authority}';
    final resetLink = '$appBaseUrl/reset?token=$token';
    
    // Build password reset email
    final emailMessage = emailService.buildPasswordResetEmail(
      recipientEmail: email,
      recipientName: userName,
      resetLink: resetLink,
      expiresIn: '24 hours',
    );

    // Send email. This now fails fast when SMTP delivery fails.
    await emailService.sendEmail(emailMessage);

    const successMessage =
        'Password reset email request accepted. If it does not arrive, check spam and verify your SMTP sender configuration.';

    final responseBody = {
      'success': true,
      'message': successMessage,
    };

    return Response.ok(
      jsonEncode(responseBody),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e) {
    print('[ERROR] requestPasswordReset: $e');
    return Response.internalServerError(
      body: jsonEncode({'error': 'Failed to send password reset email', 'details': e.toString()}),
      headers: {'Content-Type': 'application/json'},
    );
  }
}

/// Handler for confirming password reset
/// 
/// POST /api/auth/password-reset/confirm
/// Request: { "token": "token_from_email", "newPassword": "NewPassword123!" }
/// Response: { "success": true, "message": "Password reset successfully" }
Future<Response> confirmPasswordReset(
  Request request,
  PasswordResetService passwordResetService,
) async {
  try {
    // Parse request
    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;
    final token = data['token'] as String?;
    final newPassword = data['newPassword'] as String?;

    if (token == null || token.isEmpty) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Token is required'}),
      );
    }

    if (newPassword == null || newPassword.isEmpty) {
      return Response.badRequest(
        body: jsonEncode({'error': 'New password is required'}),
      );
    }

    // Validate password strength locally
    final errors = <String>[];
    if (newPassword.length < 8) errors.add('At least 8 characters');
    if (newPassword.length > 128) errors.add('Not more than 128 characters');
    if (!newPassword.contains(RegExp(r'[A-Z]'))) errors.add('Uppercase letter');
    if (!newPassword.contains(RegExp(r'[a-z]'))) errors.add('Lowercase letter');
    if (!newPassword.contains(RegExp(r'[0-9]'))) errors.add('Digit');
    if (!newPassword.contains(RegExp(r'[!@#$%^&*()_+\-=\[\]{};:",.<>?/\\|`~]'))) errors.add('Special character');

    if (errors.isNotEmpty) {
      return Response(
        400,
        body: jsonEncode({
          'error': 'Password does not meet requirements',
          'errors': errors.map((e) => 'Missing: $e').toList(),
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }

    // Verify token first and capture user id.
    final resetUserId = await passwordResetService.verifyResetToken(token);
    if (resetUserId == null) {
      return Response(
        400,
        body: jsonEncode({'error': 'Invalid or expired reset token'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    final newPasswordHash = PasswordHasher.hashPassword(newPassword);
    final didReset = await passwordResetService.resetPassword(token, newPasswordHash);
    if (!didReset) {
      return Response(
        400,
        body: jsonEncode({'error': 'Invalid or expired reset token'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
    
    return Response.ok(
      jsonEncode({
        'success': true,
        'message': 'Password reset successfully!',
        'user_id': resetUserId,
      }),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e) {
    print('[ERROR] confirmPasswordReset: $e');
    return Response.internalServerError(
      body: jsonEncode({'error': 'Failed to reset password', 'details': e.toString()}),
      headers: {'Content-Type': 'application/json'},
    );
  }
}
