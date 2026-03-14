import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';
import 'package:postgres/postgres.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';

// Alias for cleaner code
typedef Connection = PostgreSQLConnection;

/// User endpoints handler for registration and profile management
class UserEndpoints {
  static final _uuid = const Uuid();
  static late Connection _db;
  
  /// Initialize database connection for user endpoints
  static void initializeDatabase(Connection database) {
    _db = database;
  }

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

      // Check if user already exists
      final existing = await _db.query(
        'SELECT id FROM "users" WHERE email = @email OR username = @username',
        substitutionValues: {'email': email, 'username': username},
      );
      if (existing.isNotEmpty) {
        return Response(409, body: '{"error": "User already exists"}');
      }

      final userId = _uuid.v4();
      final user = UserService.createUser(
        id: userId,
        email: email,
        username: username,
        plainPassword: password,
      );

      // Insert user into database
      await _db.execute(
        '''INSERT INTO "users" (id, email, username, password_hash, email_verified, created_at)
           VALUES (@id, @email, @username, @password_hash, @email_verified, @created_at)''',
        substitutionValues: {
          'id': userId,
          'email': email,
          'username': username,
          'password_hash': user.passwordHash,
          'email_verified': false,
          'created_at': DateTime.now(),
        },
      );

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

      // Query user from database by email
      final result = await _db.query(
        'SELECT id, email, username, password_hash, email_verified FROM "users" WHERE email = @email',
        substitutionValues: {'email': email},
      );
      
      if (result.isEmpty) {
        return Response(401, body: '{"error": "Invalid credentials"}');
      }
      
      final row = result.first.toColumnMap();
      final userId = row['id'] as String;
      final username = row['username'] as String;
      final passwordHash = row['password_hash'] as String;
      final emailVerified = row['email_verified'] as bool;
      
      // Verify password
      if (!UserService.verifyPassword(password, passwordHash)) {
        return Response(401, body: '{"error": "Invalid credentials"}');
      }

      // Create user object for response
      final user = User(
        id: userId,
        email: email,
        username: username,
        passwordHash: passwordHash,
        emailVerified: emailVerified,
        createdAt: DateTime.now(),
      );

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
      // Query user from database
      final result = await _db.query(
        '''SELECT id, email, username, profile_picture_url, about_me, created_at
           FROM "users" WHERE id = @id''',
        substitutionValues: {'id': userId},
      );
      
      if (result.isEmpty) {
        return Response(404, body: '{"error": "User not found"}');
      }
      
      final row = result.first.toColumnMap();
      final user = User.fromDatabase(row);
      
      return Response.ok(
        _toJson(user),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: '{"error": "Failed to fetch profile: $e"}',
      );
    }
  }

  /// Update user profile
  static Future<Response> _updateProfile(Request request, String userId) async {
    try {
      final json = await request.readAsString();
      final body = json.isEmpty ? {} : _parseJson(json);

      final email = body['email'] as String?;
      final profilePictureUrl = body['profilePictureUrl'] as String?;
      final aboutMe = body['aboutMe'] as String?;

      // Update user in database
      await _db.execute(
        '''UPDATE "user" 
           SET email = COALESCE(@email, email),
               profile_picture_url = COALESCE(@picture_url, profile_picture_url),
               about_me = COALESCE(@about_me, about_me)
           WHERE id = @id''',
        substitutionValues: {
          'email': email,
          'picture_url': profilePictureUrl,
          'about_me': aboutMe,
          'id': userId,
        },
      );

      // Fetch updated user
      final result = await _db.query(
        '''SELECT id, email, username, profile_picture_url, about_me, created_at
           FROM "users" WHERE id = @id''',
        substitutionValues: {'id': userId},
      );

      if (result.isEmpty) {
        return Response(404, body: '{"error": "User not found"}');
      }

      final row = result.first.toColumnMap();
      final user = User.fromDatabase(row);

      return Response.ok(
        _toJson(user),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: '{"error": "Failed to update profile: $e"}',
      );
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
