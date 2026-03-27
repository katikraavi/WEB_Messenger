#!/usr/bin/env dart

import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;

void main() async {
  print('═══════════════════════════════════════════════════════════');
  print('  FRONTEND-LIKE ENCRYPTION TEST');
  print('═══════════════════════════════════════════════════════════\n');

  const apiUrl = 'http://localhost:8081';
  const aliceEmail = 'alice@example.com';
  const alicePass = 'alice123';
  
  // Step 1: Login
  print('[Step 1] Logging in as Alice...');
  final loginResponse = await http.post(
    Uri.parse('$apiUrl/auth/login'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'email': aliceEmail, 'password': alicePass}),
  );
  
  if (loginResponse.statusCode != 200) {
    print('✗ Login failed: ${loginResponse.body}');
    return;
  }
  
  final loginJson = jsonDecode(loginResponse.body);
  final token = loginJson['token'] as String;
  final userId = loginJson['user_id'] as String;
  
  print('✓ Login successful');
  print('  Token: ${token.substring(0, 20)}...');
  print('  User ID: $userId\n');
  
  // Step 2: Get chats
  print('[Step 2] Fetching chats...');
  final chatsResponse = await http.get(
    Uri.parse('$apiUrl/api/chats?limit=10'),
    headers: {'Authorization': 'Bearer $token'},
  );
  
  if (chatsResponse.statusCode != 200) {
    print('✗ Failed to fetch chats: ${chatsResponse.body}');
    return;
  }
  
  final chatsJson = jsonDecode(chatsResponse.body);
  final chatId = (chatsJson['chats'] as List<dynamic>?)?.first['id'] as String?;
  
  if (chatId == null) {
    print('✗ No chats found');
    return;
  }
  
  print('✓ Chat found: $chatId\n');
  
  // Step 3: Encrypt a message like the frontend does
  print('[Step 3] Encrypting message (AES-256-GCM)...');
  
  const plaintext = 'Test encryption message with emoji 🔐 and special chars: !@#\$%';
  print('Plaintext: $plaintext');
  
  final encryptedContent = await _encryptMessage(plaintext, userId);
  print('Encrypted: $encryptedContent');
  print('Format: nonce::ciphertext::mac\n');
  
  // Step 4: Send encrypted message
  print('[Step 4] Sending encrypted message to backend...');
  final sendResponse = await http.post(
    Uri.parse('$apiUrl/api/chats/$chatId/messages'),
    headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({'encrypted_content': encryptedContent}),
  );
  
  print('Response status: ${sendResponse.statusCode}');
  
  if (sendResponse.statusCode == 201 || sendResponse.statusCode == 200) {
    print('✓ Message sent successfully\n');
    
    final msgJson = jsonDecode(sendResponse.body);
    final messageId = msgJson['id'] ?? msgJson['message_id'];
    print('Message ID: $messageId');
    
    // Step 5: Fetch the message back
    print('\n[Step 5] Fetching message back from backend...');
    final fetchResponse = await http.get(
      Uri.parse('$apiUrl/api/chats/$chatId/messages?limit=1'),
      headers: {'Authorization': 'Bearer $token'},
    );
    
    if (fetchResponse.statusCode == 200) {
      final fetchJson = jsonDecode(fetchResponse.body);
      final message = (fetchJson['messages'] as List<dynamic>?)?.first;
      
      if (message != null) {
        final storedEncrypted = message['encrypted_content'] as String;
        print('✓ Message retrieved from backend');
        print('Stored encrypted: ${storedEncrypted.substring(0, 100)}...\n');
        
        // Step 6: Verify decryption (like frontend would do)
        print('[Step 6] Decrypting message (AES-256-GCM)...');
        try {
          final decrypted = await _decryptMessage(storedEncrypted, userId);
          print('✓ Decryption successful!');
          print('Decrypted: $decrypted\n');
          
          if (decrypted == plaintext) {
            print('═══════════════════════════════════════════════════════════');
            print('  ✅ END-TO-END ENCRYPTION TEST PASSED!');
            print('═══════════════════════════════════════════════════════════');
          } else {
            print('✗ Decrypted text does not match original');
            print('Expected: $plaintext');
            print('Got: $decrypted');
          }
        } catch (e) {
          print('✗ Decryption failed: $e');
        }
      }
    }
  } else {
    print('✗ Failed to send message: ${sendResponse.body}');
  }
}

// Frontend encryption helper (matches message_encryption_service.dart)
Future<String> _encryptMessage(String plaintext, String userId) async {
  final cipher = AesGcm.with256bits();
  
  // Derive key from userId (matches backend)
  final key = await _deriveKey(userId);
  final plaintextBytes = utf8.encode(plaintext);
  
  // Generate random nonce
  final nonce = _generateRandomBytes(12);
  
  // Encrypt
  final secretBox = await cipher.encrypt(
    plaintextBytes,
    secretKey: key,
    nonce: nonce,
  );
  
  // Return format: base64(nonce)::base64(ciphertext)::base64(mac)
  final nonceBase64 = base64Encode(nonce);
  final ctBase64 = base64Encode(secretBox.cipherText);
  final macBase64 = base64Encode(secretBox.mac.bytes);
  
  return '$nonceBase64::$ctBase64::$macBase64';
}

// Frontend decryption helper
Future<String> _decryptMessage(String encrypted, String userId) async {
  final cipher = AesGcm.with256bits();
  
  // Parse format: base64(nonce)::base64(ciphertext)::base64(mac)
  final parts = encrypted.split('::');
  if (parts.length != 3) {
    throw FormatException('Invalid format: expected 3 parts, got ${parts.length}');
  }
  
  final nonce = base64Decode(parts[0]);
  final ciphertext = base64Decode(parts[1]);
  final mac = Mac(base64Decode(parts[2]));
  
  // Derive key (matches backend)
  final key = await _deriveKey(userId);
  
  // Decrypt
  final decryptedBytes = await cipher.decrypt(
    SecretBox(ciphertext, nonce: nonce, mac: mac),
    secretKey: key,
  );
  
  return utf8.decode(decryptedBytes);
}

// Derive key using HMAC (matches both frontend and backend)
Future<SecretKey> _deriveKey(String userId) async {
  const masterKey = 'default-insecure-key-development-only'; // Must match backend env
  
  final hmac = Hmac(Sha256());
  final masterKeyBytes = utf8.encode(masterKey);
  final userIdBytes = utf8.encode(userId);
  
  final mac = await hmac.calculateMac(
    userIdBytes,
    secretKey: SecretKey(masterKeyBytes),
  );
  
  return SecretKey(mac.bytes);
}

List<int> _generateRandomBytes(int length) {
  final random = <int>[];
  for (int i = 0; i < length; i++) {
    final ms = DateTime.now().microsecond;
    random.add((ms >> 8) ^ (ms & 0xFF) ^ i);
  }
  return random;
}
