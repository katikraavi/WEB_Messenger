import 'dart:convert';
import 'package:cryptography/cryptography.dart';

/// Frontend decryption service that mirrors backend encryption
/// 
/// Decrypts messages encrypted with AES-256-CBC using user-derived keys
class DecryptionService {
  final String? masterKeyHex;

  DecryptionService({this.masterKeyHex});

  /// Derives per-user key from user ID and master key (same as backend)
  /// HMAC-SHA256(user_id, master_key) → 32-byte key
  Future<SecretKey> _deriveKey(String userId) async {
    if (masterKeyHex == null || masterKeyHex!.isEmpty) {
      throw Exception('Master key not configured');
    }

    try {
      // Convert hex string to bytes
      final masterKeyBytes = _hexToBytes(masterKeyHex!);
      
      // HMAC-SHA256(user_id, master_key)
      final hmac = Hmac(Sha256());
      final userIdBytes = utf8.encode(userId);
      
      final mac = await hmac.calculateMac(
        userIdBytes,
        secretKey: SecretKey(masterKeyBytes),
      );
      
      return SecretKey(mac.bytes);
    } catch (e) {
      throw Exception('Key derivation failed: $e');
    }
  }

  /// Decrypts AES-256-CBC encrypted text
  /// 
  /// Input format: base64(iv)::base64(ciphertext) (from server)
  /// Returns: Original plaintext
  /// 
  /// Throws: Exception if decryption fails
  Future<String> decrypt(String encrypted, String userId) async {
    try {
      if (encrypted.isEmpty) {
        return '';
      }

      // Parse format: base64(iv)::base64(ciphertext)
      final parts = encrypted.split('::');
      if (parts.length != 2) {
        // Not encrypted with our format, return as-is (backwards compatibility)
        return encrypted;
      }

      final ivBase64 = parts[0];
      final ctBase64 = parts[1];

      try {
        final iv = base64Decode(ivBase64);
        final ciphertext = base64Decode(ctBase64);

        if (iv.length != 16) {
          throw Exception('Invalid IV length');
        }

        final key = await _deriveKey(userId);
        final cipher = AesCbc(256);

        final decrypted = await cipher.decrypt(
          SecretBox(ciphertext, nonce: iv),
          secretKey: key,
        );

        return utf8.decode(decrypted);
      } on FormatException {
        // If base64 decode fails, return original (not encrypted)
        return encrypted;
      }
    } catch (e) {
      print('[DecryptionService] Decryption failed: $e');
      throw Exception('Decryption failed: $e');
    }
  }

  /// Checks if a string is encrypted in our format
  bool isEncrypted(String value) {
    if (value.isEmpty) return false;
    final parts = value.split('::');
    if (parts.length != 2) return false;

    try {
      base64Decode(parts[0]); // IV
      base64Decode(parts[1]); // Ciphertext
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Convert hex string to bytes
  static List<int> _hexToBytes(String hex) {
    final result = <int>[];
    for (int i = 0; i < hex.length; i += 2) {
      final chunk = hex.substring(i, i + 2);
      result.add(int.parse(chunk, radix: 16));
    }
    return result;
  }
}
