import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Integration tests for User Registration and Login
/// 
/// Tests both user stories:
/// - US1: New User Registration - Registration, validation, duplicate checks
/// - US2: Existing User Login - Login, session tokens, persistence
void main() {
  const String baseUrl = 'http://localhost:8081';

  group('User Registration and Login E2E Tests', () {
    // Test data
    final testUser1 = {
      'email': 'testuser${DateTime.now().millisecondsSinceEpoch}@test.com',
      'username': 'testuser${DateTime.now().millisecondsSinceEpoch}',
      'password': 'TestPassword123!',
      'full_name': 'Test User',
    };

    final testUser2 = {
      'email': 'anotheruser${DateTime.now().millisecondsSinceEpoch}@test.com',
      'username': 'anotheruser${DateTime.now().millisecondsSinceEpoch}',
      'password': 'AnotherPassword456!',
      'full_name': 'Another User',
    };

    group('User Story 1 - New User Registration', () {
      test('T011.1: Valid registration creates user and returns 201', () async {
        final response = await http.post(
          Uri.parse('$baseUrl/auth/register'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(testUser1),
        );

        expect(response.statusCode, equals(201));
        final data = jsonDecode(response.body);
        expect(data['user_id'], isNotNull);
        expect(data['email'], equals(testUser1['email']));
        expect(data['username'], equals(testUser1['username']));
        expect(data['message'], equals('Account created successfully'));
      });

      test('T011.2: Duplicate email returns 409', () async {
        // First registration
        await http.post(
          Uri.parse('$baseUrl/auth/register'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(testUser1),
        );

        // Try to register with same email
        final duplicateEmailUser = {
          ...testUser1,
          'username': 'differentusername${DateTime.now().millisecondsSinceEpoch}',
        };

        final response = await http.post(
          Uri.parse('$baseUrl/auth/register'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(duplicateEmailUser),
        );

        expect(response.statusCode, equals(409));
        final data = jsonDecode(response.body);
        expect(data['error'], equals('Email already registered'));
      });

      test('T011.3: Duplicate username returns 409', () async {
        // First registration
        await http.post(
          Uri.parse('$baseUrl/auth/register'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(testUser2),
        );

        // Try to register with same username
        final duplicateUsernameUser = {
          ...testUser2,
          'email': 'newemail${DateTime.now().millisecondsSinceEpoch}@test.com',
        };

        final response = await http.post(
          Uri.parse('$baseUrl/auth/register'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(duplicateUsernameUser),
        );

        expect(response.statusCode, equals(409));
        final data = jsonDecode(response.body);
        expect(data['error'], equals('Username already taken'));
      });

      test('T011.4: Weak password (no uppercase) returns 400', () async {
        final weakPasswordUser = {
          ...testUser1,
          'password': 'weakpassword123!',
        };

        final response = await http.post(
          Uri.parse('$baseUrl/auth/register'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(weakPasswordUser),
        );

        expect(response.statusCode, equals(400));
        final data = jsonDecode(response.body);
        expect(data['error'], contains('Password'));
        expect(data['details'], isNotNull);
        expect((data['details'] as List).isNotEmpty, isTrue);
      });

      test('T011.5: Weak password (< 8 chars) returns 400', () async {
        final weakPasswordUser = {
          ...testUser1,
          'password': 'Pass1!',
        };

        final response = await http.post(
          Uri.parse('$baseUrl/auth/register'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(weakPasswordUser),
        );

        expect(response.statusCode, equals(400));
        final data = jsonDecode(response.body);
        expect(data['error'], contains('Password'));
      });

      test('T011.6: Missing required field returns 400', () async {
        final incompleteUser = {
          'email': 'incomplete@test.com',
          // Missing username and password
        };

        final response = await http.post(
          Uri.parse('$baseUrl/auth/register'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(incompleteUser),
        );

        expect(response.statusCode, equals(400));
        final data = jsonDecode(response.body);
        expect(data['error'], isNotNull);
      });
    });

    group('User Story 2 - Existing User Login', () {
      late String userId;
      late String loginToken;

      setUpAll(() async {
        // Register a test user first
        final registerResponse = await http.post(
          Uri.parse('$baseUrl/auth/register'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(testUser1),
        );

        if (registerResponse.statusCode == 201) {
          final data = jsonDecode(registerResponse.body);
          userId = data['user_id'];
        }
      });

      test('T022.1: Valid login returns 200 with token', () async {
        final loginRequest = {
          'email': testUser1['email'],
          'password': testUser1['password'],
        };

        final response = await http.post(
          Uri.parse('$baseUrl/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(loginRequest),
        );

        expect(response.statusCode, equals(200));
        final data = jsonDecode(response.body);
        expect(data['user_id'], equals(userId));
        expect(data['email'], equals(testUser1['email']));
        expect(data['token'], isNotNull);
        loginToken = data['token'];
      });

      test('T022.2: Invalid password returns 401', () async {
        final invalidLogin = {
          'email': testUser1['email'],
          'password': 'WrongPassword123!',
        };

        final response = await http.post(
          Uri.parse('$baseUrl/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(invalidLogin),
        );

        expect(response.statusCode, equals(401));
        final data = jsonDecode(response.body);
        expect(data['error'], equals('Invalid email or password'));
      });

      test('T022.3: Non-existent email returns 401', () async {
        final invalidLogin = {
          'email': 'nonexistent@test.com',
          'password': 'SomePassword123!',
        };

        final response = await http.post(
          Uri.parse('$baseUrl/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(invalidLogin),
        );

        expect(response.statusCode, equals(401));
      });

      test('T022.4: Missing email returns 400', () async {
        final incompleteLogin = {
          'password': 'SomePassword123!',
        };

        final response = await http.post(
          Uri.parse('$baseUrl/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(incompleteLogin),
        );

        expect(response.statusCode, equals(400));
      });

      test('T022.5: JWT token can be validated by protected endpoint', () async {
        // Get a valid token
        final loginRequest = {
          'email': testUser1['email'],
          'password': testUser1['password'],
        };

        final loginResponse = await http.post(
          Uri.parse('$baseUrl/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(loginRequest),
        );

        final loginData = jsonDecode(loginResponse.body);
        final token = loginData['token'];

        // Use token on protected endpoint
        final protectedResponse = await http.get(
          Uri.parse('$baseUrl/auth/me'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );

        expect(protectedResponse.statusCode, equals(200));
        final data = jsonDecode(protectedResponse.body);
        expect(data['is_authenticated'], isTrue);
        expect(data['user_id'], equals(userId));
      });

      test('T022.6: Invalid token returns 401', () async {
        final protectedResponse = await http.get(
          Uri.parse('$baseUrl/auth/me'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer invalid_token_xyz',
          },
        );

        expect(protectedResponse.statusCode, equals(401));
      });
    });

    group('Rate Limiting - Brute Force Protection', () {
      test('T032: Multiple failed logins return 429', () async {
        // Try to login 6 times with wrong password (limit is 5 per 60s)
        for (int i = 0; i < 6; i++) {
          final response = await http.post(
            Uri.parse('$baseUrl/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': 'brute@test.com',
              'password': 'WrongPassword!',
            }),
          );

          if (i < 5) {
            // First 5 should return 401
            expect(response.statusCode, equals(401));
          } else {
            // 6th should return 429
            expect(response.statusCode, equals(429));
          }
        }
      });
    });
  });
}
