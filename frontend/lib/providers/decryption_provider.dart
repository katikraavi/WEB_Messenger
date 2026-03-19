import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'decryption_service.dart';

/// Provider for DecryptionService singleton
/// 
/// Usage: `ref.read(decryptionServiceProvider)`
final decryptionServiceProvider = Provider<DecryptionService>((ref) {
  // TODO: Load master key from secure storage or environment
  // For now, use null (will gracefully skip decryption)
  return DecryptionService(masterKeyHex: null);
});

/// Provider for decrypting a message
/// 
/// Usage: `ref.watch(decryptMessageProvider((encryptedText, userId)))`
final decryptMessageProvider = FutureProvider.family<String, (String, String)>(
  (ref, params) async {
    final (encrypted, userId) = params;
    final service = ref.watch(decryptionServiceProvider);
    
    try {
      return await service.decrypt(encrypted, userId);
    } catch (e) {
      // Graceful fallback: return original text if decryption fails
      return encrypted;
    }
  },
);

/// Helper to safely decrypt text
/// 
/// Returns:
/// - Decrypted text if encrypted format detected and decryption succeeds
/// - Original text if message is not encrypted
/// - Placeholder if decryption fails
Future<String> safeDecrypt(
  String text,
  String userId,
  DecryptionService service,
) async {
  try {
    if (text.isEmpty) return '';
    
    // Check if it looks encrypted
    if (service.isEncrypted(text)) {
      return await service.decrypt(text, userId);
    }
    
    // Not encrypted, return as-is
    return text;
  } catch (e) {
    print('[safeDecrypt] Failed to decrypt: $e');
    return '[Message could not be decrypted]';
  }
}
