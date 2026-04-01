import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

/// Service for AES-256-GCM encryption and decryption with HMAC key derivation
/// 
/// Provides simple encryption/decryption for message content using AES-256-GCM
/// which is built into the cryptography package.
class EncryptionService {
  final String masterEncryptionKey;
  final AesGcm _cipher = AesGcm.with256bits();

  EncryptionService({required this.masterEncryptionKey}) {
    if (masterEncryptionKey.isEmpty) {
      throw ArgumentError('Master encryption key cannot be empty');
    }
  }

  /// Derives a user-specific key from user ID and master key using HMAC
  Future<SecretKey> _deriveKey(String userId) async {
    // HMAC(master_key, user_id) to derive per-user key
    final hmac = Hmac(Sha256());
    final masterKeyBytes = utf8.encode(masterEncryptionKey);
    final userIdBytes = utf8.encode(userId);
    
    final mac = await hmac.calculateMac(
      userIdBytes,
      secretKey: SecretKey(masterKeyBytes),
    );
    
    return SecretKey(mac.bytes);
  }

  /// Encrypts plaintext using AES-256-GCM for a specific user.
  /// Returns base64(nonce)::base64(ciphertext)::base64(mac) for storage.
  ///
  /// Usage pattern for newly introduced entities:
  /// - Group chat names (`group_chats.name`): encrypt before INSERT/UPDATE,
  ///   decrypt when materializing API response.
  /// - Poll question (`polls.question`): encrypt before persistence,
  ///   decrypt before returning to clients.
  /// - Poll option text (`poll_options.text`): encrypt each option before write,
  ///   decrypt when assembling poll payloads.
  ///
  /// Recommended write path:
  /// 1. Validate non-empty business value.
  /// 2. `final encrypted = await encrypt(value, ownerUserId);`
  /// 3. Persist encrypted value only.
  ///
  /// Recommended read path:
  /// 1. Read encrypted DB value.
  /// 2. If non-empty, `final value = await decrypt(encrypted, ownerUserId);`
  /// 3. Return decrypted value in API response.
  Future<String> encrypt(String plaintext, String userId) async {
    try {
      if (plaintext.isEmpty) {
        return ''; // Don't encrypt empty strings
      }

      final key = await _deriveKey(userId);
      final plaintextBytes = utf8.encode(plaintext);

      // Generate random 12-byte nonce for GCM (96 bits)
      final nonce = _generateRandomBytes(12);

      final secretBox = await _cipher.encrypt(
        plaintextBytes,
        secretKey: key,
        nonce: nonce,
      );

      // Return format: base64(nonce)::base64(ciphertext)::base64(mac)
      final nonceBase64 = base64Encode(nonce);
      final ctBase64 = base64Encode(secretBox.cipherText);
      final macBase64 = base64Encode(secretBox.mac.bytes);

      return '$nonceBase64::$ctBase64::$macBase64';
    } catch (e) {
      throw Exception('Encryption failed: $e');
    }
  }

  /// Generates cryptographically secure random bytes using Random.secure()
  List<int> _generateRandomBytes(int length) {
    final random = Random.secure();
    final values = List<int>.generate(length, (_) => random.nextInt(256));
    return values;
  }

  /// Decrypts AES-256-GCM payload and returns original plaintext.
  ///
  /// Supported formats:
  /// - base64(nonce)::base64(ciphertext)::base64(mac) [current]
  /// - base64(nonce)::base64(ciphertext+mac) [legacy compatibility]
  Future<String> decrypt(String encrypted, String userId) async {
    try {
      if (encrypted.isEmpty) {
        return ''; // Don't decrypt empty strings
      }

      // Parse format: base64(nonce)::base64(ciphertext)::base64(mac)
      // Legacy: base64(nonce)::base64(ciphertext+mac)
      final parts = encrypted.split('::');
      if (parts.length != 2 && parts.length != 3) {
        throw FormatException(
          'Invalid encrypted format: expected "nonce::ciphertext::mac"',
        );
      }

      final nonceBase64 = parts[0];
      final ctBase64 = parts[1];
      final macBase64 = parts.length == 3 ? parts[2] : null;

      final nonce = base64Decode(nonceBase64);
      var ciphertext = base64Decode(ctBase64);
      late final Mac mac;

      if (macBase64 != null && macBase64.isNotEmpty) {
        mac = Mac(base64Decode(macBase64));
      } else {
        // Legacy compatibility: some older payloads may have ciphertext+mac
        // combined in the second segment.
        if (ciphertext.length <= 16) {
          throw FormatException('Ciphertext is too short to contain MAC');
        }
        final splitIndex = ciphertext.length - 16;
        final macBytes = ciphertext.sublist(splitIndex);
        ciphertext = ciphertext.sublist(0, splitIndex);
        mac = Mac(macBytes);
      }

      // GCM nonce should be 12 bytes (96 bits)
      if (nonce.length != 12) {
        throw FormatException('Invalid nonce length: expected 12 bytes, got ${nonce.length}');
      }

      final key = await _deriveKey(userId);

      final decrypted = await _cipher.decrypt(
        SecretBox(ciphertext, nonce: nonce, mac: mac),
        secretKey: key,
      );

      return utf8.decode(decrypted);
    } catch (e) {
      throw Exception('Decryption failed: $e');
    }
  }

  /// Validates if a string is encrypted (contains valid GCM format)
  bool isEncrypted(String value) {
    if (value.isEmpty) return false;
    final parts = value.split('::');
    if (parts.length != 2 && parts.length != 3) return false;
    
    try {
      base64Decode(parts[0]); // Nonce
      base64Decode(parts[1]); // Ciphertext (or ciphertext+mac)
      if (parts.length == 3) {
        base64Decode(parts[2]); // MAC
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}
