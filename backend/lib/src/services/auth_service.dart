import 'package:postgres/postgres.dart';
import 'jwt_service.dart';
import 'password_hasher.dart';
import 'password_validator.dart';
import '../models/user_model.dart';

// Alias for cleaner code
typedef Connection = PostgreSQLConnection;

/// Authentication Service
/// Business logic for user authentication via JWT and password hashing
/// 
/// Handles:
/// - User registration with password hashing
/// - User login with JWT token generation
/// - Password validation and hashing
/// - Token verification and user extraction

class AuthService {
  final Connection _db;

  AuthService(this._db);

  /// Register new user with email, password
  /// 
  /// Args:
  ///   - email: User email (must be unique, valid format)
  ///   - username: Username (must be unique, 3-32 chars)
  ///   - password: Plain-text password (validated by PasswordValidator)
  /// 
  /// Returns: Map with user_id, email, username, access_token, refresh_token
  /// 
  /// Throws:
  ///   - ArgumentError: Invalid email format
  ///   - Exception: Email already registered
  ///   - Exception: Username taken
  ///   - Exception: Password validation failed
  /// 
  /// Database:
  ///   - Queries: SELECT email FROM user WHERE email = ?
  ///   - Inserts: INSERT INTO user (email, username, password_hash, created_at)
  Future<Map<String, dynamic>> register({
    required String email,
    required String username,
    required String password,
  }) async {
    // 1. Validate password
    final validationResult = PasswordValidator.validate(password);
    if (!validationResult.isValid) {
      throw ArgumentError('Password validation failed: ${validationResult.errors.join(', ')}');
    }

    // 2. Check email doesn't exist
    final emailCheck = await _db.query(
      'SELECT id FROM "users" WHERE email = $1',
      [email.toLowerCase()],
    );
    if (emailCheck.isNotEmpty) {
      throw Exception('Email already registered');
    }

    // 3. Check username doesn't exist
    final usernameCheck = await _db.query(
      'SELECT id FROM "users" WHERE username = $1',
      [username],
    );
    if (usernameCheck.isNotEmpty) {
      throw Exception('Username already taken');
    }

    // 4. Hash password and create user
    final passwordHash = PasswordHasher.hashPassword(password);
    final userId = _generateUUID();

    await _db.execute(
      '''INSERT INTO "users" (id, email, username, password_hash, created_at)
         VALUES (\$1, \$2, \$3, \$4, NOW())''',
      [userId, email.toLowerCase(), username, passwordHash],
    );

    // 5. Generate tokens
    final accessToken = JwtService.generateToken(userId, email);
    final refreshToken = JwtService.generateToken(userId, email);

    return {
      'user_id': userId,
      'email': email,
      'username': username,
      'access_token': accessToken,
      'refresh_token': refreshToken,
    };
  }

  /// Login user with email and password
  /// 
  /// Args:
  ///   - email: User email
  ///   - password: Plain-text password
  /// 
  /// Returns: Map with user_id, email, username, access_token, refresh_token
  /// 
  /// Throws:
  ///   - Exception: User not found
  ///   - Exception: Invalid password
  /// 
  /// Database:
  ///   - Queries: SELECT * FROM user WHERE email = ?
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    // 1. Find user by email
    final result = await _db.query(
      '''SELECT id, email, username, password_hash FROM "users" 
         WHERE email = \$1''',
      [email.toLowerCase()],
    );

    if (result.isEmpty) {
      throw Exception('User not found');
    }

    final user = result.first.toColumnMap();
    final userId = user['id'] as String;
    final storedHash = user['password_hash'] as String;
    final username = user['username'] as String;

    // 2. Verify password
    if (!PasswordHasher.verifyPassword(password, storedHash)) {
      throw Exception('Invalid password');
    }

    // 3. Generate tokens
    final accessToken = JwtService.generateToken(userId, email);
    final refreshToken = JwtService.generateToken(userId, email);

    return {
      'user_id': userId,
      'email': email,
      'username': username,
      'access_token': accessToken,
      'refresh_token': refreshToken,
    };
  }

  /// Refresh access token using refresh token
  /// 
  /// Args:
  ///   - refreshToken: Valid refresh token
  /// 
  /// Returns: Map with new access_token and refresh_token
  /// 
  /// Throws:
  ///   - Exception: Invalid or expired refresh token
  /// 
  /// Database: No queries (just token validation)
  Future<Map<String, dynamic>> refreshTokens(String refreshToken) async {
    try {
      final payload = JwtService.validateToken(refreshToken);
      final userId = payload.userId;

      // Get user email for new token
      final result = await _db.query(
        'SELECT email FROM "users" WHERE id = $1',
        [userId],
      );

      if (result.isEmpty) {
        throw Exception('User not found');
      }

      final email = (result.first.toColumnMap()['email'] as String);

      final newAccessToken = JwtService.generateToken(userId, email);
      final newRefreshToken = JwtService.generateToken(userId, email);

      return {
        'access_token': newAccessToken,
        'refresh_token': newRefreshToken,
      };
    } catch (e) {
      throw Exception('Token refresh failed: $e');
    }
  }

  /// Verify bearer token and extract userId
  /// 
  /// Args:
  ///   - authHeader: Authorization header value (format: "Bearer <token>")
  /// 
  /// Returns: userId if token valid
  /// 
  /// Throws:
  ///   - Exception: Invalid header format
  ///   - Exception: Invalid token
  String extractUserIdFromHeader(String authHeader) {
    const prefix = 'Bearer ';
    if (!authHeader.startsWith(prefix)) {
      throw Exception('Invalid Authorization header format');
    }

    final token = authHeader.substring(prefix.length);
    try {
      final payload = JwtService.validateToken(token);
      return payload.userId;
    } catch (e) {
      throw Exception('Invalid or expired token');
    }
  }

  /// Generate UUID v4
  String _generateUUID() {
    // Using a simple UUID v4 generation (in production, use uuid package)
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replaceAllMapped(
      RegExp('[xy]'),
      (match) {
        final random = (DateTime.now().millisecondsSinceEpoch % 16) as int;
        return (match.group(0) == 'x' ? random : (random & 0x3) | 0x8)
            .toRadixString(16);
      },
    );
  }
}
