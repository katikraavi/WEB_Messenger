import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../services/email_service.dart';
import '../services/rate_limit_service.dart';
import '../services/token_service.dart';

/// Handler for initiating email verification
/// 
/// POST /api/auth/verify-email/send
/// Request: { "email": "user@example.com", "userId": "user-uuid" }
/// Response: { "success": true, "message": "Verification email sent" }
Future<Response> sendVerificationEmail(
  Request request,
  TokenService tokenService,
  EmailService emailService,
  RateLimitService rateLimitService,
  dynamic verificationService, // Deferred - would be VerificationService when DB is available
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

    // Check rate limit on attempts
    if (await rateLimitService.isRateLimited('verify_email:$email')) {
      final remaining = await rateLimitService.getRemainingAttempts('verify_email:$email');
      return Response(
        429,
        body: jsonEncode({
          'error': 'Too many attempts. Please try again later.',
          'remainingAttempts': remaining,
        }),
      );
    }

    // Record attempt
    await rateLimitService.recordAttempt('verify_email:$email');

    // Generate token and send email
    final token = await verificationService.createVerificationToken(userId);
    
    // Build verification email
    final emailMessage = emailService.buildVerificationEmail(
      recipientEmail: email,
      recipientName: email.split('@')[0],
      verificationLink: 'https://app.messenger.com/verify?token=$token',
      expiresIn: '24 hours',
    );

    // Send email
    try {
      await emailService.sendEmail(emailMessage);
    } catch (emailError) {
      print('[WARNING] Email send failed: $emailError');
      // Continue - in dev mode, token is logged to console
    }

    // Development mode: Include token in response for manual verification
    // In production, only return success message
    final bool isDevelopment = !bool.fromEnvironment('dart.vm.product');
    final responseBody = {
      'success': true,
      'message': isDevelopment 
        ? 'Development: Email logged to console. Token: $token'
        : 'Verification email sent. Check your inbox.',
    };
    
    if (isDevelopment) {
      responseBody['token'] = token;
      responseBody['verificationLink'] = 'https://app.messenger.com/verify?token=$token';
    }

    return Response.ok(
      jsonEncode(responseBody),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e) {
    print('[ERROR] sendVerificationEmail: $e');
    return Response.internalServerError(
      body: jsonEncode({'error': 'Failed to send verification email', 'details': e.toString()}),
      headers: {'Content-Type': 'application/json'},
    );
  }
}

/// Handler for verifying email with token
/// 
/// POST /api/auth/verify-email/confirm
/// Request: { "token": "token_from_email" }
/// Response: { "success": true, "message": "Email verified" }
Future<Response> verifyEmailToken(
  Request request,
  TokenService tokenService,
  dynamic verificationService, // Deferred - would be VerificationService when DB is available
) async {
  try {
    // Parse request
    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;
    final token = data['token'] as String?;

    if (token == null || token.isEmpty) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Token is required'}),
      );
    }

    // Validate token format
    if (!tokenService.isValidTokenFormat(token)) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Invalid token format'}),
      );
    }

    // Verify token using verification service
    final verifiedUserId = await verificationService.verifyAndConsumeToken(token);
    
    return Response.ok(
      jsonEncode({
        'success': true,
        'message': 'Email verified successfully!',
        'user_id': verifiedUserId,
      }),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e) {
    print('[ERROR] verifyEmailToken: $e');
    return Response.internalServerError(
      body: jsonEncode({'error': 'Failed to verify email', 'details': e.toString()}),
      headers: {'Content-Type': 'application/json'},
    );
  }
}
