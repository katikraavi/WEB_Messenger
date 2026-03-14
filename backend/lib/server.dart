import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:postgres/postgres.dart';
import 'src/services/token_service.dart';
import 'src/services/email_service.dart';
import 'src/services/rate_limit_service.dart';
import 'src/services/migration_runner.dart';
import 'src/services/jwt_service.dart';
import 'src/services/auth_exception.dart';
import 'src/endpoints/verification_handler.dart';
import 'src/endpoints/password_reset_handler.dart';
import 'src/endpoints/profile.dart' as profileEndpoint;
import 'src/models/user_search_result.dart';

// Alias for cleaner code
typedef Connection = PostgreSQLConnection;

void main() async {
  final port = int.parse(Platform.environment['SERVERPOD_PORT'] ?? '8081');
  final env = Platform.environment['SERVERPOD_ENV'] ?? 'development';

  print('[INFO] Starting Messenger Server (environment: $env)');

  // Initialize database connection
  print('[INFO] Connecting to PostgreSQL database...');
  late Connection dbConnection;
  try {
    dbConnection = PostgreSQLConnection(
      Platform.environment['DATABASE_HOST'] ?? 'localhost',
      int.parse(Platform.environment['DATABASE_PORT'] ?? '5432'),
      Platform.environment['DATABASE_NAME'] ?? 'messenger_db',
      username: Platform.environment['DATABASE_USER'] ?? 'messenger_user',
      password: Platform.environment['DATABASE_PASSWORD'] ?? 'messenger_password',
    );
    await dbConnection.open();
    print('[✓] Connected to database successfully');
  } catch (e) {
    print('[ERROR] Failed to connect to database: $e');
    rethrow;
  }

  // Run migrations
  print('[INFO] Running database migrations...');
  try {
    final migrationRunner = MigrationRunner(dbConnection);
    await migrationRunner.runMigrations();
    print('[✓] Database migrations completed');
  } catch (e) {
    print('[ERROR] Migration failed: $e');
    rethrow;
  }

  // Initialize services
  final tokenService = TokenService();
  final emailService = EmailService();
  final rateLimitService = RateLimitService(
    maxAttempts: 5,
    windowDuration: Duration(hours: 1),
  );

  print('[INFO] Services initialized');

  // Initialize profile endpoint
  print('[INFO] Initializing profile service...');
  profileEndpoint.initializeProfileService(dbConnection);

  // Setup middleware pipeline
  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(_corsMiddleware())
      .addHandler(_createHandler(
        tokenService,
        emailService,
        rateLimitService,
        dbConnection,
      ));

  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
  
  print('╔═══════════════════════════════════════════════════════╗');
  print('║ 🚀 Messenger Backend Started                          ║');
  print('║ Port: ${server.port}                                         ║');
  print('║ Health: http://localhost:${server.port}/health              ║');
  print('║ Schema: http://localhost:${server.port}/schema              ║');
  print('║                                                       ║');
  print('║ ✓ Services initialized                                ║');
  print('║ ✓ Email verification & password recovery enabled      ║');
  print('║ ✓ Search service ready                                ║');
  print('║ ✓ Database connected & ready                          ║');
  print('╚═══════════════════════════════════════════════════════╝');
}

/// Create the main request handler
Handler _createHandler(
  TokenService tokenService,
  EmailService emailService,
  RateLimitService rateLimitService,
  Connection database,
) {
  return (Request request) async {
    try {
      var path = request.url.path;
      final method = request.method;
      
      // Normalize path - remove leading and trailing slashes
      if (path.startsWith('/')) {
        path = path.substring(1);
      }
      if (path.endsWith('/')) {
        path = path.substring(0, path.length - 1);
      }
      
      // Debug log
      print('[DEBUG] Received request: $method /$path (raw: ${request.url.path})');

      // Health check endpoint (public)
      if (path == 'health' && method == 'GET') {
        return Response.ok(
          jsonEncode({'status': 'healthy', 'timestamp': DateTime.now().toIso8601String()}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // Schema status endpoint (public)
      if (path == 'schema' && method == 'GET') {
        return Response.ok(
          jsonEncode({'status': 'Schema tables created via migrations: users, chats, chat_members, messages, invites, verification_token, password_reset_token, password_reset_attempt'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // Auth endpoints (registration - public)
      if (path == 'auth/register' && method == 'POST') {
        return await _handleRegister(request, database);
      }

      // Auth endpoints (login - public)
      if (path == 'auth/login' && method == 'POST') {
        return await _handleLogin(request, database);
      }

      // Auth endpoints (validate session - protected)
      if (path == 'auth/me' && method == 'GET') {
        return await _handleValidateSession(request, database);
      }

      // Auth endpoints (logout - protected)
      if (path == 'auth/logout' && method == 'POST') {
        return await _handleLogout(request);
      }

      // Email verification endpoints (public)
      if (path == 'auth/verify-email/send' && method == 'POST') {
        return await sendVerificationEmail(
          request,
          tokenService,
          emailService,
          rateLimitService,
          null, // VerificationService - deferred
        );
      }

      if (path == 'auth/verify-email/confirm' && method == 'POST') {
        return await verifyEmailToken(
          request,
          tokenService,
          null, // VerificationService - deferred
        );
      }

      // Password reset endpoints (public)
      if (path == 'auth/password-reset/request' && method == 'POST') {
        return await requestPasswordReset(
          request,
          tokenService,
          emailService,
          rateLimitService,
          null, // PasswordResetService - deferred
        );
      }

      if (path == 'auth/password-reset/confirm' && method == 'POST') {
        return await confirmPasswordReset(
          request,
          tokenService,
          null, // PasswordResetService - deferred
        );
      }

      // Profile endpoints
      if (path.startsWith('profile/view/') && method == 'GET') {
        final userId = path.replaceFirst('profile/view/', '');
        return await profileEndpoint.getProfile(request, userId);
      }

      if (path == 'profile/edit' && method == 'PATCH') {
        return await profileEndpoint.updateProfile(request);
      }

      if (path == 'profile/picture/upload' && method == 'POST') {
        return await profileEndpoint.uploadProfilePicture(request);
      }

      if (path == 'profile/picture' && method == 'DELETE') {
        return await profileEndpoint.deleteProfilePicture(request);
      }

      // Search endpoints (protected - require authentication)
      if (path == 'search/username' && method == 'GET') {
        try {
          return await _handleSearchByUsername(request, database);
        } catch (e) {
          return Response.internalServerError(
            body: jsonEncode({'error': 'Search service error: $e'}),
            headers: {'Content-Type': 'application/json'},
          );
        }
      }

      if (path == 'search/email' && method == 'GET') {
        try {
          return await _handleSearchByEmail(request, database);
        } catch (e) {
          return Response.internalServerError(
            body: jsonEncode({'error': 'Search service error: $e'}),
            headers: {'Content-Type': 'application/json'},
          );
        }
      }

      return Response.notFound(
        jsonEncode({'error': 'Endpoint not found'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, st) {
      print('[ERROR] Request handler error: $e');
      print('[ERROR] Stack: $st');
      return Response.internalServerError(
        body: jsonEncode({'error': 'Internal server error', 'message': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  };
}

/// CORS middleware
Middleware _corsMiddleware() {
  return (Handler innerHandler) {
    return (Request request) async {
      if (request.method == 'OPTIONS') {
        return Response.ok(
          '',
          headers: {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type, Authorization',
          },
        );
      }

      final response = await innerHandler(request);
      return response.change(
        headers: {
          ...response.headers,
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type, Authorization',
        },
      );
    };
  };
}



/// Handle POST /auth/register
Future<Response> _handleRegister(Request request, Connection database) async {
  try {
    final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;

    final email = (body['email'] as String?).toString().toLowerCase();
    final username = body['username'] as String?;
    final password = body['password'] as String?;

    // Validate required fields
    if (email.isEmpty) {
      return Response(400,
        body: jsonEncode({'error': 'Validation failed', 'details': ['Email is required']}),
        headers: {'Content-Type': 'application/json'},
      );
    }
    if (username?.isEmpty ?? true) {
      return Response(400,
        body: jsonEncode({'error': 'Validation failed', 'details': ['Username is required']}),
        headers: {'Content-Type': 'application/json'},
      );
    }
    if (password?.isEmpty ?? true) {
      return Response(400,
        body: jsonEncode({'error': 'Validation failed', 'details': ['Password is required']}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    // Validate password strength
    final passwordErrors = _validatePasswordStrength(password!);
    if (passwordErrors.isNotEmpty) {
      return Response(400,
        body: jsonEncode({'error': 'Password validation failed', 'details': passwordErrors}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    // Check for duplicate email/username in database
    final duplicateCheck = await database.query(
      'SELECT id FROM "users" WHERE email = @email OR username = @username',
      substitutionValues: {'email': email, 'username': username},
    );
    
    if (duplicateCheck.isNotEmpty) {
      final row = duplicateCheck.first.toColumnMap();
      final existingEmail = row['email'];
      if (existingEmail == email) {
        return Response(409,
          body: jsonEncode({'error': 'Email already registered'}),
          headers: {'Content-Type': 'application/json'},
        );
      } else {
        return Response(409,
          body: jsonEncode({'error': 'Username already taken'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    }

    // Hash password (bcrypt-like)
    final passwordHash = _hashPassword(password);
    final userId = const Uuid().v4(); // Just UUID, no prefix

    // Insert user into database
    await database.execute(
      '''INSERT INTO "users" (id, email, username, password_hash, email_verified, created_at)
         VALUES (@id, @email, @username, @password_hash, @email_verified, @created_at)''',
      substitutionValues: {
        'id': userId,
        'email': email,
        'username': username,
        'password_hash': passwordHash,
        'email_verified': false,
        'created_at': DateTime.now().toUtc(),
      },
    );

    return Response(201,
      body: jsonEncode({
        'user_id': userId,
        'email': email,
        'username': username,
      }),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e, st) {
    print('[ERROR] Registration error: $e');
    print('[ERROR] Stack: $st');
    return Response(500,
      body: jsonEncode({'error': 'Server error - please try again later'}),
      headers: {'Content-Type': 'application/json'},
    );
  }
}

/// Handle POST /auth/login
Future<Response> _handleLogin(Request request, Connection database) async {
  try {
    final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;

    final email = (body['email'] as String?).toString().toLowerCase();
    final password = body['password'] as String?;

    if (email.isEmpty) {
      return Response(400,
        body: jsonEncode({'error': 'Validation failed', 'details': ['Email is required']}),
        headers: {'Content-Type': 'application/json'},
      );
    }
    if (password?.isEmpty ?? true) {
      return Response(400,
        body: jsonEncode({'error': 'Validation failed', 'details': ['Password is required']}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    // Query database for user by email
    final result = await database.query(
      'SELECT id, email, username, password_hash FROM "users" WHERE email = @email',
      substitutionValues: {'email': email},
    );

    if (result.isEmpty) {
      return Response(401,
        body: jsonEncode({'error': 'Invalid email or password'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    final user = result.first.toColumnMap();
    final storedHash = user['password_hash'] as String;
    
    // Verify password
    if (!_verifyPassword(password!, storedHash)) {
      return Response(401,
        body: jsonEncode({'error': 'Invalid email or password'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    // Generate JWT token
    final userId = user['id'] as String;
    final jwtToken = JwtService.generateToken(userId, email);

    return Response.ok(
      jsonEncode({
        'user_id': userId,
        'email': email,
        'username': user['username'],
        'token': jwtToken,
      }),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e, st) {
    print('[ERROR] Login error: $e');
    print('[ERROR] Stack: $st');
    return Response(500,
      body: jsonEncode({'error': 'Server error - please try again later'}),
      headers: {'Content-Type': 'application/json'},
    );
  }
}

/// Handle GET /auth/me (protected)
Future<Response> _handleValidateSession(Request request, Connection database) async {
  try {
    final authHeader = request.headers['authorization'];
    if (authHeader == null || !authHeader.startsWith('Bearer ')) {
      return Response(401,
        body: jsonEncode({'error': 'Missing or invalid authorization header'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    // Validate JWT token
    try {
      final token = authHeader.substring('Bearer '.length);
      final payload = JwtService.validateToken(token);
      return Response.ok(
        jsonEncode({
          'is_authenticated': true,
          'user_id': payload.userId,
          'email': payload.email,
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } on AuthException catch (e) {
      return Response(401,
        body: jsonEncode({'error': 'Invalid token'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  } catch (e) {
    print('[ERROR] Session validation error: $e');
    return Response(500,
      body: jsonEncode({'error': 'Server error'}),
      headers: {'Content-Type': 'application/json'},
    );
  }
}

/// Handle POST /auth/logout (protected)
Future<Response> _handleLogout(Request request) async {
  try {
    final authHeader = request.headers['authorization'];
    if (authHeader == null || !authHeader.startsWith('Bearer ')) {
      return Response(401,
        body: jsonEncode({'error': 'Not authenticated'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    return Response.ok(
      jsonEncode({'message': 'Logged out successfully'}),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e) {
    return Response(500,
      body: jsonEncode({'error': 'Server error'}),
      headers: {'Content-Type': 'application/json'},
    );
  }
}

/// Validate password strength
List<String> _validatePasswordStrength(String password) {
  final errors = <String>[];
  
  if (password.length < 8) errors.add('Password must be at least 8 characters');
  if (!password.contains(RegExp(r'[a-z]'))) errors.add('Password must contain a lowercase letter');
  if (!password.contains(RegExp(r'[A-Z]'))) errors.add('Password must contain an uppercase letter');
  if (!password.contains(RegExp(r'[0-9]'))) errors.add('Password must contain a digit');
  if (!password.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'))) errors.add('Password must contain a special character');
  
  return errors;
}



/// Handle search by username (mock implementation)
/// Handle search by username (real database query)
Future<Response> _handleSearchByUsername(Request request, Connection database) async {
  try {
    // Check authentication and validate JWT token
    final authHeader = request.headers['authorization'];
    if (authHeader == null || !authHeader.startsWith('Bearer ')) {
      return Response.forbidden(
        jsonEncode({'error': 'Missing or invalid authorization header'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    // Validate JWT token
    try {
      final token = authHeader.substring('Bearer '.length);
      JwtService.validateToken(token);
    } on AuthException catch (e) {
      return Response.unauthorized(
        jsonEncode({'error': 'Invalid token'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    // Get query parameter
    final query = request.url.queryParameters['q'];
    if (query == null || query.isEmpty) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Missing required query parameter: q'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    // Get optional limit parameter
    int limit = 10;
    if (request.url.queryParameters['limit'] != null) {
      try {
        limit = int.parse(request.url.queryParameters['limit']!);
      } catch (e) {
        return Response.badRequest(
          body: jsonEncode({'error': 'Invalid limit parameter: must be an integer'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    }

    // Validate query
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Search query cannot be empty'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
    if (trimmed.length > 100) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Search query cannot exceed 100 characters'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    // Search database for users by username (case-insensitive partial match)
    final searchPattern = '%${trimmed.toLowerCase()}%';
    final results = await database.query(
      '''SELECT id, username, email FROM "users" 
         WHERE LOWER(username) LIKE @pattern 
         ORDER BY username ASC 
         LIMIT @limit''',
      substitutionValues: {
        'pattern': searchPattern,
        'limit': limit,
      },
    );

    // Convert results to response format
    final data = results.map((row) {
      final map = row.toColumnMap();
      return {
        'userId': map['id'] as String,
        'username': map['username'] as String,
        'email': map['email'] as String,
        'profilePictureUrl': null,
        'isPrivateProfile': false,
      };
    }).toList();

    return Response.ok(
      jsonEncode({
        'data': data,
        'count': data.length,
        'query': query,
        'type': 'username',
      }),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e) {
    print('[ERROR] Search by username error: $e');
    return Response.internalServerError(
      body: jsonEncode({'error': 'Internal server error'}),
      headers: {'Content-Type': 'application/json'},
    );
  }
}

/// Handle search by email (real database query)
Future<Response> _handleSearchByEmail(Request request, Connection database) async {
  try {
    // Check authentication and validate JWT token
    final authHeader = request.headers['authorization'];
    if (authHeader == null || !authHeader.startsWith('Bearer ')) {
      return Response.forbidden(
        jsonEncode({'error': 'Missing or invalid authorization header'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    // Validate JWT token
    try {
      final token = authHeader.substring('Bearer '.length);
      JwtService.validateToken(token);
    } on AuthException catch (e) {
      return Response.unauthorized(
        jsonEncode({'error': 'Invalid token'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    // Get query parameter
    final query = request.url.queryParameters['q'];
    if (query == null || query.isEmpty) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Missing required query parameter: q'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    // Get optional limit parameter
    int limit = 10;
    if (request.url.queryParameters['limit'] != null) {
      try {
        limit = int.parse(request.url.queryParameters['limit']!);
      } catch (e) {
        return Response.badRequest(
          body: jsonEncode({'error': 'Invalid limit parameter: must be an integer'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    }

    // Validate query
    final trimmed = query.trim();
    if (trimmed.length < 2) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Search query must be at least 2 characters'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
    // Allow partial email searches - just need @ or . (e.g., "alice.", "alice@", "alice.smith")
    if (!trimmed.contains('@') && !trimmed.contains('.')) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Email search must contain @ or . for email-like queries'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
    if (trimmed.length > 100) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Search query cannot exceed 100 characters'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    // Search database for users by email (case-insensitive partial match)
    final searchPattern = '%${trimmed.toLowerCase()}%';
    final results = await database.query(
      '''SELECT id, username, email FROM "users" 
         WHERE LOWER(email) LIKE @pattern 
         ORDER BY email ASC 
         LIMIT @limit''',
      substitutionValues: {
        'pattern': searchPattern,
        'limit': limit,
      },
    );

    // Convert results to response format
    final data = results.map((row) {
      final map = row.toColumnMap();
      return {
        'userId': map['id'] as String,
        'username': map['username'] as String,
        'email': map['email'] as String,
        'profilePictureUrl': null,
        'isPrivateProfile': false,
      };
    }).toList();

    return Response.ok(
      jsonEncode({
        'data': data,
        'count': data.length,
        'query': query,
        'type': 'email',
      }),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e) {
    print('[ERROR] Search by email error: $e');
    return Response.internalServerError(
      body: jsonEncode({'error': 'Internal server error'}),
      headers: {'Content-Type': 'application/json'},
    );
  }
}

/// Hash password using simple algorithm (in production, use bcrypt)
String _hashPassword(String password) {
  // Simple hash for demo (in production use bcrypt package)
  return password.hashCode.toRadixString(36);
}

/// Verify password against hash
bool _verifyPassword(String password, String hash) {
  return _hashPassword(password) == hash;
}
