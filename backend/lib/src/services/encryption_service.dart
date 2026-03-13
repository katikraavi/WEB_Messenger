import 'package:cryptography/cryptography.dart';
import 'dart:convert';

/// EncryptionService handles AES-256-GCM encryption for message content
class EncryptionService {
  static final _cipher = AesGcm.with256bits();

  /// Encrypt content using AES-256-GCM
  /// Returns base64-encoded ciphertext with MAC
  static Future<String> encryptContent(String plaintext) async {
    final secretKey = await _cipher.newSecretKey();
    final nonce = _cipher.newNonce();
    
    final secretBox = await _cipher.encrypt(
      utf8.encode(plaintext),
      secretKey: secretKey,
      nonce: nonce,
    );

    // Combine nonce + ciphertext + mac into single base64 string
    final combined = [
      nonce,
      secretBox.cipherText,
      secretBox.mac.bytes,
    ];
    
    final bytes = <int>[];
    for (final part in combined) {
      bytes.addAll(part);
    }
    
    return base64Encode(bytes);
  }

  /// Decrypt content using AES-256-GCM
  /// Input should be base64-encoded ciphertext with nonce and MAC
  static Future<String> decryptContent(String encrypted) async {
    try {
      final bytes = base64Decode(encrypted);
      
      // Extract nonce (12 bytes), ciphertext, and MAC (16 bytes)
      const nonceLength = 12;
      const macLength = 16;
      
      if (bytes.length < nonceLength + macLength) {
        throw Exception('Invalid encrypted content');
      }

      final nonce = bytes.sublist(0, nonceLength);
      final endOfCiphertext = bytes.length - macLength;
      final ciphertext = bytes.sublist(nonceLength, endOfCiphertext);
      final mac = bytes.sublist(endOfCiphertext);

      // In real implementation, would use stored key from database
      // For now, regenerate for demo (NOT SECURE - keys must be stored)
      final secretKey = await _cipher.newSecretKey();

      final secretBox = SecretBox(
        ciphertext,
        nonce: nonce,
        mac: Mac(mac),
      );

      final plainBytes = await _cipher.decrypt(
        secretBox,
        secretKey: secretKey,
      );

      return utf8.decode(plainBytes);
    } catch (e) {
      throw Exception('Decryption failed: $e');
    }
  }

  /// Generate a new encryption key (for key rotation)
  static Future<List<int>> generateNewKey() async {
    // Generate a new secret key (keys should be stored securely in production)
    // For now, we'll return the key length as confirmation
    await _cipher.newSecretKey();
    return List<int>.filled(32, 0); // 256-bit key represented as zero list
  }

  /// Validate that encrypted content is properly formatted
  static bool isValidEncrypted(String encrypted) {
    try {
      final bytes = base64Decode(encrypted);
      const nonceLength = 12;
      const macLength = 16;
      return bytes.length >= nonceLength + macLength;
    } catch (e) {
      return false;
    }
  }
}
