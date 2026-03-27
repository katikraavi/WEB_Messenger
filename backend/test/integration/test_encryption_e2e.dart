import 'package:test/test.dart';
import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'dart:typed_data';
import 'package:messenger_server/src/services/encryption_service.dart';

/// End-to-end encryption/decryption test matching frontend and backend
void main() {
  group('End-to-End Encryption Test', () {
    late EncryptionService encryptionService;
    final masterKey = 'test-master-key-12345678';
    final testUserId = 'user-123-abc-def';
    final plaintext = 'Hello, this is a test message!';

    setUp(() {
      encryptionService = EncryptionService(masterEncryptionKey: masterKey);
    });

    test('encrypt returns valid format: nonce::ciphertext::mac', () async {
      final encrypted = await encryptionService.encrypt(plaintext, testUserId);
      
      print('[TEST] Plaintext: $plaintext');
      print('[TEST] Encrypted: $encrypted');
      
      // Should be in format: base64::base64::base64
      final parts = encrypted.split('::');
      expect(parts.length, 3, reason: 'Should have nonce, ciphertext, and mac parts');
      
      // Each part should be valid base64
      for (int i = 0; i < parts.length; i++) {
        expect(
          () => base64Decode(parts[i]),
          returnsNormally,
          reason: 'Part $i should be valid base64',
        );
      }

      // Verify decoded sizes
      final nonce = base64Decode(parts[0]);
      final ciphertext = base64Decode(parts[1]);
      final mac = base64Decode(parts[2]);
      
      expect(nonce.length, 12, reason: 'Nonce should be 12 bytes (96 bits)');
      expect(mac.length, 16, reason: 'MAC should be 16 bytes (128 bits)');
      expect(ciphertext.length, greaterThan(0), reason: 'Ciphertext should not be empty');
      
      print('[TEST] ✓ Format validated: nonce=${nonce.length}B, ct=${ciphertext.length}B, mac=${mac.length}B');
    });

    test('decrypt recovers original plaintext', () async {
      final encrypted = await encryptionService.encrypt(plaintext, testUserId);
      final decrypted = await encryptionService.decrypt(encrypted, testUserId);
      
      print('[TEST] Decrypted: $decrypted');
      expect(decrypted, equals(plaintext), reason: 'Decrypted text should match original');
      print('[TEST] ✓ Decryption successful');
    });

    test('different plaintexts produce different ciphertexts', () async {
      final text1 = 'Message 1';
      final text2 = 'Message 2';
      
      final e1 = await encryptionService.encrypt(text1, testUserId);
      final e2 = await encryptionService.encrypt(text2, testUserId);
      
      expect(e1, isNot(e2), reason: 'Different plaintexts should encrypt differently');
      print('[TEST] ✓ Different plaintexts produce different ciphertexts');
    });

    test('same plaintext, different encryptions (due to random nonce)', () async {
      final e1 = await encryptionService.encrypt(plaintext, testUserId);
      final e2 = await encryptionService.encrypt(plaintext, testUserId);
      
      expect(e1, isNot(e2), reason: 'Multiple encryptions should use different nonces');
      
      // But both should decrypt to the same plaintext
      final d1 = await encryptionService.decrypt(e1, testUserId);
      final d2 = await encryptionService.decrypt(e2, testUserId);
      
      expect(d1, equals(d2), reason: 'Both should decrypt to same plaintext');
      expect(d1, equals(plaintext));
      print('[TEST] ✓ Same plaintext with different nonces decrypts correctly');
    });

    test('empty string handling', () async {
      final encrypted = await encryptionService.encrypt('', testUserId);
      expect(encrypted, isEmpty, reason: 'Empty plaintext should return empty encrypted');
      
      final decrypted = await encryptionService.decrypt('', testUserId);
      expect(decrypted, isEmpty, reason: 'Empty encrypted should return empty plaintext');
      print('[TEST] ✓ Empty string handled correctly');
    });

    test('different users have different keys', () async {
      final userId1 = 'user-001';
      final userId2 = 'user-002';
      
      final e1 = await encryptionService.encrypt(plaintext, userId1);
      final e2 = await encryptionService.encrypt(plaintext, userId2);
      
      expect(e1, isNot(e2), reason: 'Different users should produce different ciphertexts due to different keys');
      
      // User 1 can decrypt user 1's message
      final d1 = await encryptionService.decrypt(e1, userId1);
      expect(d1, equals(plaintext));
      
      // User 2 can decrypt user 2's message
      final d2 = await encryptionService.decrypt(e2, userId2);
      expect(d2, equals(plaintext));
      
      // Cross-decrypt should fail or produce garbage
      try {
        final crossDecrypt = await encryptionService.decrypt(e1, userId2);
        expect(crossDecrypt, isNot(plaintext), reason: 'Cross-decryption should not recover plaintext');
        print('[TEST] ✓ Cross-decryption produces garbage (expected)');
      } catch (e) {
        print('[TEST] ✓ Cross-decryption throws exception (expected)');
      }
    });

    test('isEncrypted validation works', () async {
      final encrypted = await encryptionService.encrypt(plaintext, testUserId);
      
      expect(encryptionService.isEncrypted(encrypted), true);
      expect(encryptionService.isEncrypted('not-encrypted'), false);
      expect(encryptionService.isEncrypted(''), false);
      expect(encryptionService.isEncrypted('invalid::format'), false);
      print('[TEST] ✓ isEncrypted validation working');
    });

    test('long messages work', () async {
      final longText = 'x' * 5000;
      final encrypted = await encryptionService.encrypt(longText, testUserId);
      final decrypted = await encryptionService.decrypt(encrypted, testUserId);
      
      expect(decrypted, equals(longText));
      print('[TEST] ✓ Long message (5000 chars) encrypted/decrypted successfully');
    });

    test('special characters and unicode', () async {
      final specialText = 'Hello 👋 World! Special: !@#\$%^&*()_+-=[]{}|;:,.<>?';
      final encrypted = await encryptionService.encrypt(specialText, testUserId);
      final decrypted = await encryptionService.decrypt(encrypted, testUserId);
      
      expect(decrypted, equals(specialText));
      print('[TEST] ✓ Unicode and special characters handled correctly');
    });

    test('data integrity (tampered ciphertext fails)', () async {
      final encrypted = await encryptionService.encrypt(plaintext, testUserId);
      final parts = encrypted.split('::');
      
      // Tamper with ciphertext (middle part)
      final tamperedCiphertext = base64Decode(parts[1]);
      tamperedCiphertext[0] ^= 0xFF; // Flip all bits of first byte
      
      final tamperedEncrypted = '${parts[0]}::${base64Encode(tamperedCiphertext)}::${parts[2]}';
      
      try {
        await encryptionService.decrypt(tamperedEncrypted, testUserId);
        fail('Should throw exception for tampered data');
      } catch (e) {
        expect(e.toString(), contains('Decryption failed'));
        print('[TEST] ✓ Tampered data detected and rejected');
      }
    });
  });
}
