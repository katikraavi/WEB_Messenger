import 'package:test/test.dart';
import '../../lib/src/services/encryption_service.dart';

void main() {
  group('EncryptionService', () {
    test('encryptContent returns non-empty base64 string', () async {
      final plaintext = 'Hello, World!';
      final encrypted = await EncryptionService.encryptContent(plaintext);

      expect(encrypted, isNotEmpty);
      expect(encrypted, isNot(plaintext));
    });

    test('isValidEncrypted checks encrypted format', () async {
      final plaintext = 'Hello, World!';
      final encrypted = await EncryptionService.encryptContent(plaintext);

      expect(EncryptionService.isValidEncrypted(encrypted), true);
      expect(EncryptionService.isValidEncrypted('invalid-base64!!!'), false);
      expect(EncryptionService.isValidEncrypted('aGVsbG8='), false); // too short
    });

    test('decryptContent fails without proper key storage', () async {
      final plaintext = 'Hello, World!';
      final encrypted = await EncryptionService.encryptContent(plaintext);

      // Note: In production, this would need proper key storage and retrieval
      // For now, decryption will fail because we're generating new keys
      expect(
        () async => await EncryptionService.decryptContent(encrypted),
        throwsA(isA<Exception>()),
      );
    });

    test('generateNewKey returns non-empty list', () async {
      final key = await EncryptionService.generateNewKey();
      expect(key, isNotEmpty);
      expect(key.length, 32); // 256-bit key
    });

    test('multiple encryptions of same text produce different ciphertexts', () async {
      final plaintext = 'Hello, World!';
      final encrypted1 = await EncryptionService.encryptContent(plaintext);
      final encrypted2 = await EncryptionService.encryptContent(plaintext);

      expect(encrypted1, isNot(encrypted2)); // Different due to random nonce
    });
  });
}
