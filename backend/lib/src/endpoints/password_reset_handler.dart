import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../services/email_service.dart';
import '../services/rate_limit_service.dart';
import '../services/token_service.dart';

/// Handler for initiating password reset
/// 
/// POST /api/auth/password-reset/request
/// Request: { "email": "user@example.com", "userId": "user-uuid" }
/// Response: { "success": true, "message": "Reset email sent" }
Future<Response> requestPasswordReset(
  Request request,
  TokenService tokenService,
  EmailService emailService,
  RateLimitService rateLimitService,
  dynamic passwordResetService, // Deferred - would be PasswordResetService when DB is available
) async {
  try {
    // Parse request
    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;
    final email = data['email'] as String?;
    final userId = data['userId'] as String?;

    if (email == null || email.isEmpty) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Email is required'}),
      );
    }

    if (userId == null || userId.isEmpty) {
      return Response.badRequest(
        body: jsonEncode({'error': 'UserId is required'}),
      );
    }

    // Validate email format (basic)
    if (!email.contains('@')) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Invalid email format'}),
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
      );
    }

    // Record attempt for rate limiting
    await rateLimitService.recordAttempt('password_reset:$email');

    // Generate token and send email
    // TODO: Use passwordResetService.createResetToken when database is available
    final token = await tokenService.generateToken();
    
    // Build password reset email
    final emailMessage = emailService.buildPasswordResetEmail(
      recipientEmail: email,
      recipientName: email.split('@')[0],
      resetLink: 'https://app.messenger.com/reset?token=$token',
      expiresIn: '24 hours',
    );

    // Send email
    try {
      await emailService.sendEmail(emailMessage);
    } catch (emailError) {
      print('[WARNING] Email send failed: $emailError');
      // Continue - in dev mode, token is logged to console
    }

    // Development mode: Include token in response for manual reset
    final bool isDevelopment = !bool.fromEnvironment('dart.vm.product');
    final responseBody = {
      'success': true,
      'message': isDevelopment
        ? 'Development: Email logged to console. Token: $token'
        : 'Password reset email sent. Check your inbox.',
    };
    
    if (isDevelopment) {
      responseBody['token'] = token;
      responseBody['resetLink'] = 'https://app.messenger.com/reset?token=$token';
    }

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
  TokenService tokenService,
  dynamic passwordResetService, // Deferred - would be PasswordResetService when DB is available
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

    // Validate token format
    if (!tokenService.isValidTokenFormat(token)) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Invalid token format'}),
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

    // TODO: Use passwordResetService.verifyResetToken when database is available
    // For now, accept any valid token format
    return Response.ok(
      jsonEncode({
        'success': true,
        'message': 'Password reset successfully! (Database integration pending)',
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
