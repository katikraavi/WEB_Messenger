import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';

/// User endpoints handler for registration and profile management
class UserEndpoints {
  static final _uuid = const Uuid();
  static final _users = <String, User>{}; // In-memory storage (demo)

  /// Route configuration
  static Router get router {
    final router = Router();
    router.post('/api/users/register', _register);
    router.post('/api/users/login', _login);
    router.get('/api/users/<userId>', _getProfile);
    router.put('/api/users/<userId>', _updateProfile);
    return router;
  }

  /// Register a new user
  static Future<Response> _register(Request request) async {
    try {
      final json = await request.readAsString();
      final body = json.isEmpty ? {} : _parseJson(json);

      final email = body['email'] as String?;
      final username = body['username'] as String?;
      final password = body['password'] as String?;

      if (email == null || username == null || password == null) {
        return Response.badRequest(
          body: '{"error": "Missing required fields: email, username, password"}',
        );
      }

      if (!UserService.isValidEmail(email)) {
        return Response.badRequest(
          body: '{"error": "Invalid email format"}',
        );
      }

      if (!UserService.isValidUsername(username)) {
        return Response.badRequest(
          body: '{"error": "Username must be 3-20 alphanumeric characters"}',
        );
      }

      if (!UserService.isStrongPassword(password)) {
        return Response.badRequest(
          body: '{"error": "Password must have 8+ chars, uppercase, and numbers"}',
        );
      }

      // Check if user exists
      if (_users.values.any((u) => u.email == email || u.username == username)) {
        return Response(409, body: '{"error": "User already exists"}');
      }

      final userId = _uuid.v4();
      final user = UserService.createUser(
        id: userId,
        email: email,
        username: username,
        plainPassword: password,
      );

      _users[userId] = user;

      return Response.ok(
        _toJson(user),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: '{"error": "Registration failed: $e"}',
      );
    }
  }

  /// Login user and return user data
  static Future<Response> _login(Request request) async {
    try {
      final json = await request.readAsString();
      final body = json.isEmpty ? {} : _parseJson(json);

      final email = body['email'] as String?;
      final password = body['password'] as String?;

      if (email == null || password == null) {
        return Response.badRequest(
          body: '{"error": "Missing email or password"}',
        );
      }

      final user = _users.values.firstWhere(
        (u) => u.email == email,
        orElse: () => throw Exception('User not found'),
      );

      if (!UserService.verifyPassword(password, user.passwordHash)) {
        return Response(401, body: '{"error": "Invalid credentials"}');
      }

      return Response.ok(
        _toJson(user),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response(401, body: '{"error": "Login failed"}');
    }
  }

  /// Get user profile
  static Future<Response> _getProfile(Request request, String userId) async {
    try {
      final user = _users[userId];
      if (user == null) {
        return Response.notFound('{"error": "User not found"}');
      }

      return Response.ok(
        _toJson(user),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError();
    }
  }

  /// Update user profile
  static Future<Response> _updateProfile(Request request, String userId) async {
    try {
      final user = _users[userId];
      if (user == null) {
        return Response.notFound('{"error": "User not found"}');
      }

      final json = await request.readAsString();
      final body = json.isEmpty ? {} : _parseJson(json);

      final updated = UserService.updateProfile(
        user: user,
        email: body['email'] as String?,
        profilePictureUrl: body['profile_picture_url'] as String?,
        aboutMe: body['about_me'] as String?,
      );

      _users[userId] = updated;

      return Response.ok(
        _toJson(updated),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError();
    }
  }

  /// Utility to parse JSON string
  static Map<String, dynamic> _parseJson(String json) {
    try {
      return Map<String, dynamic>.from(Uri.splitQueryString(json));
    } catch (_) {
      return {};
    }
  }

  /// Serialize user to JSON
  static String _toJson(User user) {
    final json = user.toJson();
    json.remove('password_hash'); // Don't expose password hash
    return _encodeJson(json);
  }

  /// Utility to encode JSON
  static String _encodeJson(Map<String, dynamic> json) {
    final buffer = StringBuffer();
    buffer.write('{');
    final entries = json.entries.toList();
    for (int i = 0; i < entries.length; i++) {
      final entry = entries[i];
      buffer.write('"${entry.key}":');
      final value = entry.value;
      if (value is String) {
        buffer.write('"${value.replaceAll('"', '\\"')}"');
      } else if (value is DateTime) {
        buffer.write('"${value.toIso8601String()}"');
      } else {
        buffer.write(value);
      }
      if (i < entries.length - 1) buffer.write(',');
    }
    buffer.write('}');
    return buffer.toString();
  }
}
