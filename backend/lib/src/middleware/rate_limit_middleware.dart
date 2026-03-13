import 'dart:convert';
import 'package:shelf/shelf.dart';

/// Tracks failed login attempts per IP address for rate limiting
class _LoginAttempt {
  /// Number of failed attempts
  int failureCount = 0;

  /// When the current attempt window started
  DateTime windowStart = DateTime.now();

  /// Whether this IP is currently rate limited
  bool get isRateLimited {
    final now = DateTime.now();
    final windowAge = now.difference(windowStart);

    // Reset counter if window expired (60 seconds)
    if (windowAge.inSeconds > 60) {
      failureCount = 0;
      windowStart = now;
      return false;
    }

    return failureCount >= 5;
  }

  /// Adds a failed attempt and returns whether now rate limited
  bool recordFailure() {
    final now = DateTime.now();
    final windowAge = now.difference(windowStart);

    // Reset if window expired
    if (windowAge.inSeconds > 60) {
      failureCount = 1;
      windowStart = now;
      return false;
    }

    failureCount++;
    return isRateLimited;
  }

  /// Resets attempt counter (for successful login)
  void resetAttempts() {
    failureCount = 0;
    windowStart = DateTime.now();
  }
}

/// Rate limiting middleware to prevent brute force login attacks
class RateLimitMiddleware {
  /// In-memory store of login attempts per IP
  static final Map<String, _LoginAttempt> _attemptsByIp = {};

  /// Cleanup interval for expired entries (5 minutes)
  static final Duration _cleanupInterval = Duration(minutes: 5);

  /// Last cleanup time
  static DateTime _lastCleanup = DateTime.now();

  /// Creates middleware that rate-limits /auth/login endpoint
  static Middleware rateLimitMiddleware() {
    return (Handler innerHandler) {
      return (Request request) async {
        // Only rate limit login attempts
        if (request.url.path != '/auth/login' || request.method != 'POST') {
          return innerHandler(request);
        }

        final clientIp = _getClientIp(request);

        try {
          // Trigger cleanup if interval exceeded
          _cleanupIfNeeded();

          // Get current attempt tracking
          final attempt = _attemptsByIp.putIfAbsent(
            clientIp,
            () => _LoginAttempt(),
          );

          // Check if rate limited
          if (attempt.isRateLimited) {
            return _rateLimitedResponse();
          }

          // Process the request
          final response = await innerHandler(request);

          // Track the outcome
          if (response.statusCode == 200 || response.statusCode == 201) {
            // Successful login - reset counter
            attempt.resetAttempts();
          } else if (response.statusCode == 401 || response.statusCode == 400) {
            // Failed login - record attempt
            attempt.recordFailure();
          }

          return response;
        } catch (e) {
          print('[ERROR] Rate limit middleware error: $e');
          // On error, still allow request but log it
          return innerHandler(request);
        }
      };
    };
  }

  /// Extracts client IP from request
  /// Checks X-Forwarded-For header (for proxied requests) then connection info
  static String _getClientIp(Request request) {
    // Check for X-Forwarded-For header (requests through proxy/load balancer)
    final forwardedFor = request.headers['x-forwarded-for'];
    if (forwardedFor != null && forwardedFor.isNotEmpty) {
      // Take the first IP if multiple are listed
      return forwardedFor.split(',').first.trim();
    }

    // Default fallback to 'localhost' for local connections
    return 'localhost';
  }

  /// Cleans up old entries from the attempts map if interval exceeded
  static void _cleanupIfNeeded() {
    final now = DateTime.now();
    if (now.difference(_lastCleanup) > _cleanupInterval) {
      // Remove entries older than 2 hours (window expired long ago)
      _attemptsByIp.removeWhere((ip, attempt) {
        return now.difference(attempt.windowStart).inHours > 2;
      });
      _lastCleanup = now;
    }
  }

  /// Creates 429 Too Many Requests response
  static Response _rateLimitedResponse() {
    return Response(
      429, // Too Many Requests
      body: jsonEncode({
        'error': 'Too many login attempts',
        'message': 'Please try again in 1 minute',
        'retry_after_seconds': 60,
      }),
      headers: {
        'Content-Type': 'application/json',
        'Retry-After': '60',
      },
    );
  }

  /// Resets rate limiting for testing or admin purposes
  /// Clears all tracked attempts
  static void resetAllAttempts() {
    _attemptsByIp.clear();
    _lastCleanup = DateTime.now();
  }

  /// Resets rate limiting for specific IP (testing)
  static void resetAttemptsForIp(String ip) {
    _attemptsByIp.remove(ip);
  }

  /// Gets current attempt count for IP (debugging/monitoring)
  static int getAttemptCount(String ip) {
    return _attemptsByIp[ip]?.failureCount ?? 0;
  }

  /// Checks if IP is currently rate limited (monitoring)
  static bool isIpRateLimited(String ip) {
    final attempt = _attemptsByIp[ip];
    return attempt != null && attempt.isRateLimited;
  }
}
