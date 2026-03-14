import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'auth_exception.dart';

/// Payload data from a validated JWT token
class JwtPayload {
  /// User ID from token
  final String userId;

  /// User email from token
  final String email;

  /// Token issued at (Unix timestamp)
  final int issuedAt;

  /// Token expiration time (Unix timestamp)
  final int expiresAt;

  /// Token ID for revocation support
  final String jti;

  /// Creates a [JwtPayload] with token claims
  JwtPayload({
    required this.userId,
    required this.email,
    required this.issuedAt,
    required this.expiresAt,
    required this.jti,
  });

  /// Checks if token is expired
  bool get isExpired {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return now > expiresAt;
  }

  /// Converts payload to map for encoding
  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'email': email,
      'iat': issuedAt,
      'exp': expiresAt,
      'jti': jti,
    };
  }

  /// Creates [JwtPayload] from map
  factory JwtPayload.fromMap(Map<String, dynamic> map) {
    return JwtPayload(
      userId: map['user_id'] as String,
      email: map['email'] as String,
      issuedAt: map['iat'] as int,
      expiresAt: map['exp'] as int,
      jti: map['jti'] as String,
    );
  }
}

/// Manages JWT token generation, validation, and expiration
class JwtService {
  /// Secret key for signing tokens (in production, use environment variable or secure storage)
  static const String _secretKey = 'mobile-messenger-secret-key-change-in-production-2026';

  /// Token expiration time in days
  static const int tokenExpirationDays = 30;

  /// Generates a new JWT token for a user
  ///
  /// Returns JWT string in format: header.payload.signature
  /// Token includes user_id, email, issued_at, expiration, and unique token ID
  /// Expiration is set to [tokenExpirationDays] from now
  ///
  /// Throws [AuthException] if token generation fails
  static String generateToken(String userId, String email) {
    try {
      final now = DateTime.now();
      final expiresAt = now.add(Duration(days: tokenExpirationDays));

      final payload = JwtPayload(
        userId: userId,
        email: email,
        issuedAt: now.millisecondsSinceEpoch ~/ 1000,
        expiresAt: expiresAt.millisecondsSinceEpoch ~/ 1000,
        jti: _generateTokenId(),
      );

      // Create JWT: header.payload.signature
      final header = _encodeBase64(jsonEncode(_createHeader()));
      final payloadJson = _encodeBase64(jsonEncode(payload.toMap()));
      final signature = _createSignature('$header.$payloadJson');

      return '$header.$payloadJson.$signature';
    } catch (e) {
      throw AuthException(
        'Failed to generate token',
        code: 'server_error',
      );
    }
  }

  /// Validates a JWT token and extracts its payload
  ///
  /// Returns [JwtPayload] if token is valid
  ///
  /// Throws [AuthException] if:
  /// - Token format is invalid
  /// - Signature verification fails
  /// - Token is expired
  static JwtPayload validateToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        throw AuthException(
          'Invalid token format',
          code: 'token_invalid',
        );
      }

      final header = parts[0];
      final payload = parts[1];
      final signature = parts[2];

      // Verify signature
      final expectedSignature = _createSignature('$header.$payload');
      if (!_constantTimeEquals(signature, expectedSignature)) {
        throw AuthException(
          'Token signature verification failed',
          code: 'token_invalid',
        );
      }

      // Decode and parse payload
      final payloadJson = jsonDecode(_decodeBase64(payload)) as Map<String, dynamic>;
      final jwtPayload = JwtPayload.fromMap(payloadJson);

      // Check expiration
      if (jwtPayload.isExpired) {
        throw AuthException(
          'Token has expired',
          code: 'token_expired',
        );
      }

      return jwtPayload;
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException(
        'Token validation failed',
        code: 'token_invalid',
      );
    }
  }

  /// Checks if a token is expired without full validation
  ///
  /// Returns true if token is expired, false if still valid
  /// Returns false if token format is invalid (assumes valid for safe fallback)
  static bool isTokenExpired(String token) {
    try {
      final payload = validateToken(token);
      return payload.isExpired;
    } catch (e) {
      // If validation fails, consider token invalid/expired
      return true;
    }
  }

  /// Creates JWT standard header
  static Map<String, String> _createHeader() {
    return {
      'alg': 'HS256',
      'typ': 'JWT',
    };
  }

  /// Creates HMAC signature for token
  static String _createSignature(String message) {
    final secretBytes = utf8.encode(_secretKey);
    final key = utf8.encode(message);
    final hmacSha256 = Hmac(sha256, secretBytes);
    return hmacSha256.convert(key).toString();
  }

  /// Generates unique token ID for revocation support
  static String _generateTokenId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  /// Base64 URL-safe encoding without padding
  static String _encodeBase64(String input) {
    final bytes = utf8.encode(input);
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  /// Base64 URL-safe decoding
  static String _decodeBase64(String input) {
    // Add padding if needed (0, 1, or 2 characters maximum)
    final paddingNeeded = (4 - input.length % 4) % 4;
    final padded = input + '=' * paddingNeeded;
    return utf8.decode(base64Url.decode(padded));
  }

  /// Constant-time string comparison to prevent timing attacks
  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) {
      return false;
    }

    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }

    return result == 0;
  }
}
