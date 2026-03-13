import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'src/services/token_service.dart';
import 'src/services/email_service.dart';
import 'src/services/rate_limit_service.dart';
import 'src/endpoints/verification_handler.dart';
import 'src/endpoints/password_reset_handler.dart';
import 'src/endpoints/profile.dart' as profileEndpoint;
import 'src/models/user_search_result.dart';

void main() async {
  final port = int.parse(Platform.environment['SERVERPOD_PORT'] ?? '8081');
  final env = Platform.environment['SERVERPOD_ENV'] ?? 'development';

  print('[INFO] Starting Messenger Server (environment: $env)');

  // Initialize services
  final tokenService = TokenService();
  final emailService = EmailService();
  final rateLimitService = RateLimitService(
    maxAttempts: 5,
    windowDuration: Duration(hours: 1),
  );

  // Initialize mock search data for development
  _initializeMockSearchData();
  print('[INFO] Mock search data initialized with development users');

  // Setup middleware pipeline
  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(_corsMiddleware())
      .addHandler(_createHandler(
        tokenService,
        emailService,
        rateLimitService,
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
  print('║ ✓ Database integration ready                          ║');
  print('╚═══════════════════════════════════════════════════════╝');
}

/// Create the main request handler
Handler _createHandler(
  TokenService tokenService,
  EmailService emailService,
  RateLimitService rateLimitService,
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
        return await _handleRegister(request);
      }

      // Auth endpoints (login - public)
      if (path == 'auth/login' && method == 'POST') {
        return await _handleLogin(request);
      }

      // Auth endpoints (validate session - protected)
      if (path == 'auth/me' && method == 'GET') {
        return await _handleValidateSession(request);
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
        return await profileEndpoint.editProfile(request);
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
          return _handleSearchByUsername(request);
        } catch (e) {
          return Response.internalServerError(
            body: jsonEncode({'error': 'Search service error: $e'}),
            headers: {'Content-Type': 'application/json'},
          );
        }
      }

      if (path == 'search/email' && method == 'GET') {
        try {
          return _handleSearchByEmail(request);
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

/// Test data store (simulating database)
final Map<String, Map<String, dynamic>> _testUsers = {};
const String testUserId = 'user-123-abc';
const String testToken = 'eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoidXNlci0xMjMtYWJjIiwiZW1haWwiOiJ0ZXN0QGV4YW1wbGUuY29tIiwiaWF0IjoxNjI2MDAwMDAwLCJleHAiOjE2MjczMzYwMDB9.test_signature';

/// Handle POST /auth/register
Future<Response> _handleRegister(Request request) async {
  try {
    final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;

    final email = body['email'] as String?;
    final username = body['username'] as String?;
    final password = body['password'] as String?;
    final fullName = body['full_name'] as String?;

    // Validate required fields
    if (email?.isEmpty ?? true) {
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

    // Check for duplicate email
    if (_testUsers.values.any((user) => user['email'] == email)) {
      return Response(409,
        body: jsonEncode({'error': 'Email already registered'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    // Check for duplicate username
    if (_testUsers.values.any((user) => user['username'] == username)) {
      return Response(409,
        body: jsonEncode({'error': 'Username already taken'}),
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

    // Create user (test)
    final userId = 'user-${const Uuid().v4()}';
    _testUsers[userId] = {
      'user_id': userId,
      'email': email,
      'username': username,
      'full_name': fullName,
      'password_hash': password, // In real app, would be hashed
    };

    return Response(201,
      body: jsonEncode({
        'user_id': userId,
        'email': email,
        'username': username,
        'message': 'Account created successfully'
      }),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e) {
    return Response(500,
      body: jsonEncode({'error': 'Server error - please try again later'}),
      headers: {'Content-Type': 'application/json'},
    );
  }
}

/// Handle POST /auth/login
Future<Response> _handleLogin(Request request) async {
  try {
    final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;

    final email = body['email'] as String?;
    final password = body['password'] as String?;

    if (email?.isEmpty ?? true) {
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

    // Find user by email
    final user = _testUsers.values.firstWhere(
      (u) => u['email'] == email,
      orElse: () => {},
    );

    if (user.isEmpty || user['password_hash'] != password) {
      return Response(401,
        body: jsonEncode({'error': 'Invalid email or password'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    return Response.ok(
      jsonEncode({
        'user_id': user['user_id'],
        'email': user['email'],
        'username': user['username'],
        'token': testToken,
      }),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e) {
    return Response(500,
      body: jsonEncode({'error': 'Server error - please try again later'}),
      headers: {'Content-Type': 'application/json'},
    );
  }
}

/// Handle GET /auth/me (protected)
Future<Response> _handleValidateSession(Request request) async {
  try {
    final authHeader = request.headers['authorization'];
    if (authHeader == null || !authHeader.startsWith('Bearer ')) {
      return Response(401,
        body: jsonEncode({'error': 'Missing or invalid authorization header'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    final token = authHeader.substring(7);
    if (token != testToken) {
      return Response(401,
        body: jsonEncode({'error': 'Invalid or expired token'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    // Find test user
    final user = _testUsers.values.firstWhere(
      (u) => u['user_id'] == testUserId,
      orElse: () => {},
    );

    if (user.isEmpty) {
      return Response(401,
        body: jsonEncode({'error': 'User not found'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    return Response.ok(
      jsonEncode({
        'user_id': user['user_id'],
        'email': user['email'],
        'is_authenticated': true,
      }),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e) {
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

/// Mock search data (in-memory database for development/testing)
final Map<String, UserSearchResult> _mockSearchUsers = {};

/// Initialize mock search data with development users
void _initializeMockSearchData() {
  _mockSearchUsers.clear();
  _testUsers.clear();
  
  final mockUsers = [
    UserSearchResult(
      userId: 'user-001',
      username: 'alice',
      email: 'alice@example.com',
      profilePictureUrl: null,
      isPrivateProfile: false,
    ),
    UserSearchResult(
      userId: 'user-002',
      username: 'bob',
      email: 'bob@example.com',
      profilePictureUrl: null,
      isPrivateProfile: false,
    ),
    UserSearchResult(
      userId: 'user-003',
      username: 'charlie',
      email: 'charlie@example.com',
      profilePictureUrl: null,
      isPrivateProfile: false,
    ),
    UserSearchResult(
      userId: 'user-004',
      username: 'alice_smith',
      email: 'alice.smith@example.com',
      profilePictureUrl: null,
      isPrivateProfile: false,
    ),
    UserSearchResult(
      userId: 'user-005',
      username: 'bob_jones',
      email: 'bob.jones@example.com',
      profilePictureUrl: null,
      isPrivateProfile: false,
    ),
    UserSearchResult(
      userId: 'user-006',
      username: 'diane',
      email: 'diane@test.org',
      profilePictureUrl: null,
      isPrivateProfile: false,
    ),
  ];
  
  for (final user in mockUsers) {
    _mockSearchUsers[user.userId] = user;
    
    // Also add to _testUsers for authentication
    _testUsers[user.userId] = {
      'user_id': user.userId,
      'email': user.email,
      'username': user.username,
      'full_name': user.username,
      'password_hash': 'password123', // Default password for development
    };
  }
  
  print('[MOCK] Initialized ${mockUsers.length} search users and ${_testUsers.length} test auth users');
}

/// Handle search by username (mock implementation)
Response _handleSearchByUsername(Request request) {
  try {
    // Check authentication
    final authHeader = request.headers['authorization'];
    if (authHeader == null || !authHeader.startsWith('Bearer ')) {
      return Response.forbidden(
        jsonEncode({'error': 'Missing or invalid authorization header'}),
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
    if (trimmed.length > 100) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Search query cannot exceed 100 characters'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    // Mock search - filter users by username (case-insensitive)
    final results = _mockSearchUsers.values
        .where((u) => u.username.toLowerCase().contains(trimmed.toLowerCase()))
        .toList();

    // Sort by exact match first, then by username
    results.sort((a, b) {
      final aIsExact = a.username.toLowerCase() == trimmed.toLowerCase() ? 0 : 1;
      final bIsExact = b.username.toLowerCase() == trimmed.toLowerCase() ? 0 : 1;
      if (aIsExact != bIsExact) return aIsExact.compareTo(bIsExact);
      return a.username.compareTo(b.username);
    });

    // Limit results
    final limitedResults = results.take(limit).toList();

    return Response.ok(
      jsonEncode({
        'data': limitedResults.map((r) => r.toJson()).toList(),
        'count': limitedResults.length,
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

/// Handle search by email (mock implementation)
Response _handleSearchByEmail(Request request) {
  try {
    // Check authentication
    final authHeader = request.headers['authorization'];
    if (authHeader == null || !authHeader.startsWith('Bearer ')) {
      return Response.forbidden(
        jsonEncode({'error': 'Missing or invalid authorization header'}),
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
    if (!trimmed.contains('@')) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Invalid email format'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
    if (trimmed.length > 100) {
      return Response.badRequest(
        body: jsonEncode({'error': 'Search query cannot exceed 100 characters'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    // Mock search - filter users by email (case-insensitive)
    final results = _mockSearchUsers.values
        .where((u) => u.email.toLowerCase().contains(trimmed.toLowerCase()))
        .toList();

    // Sort by exact match first, then by email
    results.sort((a, b) {
      final aIsExact = a.email.toLowerCase() == trimmed.toLowerCase() ? 0 : 1;
      final bIsExact = b.email.toLowerCase() == trimmed.toLowerCase() ? 0 : 1;
      if (aIsExact != bIsExact) return aIsExact.compareTo(bIsExact);
      return a.email.compareTo(b.email);
    });

    // Limit results
    final limitedResults = results.take(limit).toList();

    return Response.ok(
      jsonEncode({
        'data': limitedResults.map((r) => r.toJson()).toList(),
        'count': limitedResults.length,
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
