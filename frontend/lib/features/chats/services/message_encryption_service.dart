import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/message_model.dart';

/// Service for message encryption/decryption
/// 
/// For MVP: Uses simple base64 encoding
/// In production: Should use proper end-to-end encryption
class MessageEncryptionService {
  /// Decrypt a message's encrypted content
  /// 
  /// For MVP: Decodes base64 content
  /// In production: Would use proper decryption
  /// 
  /// Parameters:
  /// - message: The Message with encrypted_content (base64-encoded)
  /// 
  /// Returns: Message with decryptedContent populated
  static Future<Message> decryptMessage(
    Message message,
  ) async {
    try {
      // For MVP: Decode base64
      final decrypted = utf8.decode(base64Decode(message.encryptedContent));
      return message.copyWith(decryptedContent: decrypted);
    } catch (e) {
      debugPrint('[MessageEncryptionService] Failed to decrypt message ${message.id}: $e');
      // If decryption fails, return the encrypted content as-is
      return message.copyWith(decryptedContent: 'Could not decrypt message');
    }
  }

  /// Decrypt multiple messages
  /// 
  /// Parameters:
  /// - messages: List of Message objects with encrypted_content
  /// 
  /// Returns: List of Messages with decryptedContent populated
  static Future<List<Message>> decryptMessages(
    List<Message> messages,
  ) async {
    try {
      final decrypted = <Message>[];
      for (final message in messages) {
        final decryptedMsg = await decryptMessage(message);
        decrypted.add(decryptedMsg);
      }
      return decrypted;
    } catch (e) {
      throw Exception('Failed to decrypt messages: $e');
    }
  }

  /// Encrypt plaintext message content
  /// 
  /// For MVP: Uses base64 encoding
  /// In production: Should use proper encryption
  /// 
  /// Parameters:
  /// - plaintext: The message content to encrypt
  /// 
  /// Returns: Base64-encoded content (suitable for storage)
  static String encryptMessage(String plaintext) {
    if (plaintext.isEmpty) {
      throw ArgumentError('Cannot encrypt empty message');
    }
    // For MVP: Simple base64 encoding
    return base64Encode(utf8.encode(plaintext));
  }
}
