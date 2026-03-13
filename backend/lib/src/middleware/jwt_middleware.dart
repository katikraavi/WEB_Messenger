import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../services/jwt_service.dart';
import '../services/auth_exception.dart';

/// JWT validation middleware for protecting endpoints
/// Validates bearer tokens and attaches user context to requests
class JwtMiddleware {
  /// List of paths that don't require JWT validation
  static const List<String> publicPaths = [
    '/auth/register',
    '/auth/login',
    '/health',
    '/schema',
  ];

  /// Creates middleware that validates JWT tokens on protected endpoints
  static Middleware jwtValidation() {
    return (Handler innerHandler) {
      return (Request request) async {
        // Skip JWT validation for public paths
        if (_isPublicPath(request.url.path)) {
          return innerHandler(request);
        }

        try {
          // Extract Authorization header
          final authHeader = request.headers['authorization'];
          if (authHeader == null || authHeader.isEmpty) {
            return _unauthorizedResponse('Missing authorization header');
          }

          // Extract bearer token
          final parts = authHeader.split(' ');
          if (parts.length != 2 || parts[0].toLowerCase() != 'bearer') {
            return _unauthorizedResponse('Invalid authorization header format');
          }

          final token = parts[1];

          // Validate token
          JwtPayload payload;
          try {
            payload = JwtService.validateToken(token);
          } on AuthException {
            return _unauthorizedResponse('Invalid or expired token');
          }

          // Attach user context to request for downstream handlers
          final updatedRequest = request.change(context: {
            ...request.context,
            'user': payload,
            'userId': payload.userId,
            'userEmail': payload.email,
          });

          return innerHandler(updatedRequest);
        } catch (e) {
          print('[ERROR] JWT middleware error: $e');
          return _unauthorizedResponse('Authentication failed');
        }
      };
    };
  }

  /// Checks if path is public (doesn't require JWT)
  static bool _isPublicPath(String path) {
    return publicPaths.any((p) => path.startsWith(p));
  }

  /// Creates 401 Unauthorized response
  static Response _unauthorizedResponse(String message) {
    return Response.unauthorized(
      jsonEncode({'error': message}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// Extracts user ID from request context
  /// Returns null if user context not found (request not authenticated)
  static String? extractUserId(Request request) {
    return request.context['userId'] as String?;
  }

  /// Extracts JWT payload from request context
  /// Returns null if payload not found (request not authenticated)
  static JwtPayload? extractUserPayload(Request request) {
    return request.context['user'] as JwtPayload?;
  }
}
