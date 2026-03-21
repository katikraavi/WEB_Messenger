import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import '../services/email_service.dart';
import '../services/rate_limit_service.dart';
import '../services/token_service.dart';
import '../services/verification_service.dart';

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
  VerificationService verificationService,
) async {
  try {
    // Parse request
    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;
    final email = data['email'] as String?;
    String? userId = data['userId'] as String?;

    if (email == null || email.isEmpty) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Email is required'}),
      );
    }

    if (userId == null || userId.isEmpty) {
      // Allow resend by email when frontend does not have userId in state.
      final lookup = await verificationService.connection.query(
        'SELECT id, email_verified FROM "users" WHERE LOWER(email) = LOWER(@email) LIMIT 1',
        substitutionValues: {'email': email},
      );

      if (lookup.isEmpty) {
        return Response(404,
          body: jsonEncode({'error': 'Account not found for this email'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final row = lookup.first.toColumnMap();
      final alreadyVerified = row['email_verified'] as bool? ?? false;
      if (alreadyVerified) {
        return Response(409,
          body: jsonEncode({'error': 'Email is already verified'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      userId = row['id'] as String;
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
    final appBaseUrl = Platform.environment['APP_BASE_URL'] ?? 'http://localhost:8081';
    
    // Build verification email
    final emailMessage = emailService.buildVerificationEmail(
      recipientEmail: email,
      recipientName: email.split('@')[0],
      verificationLink: '$appBaseUrl/auth/verify-email/confirm?token=$token',
      expiresIn: '24 hours',
    );

    // Send email and fail the request if SMTP delivery fails.
    await emailService.sendEmail(emailMessage);

    final bool isDevelopment = !bool.fromEnvironment('dart.vm.product');
    final successMessage = emailService.isUsingMailhog
        ? 'Verification email captured in MailHog at http://localhost:8025.'
        : 'Verification email accepted by SMTP. If it does not arrive, check spam and verify SMTP sender configuration.';

    final responseBody = {
      'success': true,
      'message': successMessage,
    };
    
    if (isDevelopment) {
      responseBody['token'] = token;
      responseBody['verificationLink'] = '$appBaseUrl/auth/verify-email/confirm?token=$token';
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
  VerificationService verificationService,
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
    final verified = await verificationService.verifyAndConsumeToken(token);
    if (!verified) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Invalid or expired token'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    return Response.ok(
      jsonEncode({
        'success': true,
        'message': 'Email verified successfully!',
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
