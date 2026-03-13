import 'package:test/test.dart';
import 'dart:convert';
import 'package:postgres/postgres.dart';
import '../../lib/src/endpoints/auth.dart';
import '../../lib/src/services/user_auth_service.dart';
import 'package:shelf/shelf.dart';

void main() {
  late Connection connection;
  late UserAuthService authService;
  late AuthEndpoint authEndpoint;

  setUpAll(() async {
    // Connect to test database
    connection = await Connection.open(
      Endpoint(
        host: 'postgres',
        port: 5432,
        database: 'messenger_db',
        username: 'messenger_user',
        password: 'messenger_password',
      ),
    );
  });

  tearDownAll(() async {
    // Clean up test data
    try {
      // Delete test users
      await connection.execute(
        "DELETE FROM users WHERE email LIKE '%test%' OR username LIKE '%testuser%' OR username LIKE '%duplicate%'",
      );
    } catch (e) {
      print('[WARN] Cleanup error: $e');
    }
    await connection.close();
  });

  setUp(() async {
    authService = UserAuthService(connection: connection);
    authEndpoint = AuthEndpoint(authService: authService);
  });

  group('Registration Endpoint Tests', () {
    test('T1: Valid registration creates user and returns 201 with user data', () async {
      final request = _createJsonRequest(
        method: 'POST',
        body: {
          'email': 'newuser${DateTime.now().millisecondsSinceEpoch}@test.com',
          'username': 'testuser_${DateTime.now().millisecondsSinceEpoch}',
          'password': 'ValidPassword123!',
          'full_name': 'Test User',
        },
      );

      final response = await authEndpoint.register(request);

      expect(response.statusCode, 201);
      final body = jsonDecode(await response.readAsString());
      expect(body['user_id'], isNotNull);
      expect(body['email'], isNotNull);
      expect(body['username'], isNotNull);
      expect(body['message'], 'Account created successfully');
    });

    test('T2: Duplicate email returns 409 with "Email already registered"', () async {
      final email = 'duplicate${DateTime.now().millisecondsSinceEpoch}@test.com';

      // Register first user
      await authEndpoint.register(_createJsonRequest(
        method: 'POST',
        body: {
          'email': email,
          'username': 'unique_user1_${DateTime.now().millisecondsSinceEpoch}',
          'password': 'ValidPassword123!',
        },
      ));

      // Try to register with same email
      final request = _createJsonRequest(
        method: 'POST',
        body: {
          'email': email,
          'username': 'unique_user2_${DateTime.now().millisecondsSinceEpoch}',
          'password': 'ValidPassword123!',
        },
      );

      final response = await authEndpoint.register(request);

      expect(response.statusCode, 409);
      final body = jsonDecode(await response.readAsString());
      expect(body['error'], 'Email already registered');
    });

    test('T3: Duplicate username returns 409 with "Username already taken"', () async {
      final username = 'duplicate_user_${DateTime.now().millisecondsSinceEpoch}';

      // Register first user
      await authEndpoint.register(_createJsonRequest(
        method: 'POST',
        body: {
          'email': 'user1_${DateTime.now().millisecondsSinceEpoch}@test.com',
          'username': username,
          'password': 'ValidPassword123!',
        },
      ));

      // Try to register with same username
      final request = _createJsonRequest(
        method: 'POST',
        body: {
          'email': 'user2_${DateTime.now().millisecondsSinceEpoch}@test.com',
          'username': username,
          'password': 'ValidPassword123!',
        },
      );

      final response = await authEndpoint.register(request);

      expect(response.statusCode, 409);
      final body = jsonDecode(await response.readAsString());
      expect(body['error'], 'Username already taken');
    });

    test('T4: Weak password (no uppercase) returns 400 with validation error', () async {
      final request = _createJsonRequest(
        method: 'POST',
        body: {
          'email': 'test_${DateTime.now().millisecondsSinceEpoch}@test.com',
          'username': 'testuser_${DateTime.now().millisecondsSinceEpoch}',
          'password': 'weakpassword123!', // No uppercase
        },
      );

      final response = await authEndpoint.register(request);

      expect(response.statusCode, 400);
      final body = jsonDecode(await response.readAsString());
      expect(body['error'], 'Password validation failed');
      expect(body['details'], isNotEmpty);
    });

    test('T5: Weak password (< 8 chars) returns 400 with validation error', () async {
      final request = _createJsonRequest(
        method: 'POST',
        body: {
          'email': 'test_${DateTime.now().millisecondsSinceEpoch}@test.com',
          'username': 'testuser_${DateTime.now().millisecondsSinceEpoch}',
          'password': 'Pass1!', // Only 6 chars
        },
      );

      final response = await authEndpoint.register(request);

      expect(response.statusCode, 400);
      final body = jsonDecode(await response.readAsString());
      expect(body['error'], 'Password validation failed');
      expect(body['details'], isNotEmpty);
    });

    test('T6: Missing required field returns 400 with validation error', () async {
      final request = _createJsonRequest(
        method: 'POST',
        body: {
          'email': 'test_${DateTime.now().millisecondsSinceEpoch}@test.com',
          // Missing username
          'password': 'ValidPassword123!',
        },
      );

      final response = await authEndpoint.register(request);

      expect(response.statusCode, 400);
      final body = jsonDecode(await response.readAsString());
      expect(body['error'], isNotNull);
    });

    test('T7: Very long email or username is rejected', () async {
      final longEmail = '${'a' * 255}@test.com'; // 265 chars

      final request = _createJsonRequest(
        method: 'POST',
        body: {
          'email': longEmail,
          'username': 'testuser_${DateTime.now().millisecondsSinceEpoch}',
          'password': 'ValidPassword123!',
        },
      );

      final response = await authEndpoint.register(request);

      // Should be either 400 (validation) or other error code
      expect(response.statusCode, isIn([400, 500]));
    });

    test('T8: Invalid email format returns 400', () async {
      final request = _createJsonRequest(
        method: 'POST',
        body: {
          'email': 'not-a-valid-email',
          'username': 'testuser_${DateTime.now().millisecondsSinceEpoch}',
          'password': 'ValidPassword123!',
        },
      );

      final response = await authEndpoint.register(request);

      expect(response.statusCode, 400);
      final body = jsonDecode(await response.readAsString());
      expect(body['error'], isNotNull);
    });
  });
}

/// Helper to create a JSON request
Request _createJsonRequest({
  required String method,
  required Map<String, dynamic> body,
}) {
  return Request(
    method,
    Uri.parse('http://localhost/auth/register'),
    body: jsonEncode(body),
    headers: {'Content-Type': 'application/json'},
  );
}
