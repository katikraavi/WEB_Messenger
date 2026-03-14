import 'package:postgres/postgres.dart';
import 'package:uuid/uuid.dart';
import 'auth_exception.dart';
import 'password_validator.dart';
import 'password_hasher.dart';
import 'jwt_service.dart';
import '../models/auth_result.dart';

// Alias for cleaner code
typedef Connection = PostgreSQLConnection;

/// Handles user authentication operations (registration and login)
/// Provides registration, login, and user lookup functionality
class UserAuthService {
  /// Database connection for user operations
  late Connection _connection;

  /// Whether this instance owns the connection (created it)
  final bool _ownsConnection;

  /// Creates [UserAuthService] with optional database connection
  /// If no connection provided, will create one (closing responsibility on caller)
  /// If connection provided, caller is responsible for closing it
  UserAuthService({Connection? connection})
      : _ownsConnection = connection == null {
    if (connection != null) {
      _connection = connection;
    }
  }

  /// Initializes database connection
  /// Must be called before any service methods
  /// Only needed if UserAuthService was created without passing a connection
  Future<void> initialize() async {
    if (_ownsConnection) {
      _connection = await Connection.open(
        Endpoint(
          host: 'localhost',
          port: 5432,
          database: 'messenger_db',
          username: 'messenger_user',
          password: 'messenger_password',
        ),
      );
    }
  }

  /// Closes database connection only if this instance created it
  Future<void> close() async {
    if (_ownsConnection) {
      await _connection.close();
    }
  }

  /// Validates email format using basic regex
  /// Returns true if email looks valid
  static bool _isValidEmailFormat(String email) {
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return emailRegex.hasMatch(email);
  }

  /// Registers a new user with email, username, and validated password
  ///
  /// Parameters:
  /// - [email]: User's email (must be unique and valid format)
  /// - [username]: User's chosen username (must be unique)
  /// - [password]: Password (must meet strength requirements)
  /// - [fullName]: User's full name (optional)
  ///
  /// Returns [AuthResult] with user info (no token for registration)
  ///
  /// Throws [AuthException] if:
  /// - Email format is invalid
  /// - Email already registered
  /// - Username already taken
  /// - Password doesn't meet strength requirements
  /// - Database error occurs
  Future<AuthResult> registerUser(
    String email,
    String username,
    String password, {
    String? fullName,
  }) async {
    try {
      // Validate email format
      if (!_isValidEmailFormat(email)) {
        throw AuthException(
          'Invalid email format',
          code: 'invalid_email_format',
        );
      }

      // Validate password strength
      final passwordValidation = PasswordValidator.validate(password);
      if (!passwordValidation.isValid) {
        throw AuthException(
          'Password validation failed: ${passwordValidation.errors.join(", ")}',
          code: 'weak_password',
        );
      }

      // Check if email already exists
      final emailExists = await _connection.query(
        'SELECT id FROM "users" WHERE LOWER(email) = LOWER(@email)',
        substitutionValues: {'email': email},
      );

      if (emailExists.isNotEmpty) {
        throw AuthException(
          'Email already registered',
          code: 'user_exists',
        );
      }

      // Check if username already exists
      final usernameExists = await _connection.query(
        'SELECT id FROM "users" WHERE LOWER(username) = LOWER(@username)',
        substitutionValues: {'username': username},
      );

      if (usernameExists.isNotEmpty) {
        throw AuthException(
          'Username already taken',
          code: 'user_exists',
        );
      }

      // Hash password
      final passwordHash = PasswordHasher.hashPassword(password);

      // Create new user
      final userId = const Uuid().v4();
      final now = DateTime.now();

      final result = await _connection.query(
        '''
        INSERT INTO "users" (id, email, username, password_hash, created_at)
        VALUES (@id, @email, @username, @password_hash, @created_at)
        RETURNING id, email, username
        ''',
        substitutionValues: {
          'id': userId,
          'email': email,
          'username': username,
          'password_hash': passwordHash,
          'created_at': now,
        },
      );

      if (result.isEmpty) {
        throw AuthException(
          'Failed to create user',
          code: 'server_error',
        );
      }

      // Log registration attempt (for security auditing)
      print('[AUTH] User registration: username=$username');

      return AuthResult(
        userId: userId,
        email: email,
        username: username,
      );
    } on AuthException {
      rethrow;
    } catch (e) {
      print('[ERROR] Registration failed: $e');
      throw AuthException(
        'Registration failed. Please try again.',
        code: 'server_error',
      );
    }
  }

  /// Authenticates user with email and password
  ///
  /// Parameters:
  /// - [email]: User's email address
  /// - [password]: User's password
  ///
  /// Returns [AuthResult] with user info and JWT token
  ///
  /// Throws [AuthException] if:
  /// - User not found
  /// - Password incorrect
  /// - Database error occurs
  Future<AuthResult> authenticateUser(String email, String password) async {
    try {
      // Look up user by email
      final result = await _connection.query(
        'SELECT id, email, username, password_hash, email_verified FROM "users" WHERE LOWER(email) = LOWER(@email)',
        substitutionValues: {'email': email},
      );

      if (result.isEmpty) {
        // Don't reveal whether email exists (security best practice)
        throw AuthException(
          'Invalid email or password',
          code: 'invalid_credentials',
        );
      }

      final userRow = result.first;
      final userId = userRow[0] as String;
      final userEmail = userRow[1] as String;
      final username = userRow[2] as String;
      final storedHash = userRow[3] as String;

      // Verify password
      final isPasswordValid = PasswordHasher.verifyPassword(password, storedHash);
      if (!isPasswordValid) {
        throw AuthException(
          'Invalid email or password',
          code: 'invalid_credentials',
        );
      }

      // Update last login timestamp
      try {
        await _connection.execute(
          'UPDATE "users" SET last_login_at = @now WHERE id = @id',
          substitutionValues: {'now': DateTime.now(), 'id': userId},
        );
      } catch (e) {
        // Non-critical: don't fail login if last_login_at update fails
        print('[WARN] Failed to update last_login_at: $e');
      }

      // Generate JWT token
      final token = JwtService.generateToken(userId, userEmail);

      // Log login attempt (for security auditing)
      print('[AUTH] User login: email=$email');

      return AuthResult(
        userId: userId,
        email: userEmail,
        username: username,
        token: token,
      );
    } on AuthException {
      rethrow;
    } catch (e) {
      print('[ERROR] Authentication failed: $e');
      throw AuthException(
        'Authentication failed. Please try again.',
        code: 'server_error',
      );
    }
  }

  /// Looks up user by ID
  /// Returns user info without token (non-authentication context)
  Future<AuthResult?> getUserById(String userId) async {
    try {
      final result = await _connection.query(
        'SELECT id, email, username FROM "users" WHERE id = @id',
        substitutionValues: {'id': userId},
      );

      if (result.isEmpty) {
        return null;
      }

      final row = result.first;
      return AuthResult(
        userId: row[0] as String,
        email: row[1] as String,
        username: row[2] as String,
      );
    } catch (e) {
      print('[ERROR] Failed to get user by ID: $e');
      return null;
    }
  }

  /// Verifies if a JWT token's user exists in the database
  /// Used by JWT middleware to validate token claims
  Future<bool> userExists(String userId) async {
    try {
      final result = await _connection.query(
        'SELECT 1 FROM "users" WHERE id = @id',
        substitutionValues: {'id': userId},
      );
      return result.isNotEmpty;
    } catch (e) {
      print('[ERROR] Failed to check user existence: $e');
      return false;
    }
  }
}
