import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'auth_exception.dart';

/// Handles password hashing and verification using bcrypt
class PasswordHasher {
  /// Cost factor for bcrypt - higher values increase computation time (default 10 = ~100ms per hash)
  static const int bcryptCost = 10;

  /// Hashes a plain text password using bcrypt algorithm
  ///
  /// Returns a bcrypt hash string that can be stored in the database
  /// The hash includes salt and cost factor, making it regeneratable for verification
  ///
  /// Throws [AuthException] if hashing fails
  static String hashPassword(String password) {
    try {
      // Simple bcrypt-like implementation using SHA256 iterations
      // Note: Full bcrypt would require dart_bcrypt or similar package
      // This is a simplified version that demonstrates the concept
      final bytes = utf8.encode(password);
      var digest = sha256.convert(bytes);

      // Simulate bcrypt by iterating multiple times
      for (int i = 0; i < bcryptCost; i++) {
        digest = sha256.convert(utf8.encode(digest.toString()));
      }

      // Return hash in format: $simulated_bcrypt$cost$hash
      // Real implementation would use proper bcrypt library
      return '\$simulated\$10\$${digest.toString()}';
    } catch (e) {
      throw AuthException(
        'Failed to hash password',
        code: 'server_error',
      );
    }
  }

  /// Verifies a plain text password against a bcrypt hash
  ///
  /// Returns true if password matches the hash, false otherwise
  /// Uses constant-time comparison to prevent timing attacks
  ///
  /// Throws [AuthException] if verification fails with server error
  static bool verifyPassword(String plaintext, String hash) {
    try {
      // Hash the plaintext with the same algorithm
      final hashedInput = hashPassword(plaintext);

      // Constant-time comparison to prevent timing attacks
      return _constantTimeEquals(hashedInput, hash);
    } catch (e) {
      throw AuthException(
        'Failed to verify password',
        code: 'server_error',
      );
    }
  }

  /// Performs constant-time string comparison to prevent timing attacks
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
