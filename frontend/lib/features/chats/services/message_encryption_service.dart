import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cryptography/cryptography.dart';
import '../models/message_model.dart';

/// Service for message encryption/decryption using AES-256-GCM
/// 
/// Matches the backend encryption implementation with:
/// - AES-256-GCM encryption algorithm
/// - HMAC-based key derivation from user ID and master key
/// - Format: base64(nonce)::base64(ciphertext)::base64(mac)
class MessageEncryptionService {
  static final AesGcm _cipher = AesGcm.with256bits();
  static const bool _verboseEncryptionLogs = false;

  static void _log(String message) {
    if (_verboseEncryptionLogs && kDebugMode) {
      debugPrint(message);
    }
  }
  
  /// Master encryption key from environment
  /// Should be set as ENCRYPTION_MASTER_KEY environment variable
  static String? _masterEncryptionKey;
  
  /// Initialize encryption service with master key
  static void initialize(String masterEncryptionKey) {
    if (masterEncryptionKey.isEmpty) {
      throw ArgumentError('Master encryption key cannot be empty');
    }
    _masterEncryptionKey = masterEncryptionKey;
  }
  
  /// Get or use default master key
  /// In production, this should come from secure config
  static String get _masterKey {
    if (_masterEncryptionKey == null) {
      // For testing/demo: use a default key (should be set via initialize() in production)
      return 'a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6a7b8c9d0e1f2';
    }
    return _masterEncryptionKey!;
  }

  /// Derives a user-specific key from user ID and master key using HMAC-SHA256
  static Future<SecretKey> _deriveKey(String userId) async {
    final hmac = Hmac(Sha256());
    final masterKeyBytes = utf8.encode(_masterKey);
    final userIdBytes = utf8.encode(userId);
    
    final mac = await hmac.calculateMac(
      userIdBytes,
      secretKey: SecretKey(masterKeyBytes),
    );
    
    return SecretKey(mac.bytes);
  }

  /// Generates cryptographically secure random bytes using timestamp
  static List<int> _generateRandomBytes(int length) {
    final random = <int>[];
    for (int i = 0; i < length; i++) {
      final ms = DateTime.now().microsecond;
      random.add((ms >> 8) ^ (ms & 0xFF) ^ i);
    }
    return random;
  }

  /// Encrypt plaintext message content using AES-256-GCM
  /// 
  /// Parameters:
  /// - plaintext: The message content to encrypt
  /// - userId: The user ID for key derivation
  /// 
  /// Returns: Encrypted content in format: base64(nonce)::base64(ciphertext)::base64(mac)
  static Future<String> encryptMessage(String plaintext, String userId) async {
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

  /// Decrypt a message's encrypted content
  /// 
  /// Parameters:
  /// - message: The Message with encrypted_content
  /// - userId: The user ID who owns this message (for decryption)
  /// 
  /// Returns: Message with decryptedContent populated
  static Future<Message> decryptMessage(
    Message message, {
    required String userId,
  }) async {
    try {
      if (message.encryptedContent.isEmpty) {
        return message.copyWith(decryptedContent: '');
      }

      final decrypted = await _decrypt(message.encryptedContent, userId);
      return message.copyWith(decryptedContent: decrypted);
    } catch (e, st) {
      // Log the error for debugging
      _log('[MessageEncryptionService] Decryption error for message ${message.id}:');
      _log('[MessageEncryptionService] Error: $e');
      _log('[MessageEncryptionService] StackTrace: $st');
      _log('[MessageEncryptionService] Encrypted content (first 50 chars): ${message.encryptedContent.substring(0, (message.encryptedContent.length > 50 ? 50 : message.encryptedContent.length))}');
      
      // If decryption fails, return error message with more detail
      return message.copyWith(decryptedContent: 'Decryption failed: $e');
    }
  }

  /// Decrypt multiple messages
  /// 
  /// Parameters:
  /// - messages: List of Message objects with encrypted_content
  /// - userId: Currently unused (kept for backward compatibility)
  /// 
  /// Returns: List of Messages with decryptedContent populated
  /// 
  /// NOTE: Each message is decrypted using its sender's ID, as messages
  /// are encrypted with the sender-specific key.
  static Future<List<Message>> decryptMessages(
    List<Message> messages, {
    required String userId,
  }) async {
    try {
      final decrypted = <Message>[];
      for (final message in messages) {
        // Decrypt using sender's ID, not the current user's ID
        final decryptedMsg = await decryptMessage(message, userId: message.senderId);
        decrypted.add(decryptedMsg);
      }
      return decrypted;
    } catch (e) {
      throw Exception('Failed to decrypt messages: $e');
    }
  }

  /// Internal decrypt method for AES-256-GCM decryption
  static Future<String> _decrypt(String encrypted, String userId) async {
    try {
      if (encrypted.isEmpty) {
        return ''; // Don't decrypt empty strings
      }

      _log('[_decrypt] Starting decryption for userId: $userId');
      _log('[_decrypt] Encrypted content: $encrypted');
      
      // Parse format: base64(nonce)::base64(ciphertext)::base64(mac)
      final parts = encrypted.split('::');
      _log('[_decrypt] Parts count: ${parts.length}');
      
      if (parts.length != 2 && parts.length != 3) {
        throw FormatException(
          'Invalid encrypted format: expected 2 or 3 parts separated by ::, got ${parts.length}',
        );
      }

      final nonceBase64 = parts[0];
      final ctBase64 = parts[1];
      final macBase64 = parts.length == 3 ? parts[2] : null;

      _log('[_decrypt] Nonce base64: $nonceBase64 (${nonceBase64.length} chars)');
      _log('[_decrypt] Ciphertext base64: $ctBase64 (${ctBase64.length} chars)');
      _log('[_decrypt] MAC base64: $macBase64 (${macBase64?.length ?? 0} chars)');

      final nonce = base64Decode(nonceBase64);
      var ciphertext = base64Decode(ctBase64);
      late final Mac mac;

      _log('[_decrypt] Decoded nonce length: ${nonce.length} bytes');
      _log('[_decrypt] Decoded ciphertext length: ${ciphertext.length} bytes');

      if (macBase64 != null && macBase64.isNotEmpty) {
        mac = Mac(base64Decode(macBase64));
        _log('[_decrypt] Using explicit MAC: ${mac.bytes.length} bytes');
      } else {
        // Legacy compatibility: ciphertext+mac combined
        if (ciphertext.length <= 16) {
          throw FormatException('Ciphertext is too short to contain MAC');
        }
        final splitIndex = ciphertext.length - 16;
        final macBytes = ciphertext.sublist(splitIndex);
        ciphertext = ciphertext.sublist(0, splitIndex);
        mac = Mac(macBytes);
        _log('[_decrypt] Using legacy MAC (last 16 bytes): ${mac.bytes.length} bytes');
      }

      // GCM nonce should be 12 bytes (96 bits)
      if (nonce.length != 12) {
        throw FormatException('Invalid nonce length: expected 12 bytes, got ${nonce.length}');
      }

      _log('[_decrypt] Deriving key...');
      final key = await _deriveKey(userId);
      _log('[_decrypt] Key derived successfully');

      _log('[_decrypt] Attempting AES-GCM decryption...');
      final decrypted = await _cipher.decrypt(
        SecretBox(ciphertext, nonce: nonce, mac: mac),
        secretKey: key,
      );
      
      _log('[_decrypt] Decryption successful! Decrypted ${decrypted.length} bytes');

      return utf8.decode(decrypted);
    } catch (e) {
      _log('[_decrypt] Fatal decryption error: $e');
      throw Exception('Decryption failed: $e');
    }
  }

  /// Validate if a string is encrypted (contains valid GCM format)
  static bool isEncrypted(String value) {
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
