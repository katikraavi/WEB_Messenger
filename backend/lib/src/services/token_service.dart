import 'dart:async';
import 'dart:convert';
import 'dart:math' show Random;
import 'package:cryptography/cryptography.dart';

/// TokenService generates, hashes, and verifies cryptographically secure tokens
/// 
/// Security approach:
/// - Tokens: 32-byte (256-bit) random data, Base64URL encoded
/// - Storage: Never stored plaintext; SHA256 hash stored in database
/// - Verification: Timing-safe comparison prevents timing attacks
class TokenService {
  static const int TOKEN_BYTE_LENGTH = 32; // 256-bit entropy
  static const int TOKEN_LENGTH_BASE64 = 43; // Base64URL encoded length

  /// Generate a new cryptographically secure token
  /// 
  /// Returns a Base64URL-encoded token (approximately 43 characters)
  /// Example: "nV7Zq1_pK2mX8bYc3dEfGhIjKlMnOpQrStUvWxYzAbCdEfGhIjKlMnOp"
  Future<String> generateToken() async {
    // Generate 32 bytes (256 bits) of cryptographically secure random data
    final random = Random.secure();
    final values = List<int>.generate(TOKEN_BYTE_LENGTH, (i) => random.nextInt(256));
    
    // Use Base64URL encoding (URL-safe without padding)
    return base64Url.encode(values).replaceAll('=', '');
  }

  /// Hash a token using SHA256 for secure storage
  /// 
  /// Never store tokens plaintext in database. Always hash before storage.
  /// Example: token "abc123" → hash "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
  Future<String> hashToken(String token) async {
    final sha256 = Sha256();
    final digest = await sha256.hash(utf8.encode(token));
    
    // Convert bytes to hex string
    return digest.bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Verify token against stored hash using timing-safe comparison
  /// 
  /// This prevents timing attacks where an attacker could learn parts of the
  /// token by measuring response time differences.
  /// 
  /// Returns true only if token hashes match the stored hash.
  Future<bool> verifyTokenHash(String token, String storedHash) async {
    try {
      final computedHash = await hashToken(token);
      
      // Timing-safe comparison: always check all bytes regardless of match
      // This prevents timing attacks from revealing token validity
      return _timingSafeEquals(computedHash, storedHash);
    } catch (e) {
      return false;
    }
  }

  /// Compare two strings in constant time to prevent timing attacks
  /// 
  /// Standard string comparison (==) can leak information via timing:
  /// - First char mismatch: fast
  /// - Last char mismatch: slow
  /// 
  /// This checks ALL characters regardless of match result.
  bool _timingSafeEquals(String a, String b) {
    if (a.length != b.length) {
      return false;
    }
    
    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }

  /// Validate token format (should be Base64URL, ~43 chars)
  bool isValidTokenFormat(String token) {
    if (token.length != TOKEN_LENGTH_BASE64) {
      return false;
    }
    
    // Check if it's valid Base64URL (alphanumeric, -, _, no padding =)
    final base64UrlRegex = RegExp(r'^[A-Za-z0-9_-]+$');
    return base64UrlRegex.hasMatch(token);
  }

  /// Validate token hash format (SHA256 hex = 64 characters)
  bool isValidHashFormat(String hash) {
    if (hash.length != 64) {
      return false;
    }
    
    // Check if it's valid hex (0-9, a-f)
    final hexRegex = RegExp(r'^[a-f0-9]+$');
    return hexRegex.hasMatch(hash);
  }
}
