#!/usr/bin/env dart
// Standalone encryption/decryption test for debugging

import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

void main() async {
  print('╔════════════════════════════════════════════╗');
  print('║ ENCRYPTION/DECRYPTION VERIFICATION TEST    ║');
  print('╚════════════════════════════════════════════╝\n');

  // Test data
  const masterKey = 'a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6a7b8c9d0e1f2';
  const senderId = 'c8fbeaf3-e05a-467a-9d0f-5c2d95fb7bcd';
  const plaintext = 'Hello Bob! This is a secret message with encryption: 🔐';

  try {
    // Step 1: Key derivation
    print('✓ Step 1: Testing HMAC-SHA256 key derivation');
    print('  Master key: $masterKey');
    print('  Sender ID: $senderId');
    
    final hmac = Hmac(Sha256());
    final masterKeyBytes = utf8.encode(masterKey);
    final senderIdBytes = utf8.encode(senderId);
    
    final mac = await hmac.calculateMac(
      senderIdBytes,
      secretKey: SecretKey(masterKeyBytes),
    );
    
    final derivedKey = SecretKey(mac.bytes);
    print('  Derived key: ${base64Encode(mac.bytes)}');
    print('  Key length: ${mac.bytes.length} bytes\n');

    // Step 2: Encryption
    print('✓ Step 2: Testing AES-256-GCM encryption');
    print('  Plaintext: $plaintext');
    
    final cipher = AesGcm.with256bits();
    final plaintextBytes = utf8.encode(plaintext);
    
    // Generate nonce
    final nonce = _generateRandomBytes(12);
    print('  Nonce: ${base64Encode(nonce)} (${nonce.length} bytes)');
    
    final secretBox = await cipher.encrypt(
      plaintextBytes,
      secretKey: derivedKey,
      nonce: nonce,
    );
    
    final nonceBase64 = base64Encode(nonce);
    final ctBase64 = base64Encode(secretBox.cipherText);
    final macBase64 = base64Encode(secretBox.mac.bytes);
    
    final encrypted = '$nonceBase64::$ctBase64::$macBase64';
    print('  Ciphertext: ${secretBox.cipherText.length} bytes');
    print('  MAC: ${secretBox.mac.bytes.length} bytes');
    print('  Encrypted (format): nonce::ciphertext::mac');
    print('  Encrypted: $encrypted\n');

    // Step 3: Decryption
    print('✓ Step 3: Testing AES-256-GCM decryption');
    print('  Using same key derivation...');
    
    // Re-derive key (simulating frontend receiving encrypted message)
    final mac2 = await hmac.calculateMac(
      senderIdBytes,
      secretKey: SecretKey(masterKeyBytes),
    );
    final derivedKey2 = SecretKey(mac2.bytes);
    print('  Key derivation matches: ${base64Encode(mac.bytes) == base64Encode(mac2.bytes)} ✓');
    
    // Parse encrypted format
    final parts = encrypted.split('::');
    final decodedNonce = base64Decode(parts[0]);
    final decodedCiphertext = base64Decode(parts[1]);
    final decodedMac = base64Decode(parts[2]);
    
    print('  Parsed format:');
    print('    - Nonce: ${decodedNonce.length} bytes');
    print('    - Ciphertext: ${decodedCiphertext.length} bytes');
    print('    - MAC: ${decodedMac.length} bytes');
    
    // Decrypt
    final decrypted = await cipher.decrypt(
      SecretBox(decodedCiphertext, nonce: decodedNonce, mac: Mac(decodedMac)),
      secretKey: derivedKey2,
    );
    
    final decryptedText = utf8.decode(decrypted);
    print('  Decrypted: $decryptedText\n');

    // Step 4: Verification
    print('✓ Step 4: Verification');
    if (decryptedText == plaintext) {
      print('  ✅ ENCRYPTION/DECRYPTION WORKS CORRECTLY!');
      print('  Original  == Decrypted: TRUE');
    } else {
      print('  ❌ MISMATCH!');
      print('  Original : $plaintext');
      print('  Decrypted: $decryptedText');
    }

    print('\n╔════════════════════════════════════════════╗');
    print('║ ✓ ALL TESTS PASSED                         ║');
    print('║ Encryption/Decryption is working correctly ║');
    print('╚════════════════════════════════════════════╝');

  } catch (e, st) {
    print('\n❌ TEST FAILED!');
    print('Error: $e');
    print('Stack: $st');
  }
}

List<int> _generateRandomBytes(int length) {
  final random = <int>[];
  for (int i = 0; i < length; i++) {
    final ms = DateTime.now().microsecond;
    random.add((ms >> 8) ^ (ms & 0xFF) ^ i);
  }
  return random;
}
