import 'package:test/test.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  group('Registration API', () {
    test('registers new user successfully', () async {
      final email = 'testuser1@example.com';
      final username = 'testuser1';
      final password = 'Test123!';
      final response = await http.post(
        Uri.parse('http://localhost:8081/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'username': username,
          'password': password,
        }),
      );
      expect(response.statusCode, anyOf([201, 409]));
      if (response.statusCode == 201) {
        final body = jsonDecode(response.body);
        expect(body['email'], email);
        expect(body['username'], username);
        expect(body['user_id'], isNotEmpty);
      } else if (response.statusCode == 409) {
        final body = jsonDecode(response.body);
        expect(body['error'], anyOf(['Email already registered', 'Username already taken']));
      }
    });

    test('fails for duplicate email', () async {
      final email = 'testuser1@example.com';
      final username = 'anotheruser';
      final password = 'Test123!';
      final response = await http.post(
        Uri.parse('http://localhost:8081/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'username': username,
          'password': password,
        }),
      );
      expect(response.statusCode, 409);
      final body = jsonDecode(response.body);
      expect(body['error'], 'Email already registered');
    });

    test('fails for duplicate username', () async {
      final email = 'anotheruser@example.com';
      final username = 'testuser1';
      final password = 'Test123!';
      final response = await http.post(
        Uri.parse('http://localhost:8081/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'username': username,
          'password': password,
        }),
      );
      expect(response.statusCode, 409);
      final body = jsonDecode(response.body);
      expect(body['error'], 'Username already taken');
    });

    test('fails for missing fields', () async {
      final response = await http.post(
        Uri.parse('http://localhost:8081/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({}),
      );
      expect(response.statusCode, 400);
      final body = jsonDecode(response.body);
      expect(body['error'], 'Validation failed');
    });
  });
}
