import 'dart:async';
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
import 'src/services/password_reset_service.dart';
import 'src/services/chat_service.dart';
import 'src/services/encryption_service.dart';
import 'src/services/notification_service.dart';
import 'src/services/service_config.dart';
import 'src/endpoints/verification_handler.dart';
import 'src/endpoints/password_reset_handler.dart';
import 'src/services/verification_service.dart';
import 'src/endpoints/profile.dart' as profileEndpoint;
import 'src/models/user_search_result.dart';
import 'src/models/chat_invite_model.dart';
import 'src/handlers/chat_handlers.dart';
import 'src/handlers/message_handlers.dart';
import 'src/handlers/media_handlers.dart';
import 'src/handlers/websocket_handler.dart';
import 'src/services/websocket_service.dart';

// Alias for cleaner code
typedef Connection = PostgreSQLConnection;

bool get _verboseBackendLogs {
  final value = Platform.environment['VERBOSE_BACKEND_LOGS'];
  if (value == null) return false;
  return value.toLowerCase() == '1' || value.toLowerCase() == 'true';
}

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
      password:
          Platform.environment['DATABASE_PASSWORD'] ?? 'messenger_password',
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

  // Seed test users for development
  if (env == 'development') {
    print('[INFO] Seeding test users for development...');
    await _seedTestUsers(dbConnection);
  }

  // Initialize services
  final tokenService = TokenService();
  final emailService = EmailService(
    smtpHost: Platform.environment['SMTP_HOST'],
    smtpPort: int.tryParse(Platform.environment['SMTP_PORT'] ?? ''),
    senderEmail: Platform.environment['SMTP_FROM_EMAIL'],
    senderName: Platform.environment['SMTP_FROM_NAME'] ?? 'Mobile Messenger',
    smtpUser: Platform.environment['SMTP_USER'],
    smtpPassword: Platform.environment['SMTP_PASSWORD'],
    smtpSecure:
        (Platform.environment['SMTP_SECURE'] ?? 'false').toLowerCase() ==
            'true',
  );
  if (Platform.environment['SMTP_HOST'] != null) {
    print(
        '[✓] Email: SMTP → ${Platform.environment['SMTP_HOST']}:${Platform.environment['SMTP_PORT'] ?? '?'}');
  } else {
    print(
        '[INFO] Email: No SMTP configured — tokens returned in API response (dev mode)');
  }
  for (final warning in emailService.getConfigurationWarnings()) {
    print('[WARNING] Email configuration: $warning');
  }
  final verificationService = VerificationService(
    connection: dbConnection,
    tokenService: tokenService,
  );
  final passwordResetService = PasswordResetService(
    connection: dbConnection,
    tokenService: tokenService,
  );
  final rateLimitService = RateLimitService(
    maxAttempts: 5,
    windowDuration: Duration(hours: 1),
  );

  // Initialize encryption service with master key from environment
  final encryptionMasterKey = Platform.environment['ENCRYPTION_MASTER_KEY'];
  late EncryptionService encryptionService;

  if (encryptionMasterKey != null && encryptionMasterKey.isNotEmpty) {
    encryptionService =
        EncryptionService(masterEncryptionKey: encryptionMasterKey);
    print('[✓] Encryption service initialized with master key');
  } else {
    print(
        '[WARNING] ENCRYPTION_MASTER_KEY not set - encryption disabled. Set this in production!');
    // Create dummy service that returns plaintext
    encryptionService = EncryptionService(
        masterEncryptionKey: 'default-insecure-key-development-only');
  }

  // Initialize service config for handlers to access services
  ServiceConfig.initialize(encryptionService);
  MediaHandlers.initialize(dbConnection);

  print('[INFO] Services initialized');

  // Initialize profile endpoint
  print('[INFO] Initializing profile service...');
  profileEndpoint.initializeProfileService(dbConnection);

  // Setup middleware pipeline
  final handler = Pipeline()
      .addMiddleware(_logRequestsExceptHealth())
      .addMiddleware(_corsMiddleware())
      .addHandler(_createHandler(
        tokenService,
        emailService,
        rateLimitService,
        dbConnection,
        encryptionService,
        verificationService,
        passwordResetService,
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
  EncryptionService encryptionService,
  VerificationService verificationService,
  PasswordResetService passwordResetService,
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

      if (_verboseBackendLogs) {
        print(
            '[DEBUG] Received request: $method /$path (raw: ${request.url.path})');
      }

      // Static file serving for /uploads directory
      if (path.startsWith('uploads/')) {
        return _serveStaticFile(request, path);
      }

      // Health check endpoint (public)
      if (path == 'health' && method == 'GET') {
        return Response.ok(
          jsonEncode({
            'status': 'healthy',
            'timestamp': DateTime.now().toIso8601String()
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // Schema status endpoint (public)
      if (path == 'schema' && method == 'GET') {
        return Response.ok(
          jsonEncode({
            'status':
                'Schema tables created via migrations: users, chats, chat_members, messages, invites, verification_token, password_reset_token, password_reset_attempt'
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // Password reset landing page (public)
      // Opened from emails: /reset?token=...
      if (path == 'reset' && method == 'GET') {
        final token = request.url.queryParameters['token'] ?? '';
        if (token.isEmpty) {
          return Response.badRequest(
            body: 'Missing token',
            headers: {'Content-Type': 'text/plain; charset=utf-8'},
          );
        }

        final html = '''
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Reset Password</title>
  <style>
    body { font-family: Arial, sans-serif; background: #f5f7fb; margin: 0; }
    .card { max-width: 420px; margin: 48px auto; background: #fff; border: 1px solid #e2e8f0; border-radius: 10px; padding: 24px; }
    h1 { margin: 0 0 12px; font-size: 24px; }
    p { color: #475569; margin: 0 0 20px; }
    label { display: block; font-weight: 600; margin-bottom: 8px; }
    input { width: 100%; box-sizing: border-box; padding: 10px 12px; border: 1px solid #cbd5e1; border-radius: 8px; margin-bottom: 12px; }
    button { width: 100%; padding: 11px 12px; background: #2563eb; color: #fff; border: 0; border-radius: 8px; font-weight: 600; cursor: pointer; }
    button:disabled { opacity: 0.7; cursor: not-allowed; }
    .msg { margin-top: 14px; font-size: 14px; }
    .err { color: #b91c1c; }
    .ok { color: #166534; }
  </style>
</head>
<body>
  <div class="card">
    <h1>Reset your password</h1>
    <p>Enter your new password below.</p>
    <label for="pw">New password</label>
    <input id="pw" type="password" autocomplete="new-password" placeholder="At least 8 characters" />
    <label for="cpw">Confirm password</label>
    <input id="cpw" type="password" autocomplete="new-password" placeholder="Repeat password" />
    <button id="submit">Update Password</button>
    <div id="msg" class="msg"></div>
  </div>

  <script>
    const token = ${jsonEncode(token)};
    const submit = document.getElementById('submit');
    const msg = document.getElementById('msg');
    const pw = document.getElementById('pw');
    const cpw = document.getElementById('cpw');

    function show(text, ok) {
      msg.textContent = text;
      msg.className = 'msg ' + (ok ? 'ok' : 'err');
    }

    submit.addEventListener('click', async () => {
      if (!pw.value) return show('Please enter a new password.', false);
      if (pw.value !== cpw.value) return show('Passwords do not match.', false);

      submit.disabled = true;
      show('Updating password...', true);

      try {
        const res = await fetch('/auth/password-reset/confirm', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ token, newPassword: pw.value }),
        });

        const data = await res.json().catch(() => ({}));
        if (res.ok) {
          show(data.message || 'Password reset successfully. You can now log in.', true);
          pw.value = '';
          cpw.value = '';
        } else {
          show(data.error || 'Failed to reset password.', false);
        }
      } catch (_) {
        show('Network error while resetting password.', false);
      } finally {
        submit.disabled = false;
      }
    });
  </script>
</body>
</html>
''';

        return Response.ok(
          html,
          headers: {'Content-Type': 'text/html; charset=utf-8'},
        );
      }

      // Auth endpoints (registration - public)
      if (path == 'auth/register' && method == 'POST') {
        return await _handleRegister(
            request, database, tokenService, emailService, verificationService);
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
          verificationService,
        );
      }

      if (path == 'auth/verify-email/confirm' && method == 'POST') {
        return await verifyEmailToken(
          request,
          tokenService,
          verificationService,
        );
      }

      // Password reset endpoints (public)
      if (path == 'auth/password-reset/request' && method == 'POST') {
        return await requestPasswordReset(
          request,
          emailService,
          rateLimitService,
          passwordResetService,
        );
      }

      if (path == 'auth/password-reset/confirm' && method == 'POST') {
        return await confirmPasswordReset(
          request,
          passwordResetService,
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

      // Invite endpoints - simple in-memory implementation for testing
      // GET /api/users/<userId>/invites/pending/count - Get count of pending invites
      if (path.startsWith('api/users/') &&
          path.contains('/invites/pending/count') &&
          method == 'GET') {
        print('[InviteHandler] Fetching pending invite count for user');
        try {
          // Verify authorization
          final authHeader = request.headers['authorization'];
          if (authHeader == null || !authHeader.startsWith('Bearer ')) {
            return Response(
              401,
              body: jsonEncode(
                  {'error': 'Missing or invalid authorization header'}),
              headers: {'Content-Type': 'application/json'},
            );
          }

          final token = authHeader.substring('Bearer '.length);
          final payload = JwtService.validateToken(token);
          final authenticatedUserId = payload.userId;

          // Extract userId from path: api/users/{userId}/invites/pending/count
          final pathParts = path.split('/');
          final userIdIndex = pathParts.indexOf('users') + 1;
          final userId = userIdIndex > 0 && userIdIndex < pathParts.length
              ? pathParts[userIdIndex]
              : null;

          if (userId == null) {
            return Response(
              400,
              body: jsonEncode({'error': 'User ID not found in path'}),
              headers: {'Content-Type': 'application/json'},
            );
          }

          // Ensure user can only access their own invite count
          if (authenticatedUserId != userId) {
            print(
                '[InviteHandler] ⚠️  Unauthorized access attempt: user $authenticatedUserId tried to access count for user $userId');
            return Response(
              403,
              body: jsonEncode({
                'error': 'Unauthorized - you can only view your own invitations'
              }),
              headers: {'Content-Type': 'application/json'},
            );
          }

          // Query count of pending invites
          final result = await database.query(
            '''SELECT COUNT(*) as count FROM invites 
               WHERE receiver_id = @userId AND status = 'pending' ''',
            substitutionValues: {'userId': userId},
          );

          final count = result.isNotEmpty ? result[0][0] as int : 0;

          return Response.ok(
            jsonEncode({'count': count}),
            headers: {'Content-Type': 'application/json'},
          );
        } on AuthException catch (e) {
          return Response(
            401,
            body: jsonEncode({'error': 'Invalid token'}),
            headers: {'Content-Type': 'application/json'},
          );
        } catch (e) {
          print('[InviteHandler] ❌ Error fetching pending invite count: $e');
          return Response(
            400,
            body: jsonEncode({'error': e.toString()}),
            headers: {'Content-Type': 'application/json'},
          );
        }
      }

      // GET /api/users/<userId>/invites/pending - Get pending invites for user
      if (path.startsWith('api/users/') &&
          path.contains('/invites/pending') &&
          method == 'GET') {
        print('[InviteHandler] Fetching pending invites for user');
        try {
          // Verify authorization
          final authHeader = request.headers['authorization'];
          if (authHeader == null || !authHeader.startsWith('Bearer ')) {
            return Response(
              401,
              body: jsonEncode(
                  {'error': 'Missing or invalid authorization header'}),
              headers: {'Content-Type': 'application/json'},
            );
          }

          final token = authHeader.substring('Bearer '.length);
          final payload = JwtService.validateToken(token);
          final authenticatedUserId = payload.userId;

          // Extract userId from path: api/users/{userId}/invites/pending
          final pathParts = path.split('/');
          final userIdIndex = pathParts.indexOf('users') + 1;
          final userId = userIdIndex > 0 && userIdIndex < pathParts.length
              ? pathParts[userIdIndex]
              : null;

          if (userId == null) {
            return Response(
              400,
              body: jsonEncode({'error': 'User ID not found in path'}),
              headers: {'Content-Type': 'application/json'},
            );
          }

          // Ensure user can only access their own pending invites
          print(
              '[InviteHandler] 🔍 DEBUG: authenticatedUserId=$authenticatedUserId, requested userId=$userId');
          if (authenticatedUserId != userId) {
            print(
                '[InviteHandler] ⚠️  Unauthorized access attempt: user $authenticatedUserId tried to access pending invites for user $userId');
            return Response(
              403,
              body: jsonEncode({
                'error': 'Unauthorized - you can only view your own invitations'
              }),
              headers: {'Content-Type': 'application/json'},
            );
          }

          print('[InviteHandler] Fetching pending invites for userId: $userId');

          // Query pending invites from database (where this user is the receiver)
          // JOIN with both sender AND recipient to get all user info
          final result = await database.query(
            '''SELECT i.id, i.sender_id, u.username, u.profile_picture_url, i.receiver_id, r.username, r.profile_picture_url, i.status, i.created_at, i.responded_at 
               FROM invites i 
               JOIN users u ON i.sender_id = u.id 
               JOIN users r ON i.receiver_id = r.id
               WHERE i.receiver_id = @userId AND i.status = 'pending' 
               ORDER BY i.created_at DESC''',
            substitutionValues: {'userId': userId},
          );

          final invites = result
              .map((row) => {
                    'id': row[0].toString(),
                    'senderId': row[1].toString(),
                    'senderName': row[2] as String,
                    'senderAvatarUrl': row[3] as String?,
                    'recipientId': row[4].toString(),
                    'recipientName': row[5] as String,
                    'recipientAvatarUrl': row[6] as String?,
                    'status': row[7] as String,
                    'createdAt': (row[8] as DateTime).toIso8601String(),
                    'updatedAt': (row[9] as DateTime?)?.toIso8601String() ??
                        (row[8] as DateTime).toIso8601String(),
                    'deletedAt': null,
                  })
              .toList();

          print('[InviteHandler] ✅ Fetched ${invites.length} pending invites');

          return Response.ok(
            jsonEncode(invites),
            headers: {'Content-Type': 'application/json'},
          );
        } on AuthException catch (e) {
          return Response(
            401,
            body: jsonEncode({'error': 'Invalid token'}),
            headers: {'Content-Type': 'application/json'},
          );
        } catch (e) {
          print('[InviteHandler] ❌ Error fetching pending invites: $e');
          return Response(
            400,
            body: jsonEncode({'error': e.toString()}),
            headers: {'Content-Type': 'application/json'},
          );
        }
      }

      // GET /api/users/<userId>/invites/sent - Get sent invites for user
      if (path.startsWith('api/users/') &&
          path.contains('/invites/sent') &&
          method == 'GET') {
        print('[InviteHandler] Fetching sent invites for user');
        try {
          // Verify authorization
          final authHeader = request.headers['authorization'];
          if (authHeader == null || !authHeader.startsWith('Bearer ')) {
            return Response(
              401,
              body: jsonEncode(
                  {'error': 'Missing or invalid authorization header'}),
              headers: {'Content-Type': 'application/json'},
            );
          }

          final token = authHeader.substring('Bearer '.length);
          final payload = JwtService.validateToken(token);
          final authenticatedUserId = payload.userId;

          // Extract userId from path: api/users/{userId}/invites/sent
          final pathParts = path.split('/');
          final userIdIndex = pathParts.indexOf('users') + 1;
          final userId = userIdIndex > 0 && userIdIndex < pathParts.length
              ? pathParts[userIdIndex]
              : null;

          if (userId == null) {
            return Response(
              400,
              body: jsonEncode({'error': 'User ID not found in path'}),
              headers: {'Content-Type': 'application/json'},
            );
          }

          // Ensure user can only access their own sent invites
          if (authenticatedUserId != userId) {
            print(
                '[InviteHandler] ⚠️  Unauthorized access attempt: user $authenticatedUserId tried to access sent invites for user $userId');
            return Response(
              403,
              body: jsonEncode({
                'error': 'Unauthorized - you can only view your own invitations'
              }),
              headers: {'Content-Type': 'application/json'},
            );
          }

          print('[InviteHandler] Fetching sent invites for userId: $userId');

          // Query sent invites from database (where this user is the sender)
          // JOIN with sender and recipient user info
          final result = await database.query(
            '''SELECT i.id, i.sender_id, s.username, s.profile_picture_url, i.receiver_id, r.username, r.profile_picture_url, i.status, i.created_at, i.responded_at 
               FROM invites i 
               JOIN users s ON i.sender_id = s.id
               JOIN users r ON i.receiver_id = r.id 
               WHERE i.sender_id = @userId 
               ORDER BY i.created_at DESC''',
            substitutionValues: {'userId': userId},
          );

          final invites = result
              .map((row) => {
                    'id': row[0].toString(),
                    'senderId': row[1].toString(),
                    'senderName': row[2] as String,
                    'senderAvatarUrl': row[3] as String?,
                    'recipientId': row[4].toString(),
                    'recipientName': row[5] as String,
                    'recipientAvatarUrl': row[6] as String?,
                    'status': row[7] as String,
                    'createdAt': (row[8] as DateTime).toIso8601String(),
                    'updatedAt': (row[9] as DateTime?)?.toIso8601String() ??
                        (row[8] as DateTime).toIso8601String(),
                    'deletedAt': null,
                  })
              .toList();

          print('[InviteHandler] ✅ Fetched ${invites.length} sent invites');

          return Response.ok(
            jsonEncode(invites),
            headers: {'Content-Type': 'application/json'},
          );
        } on AuthException catch (e) {
          return Response(
            401,
            body: jsonEncode({'error': 'Invalid token'}),
            headers: {'Content-Type': 'application/json'},
          );
        } catch (e) {
          print('[InviteHandler] ❌ Error fetching sent invites: $e');
          return Response(
            400,
            body: jsonEncode({'error': e.toString()}),
            headers: {'Content-Type': 'application/json'},
          );
        }
      }

      // POST /api/invites - Send a new invite
      if (path == 'api/invites' && method == 'POST') {
        print('[InviteHandler] Sending new invite');
        try {
          final authHeader = request.headers['authorization'];
          if (authHeader == null || !authHeader.startsWith('Bearer ')) {
            return Response(
              401,
              body: jsonEncode(
                  {'error': 'Missing or invalid authorization header'}),
              headers: {'Content-Type': 'application/json'},
            );
          }

          // Extract and validate token
          final token = authHeader.substring('Bearer '.length);
          final payload = JwtService.validateToken(token);
          final senderId = payload.userId;

          final body =
              jsonDecode(await request.readAsString()) as Map<String, dynamic>;
          final recipientId = body['recipientId'] as String?;

          if (recipientId == null) {
            return Response(
              400,
              body: jsonEncode({'error': 'recipientId is required'}),
              headers: {'Content-Type': 'application/json'},
            );
          }

          // Fetch sender info
          final senderResult = await database.query(
            'SELECT id, username FROM users WHERE id = @senderId',
            substitutionValues: {'senderId': senderId},
          );

          if (senderResult.isEmpty) {
            return Response(
              404,
              body: jsonEncode({'error': 'Sender not found'}),
              headers: {'Content-Type': 'application/json'},
            );
          }

          final senderUsername = senderResult[0][1] as String;

          // Check if recipient exists
          final recipientResult = await database.query(
            'SELECT id FROM users WHERE id = @recipientId',
            substitutionValues: {'recipientId': recipientId},
          );

          if (recipientResult.isEmpty) {
            return Response(
              404,
              body: jsonEncode({'error': 'Recipient not found'}),
              headers: {'Content-Type': 'application/json'},
            );
          }

          // Check for existing pending invite
          final pendingInviteCheck = await database.query(
            '''SELECT id FROM invites 
               WHERE sender_id = @senderId AND receiver_id = @recipientId AND status IN ('pending', 'accepted') 
               LIMIT 1''',
            substitutionValues: {
              'senderId': senderId,
              'recipientId': recipientId
            },
          );

          if (pendingInviteCheck.isNotEmpty) {
            return Response(
              409,
              body: jsonEncode(
                  {'error': 'Pending invitation already exists to this user'}),
              headers: {'Content-Type': 'application/json'},
            );
          }

          // Insert invite into database
          final inviteId = _generateId();
          await database.execute(
            '''INSERT INTO invites (id, sender_id, receiver_id, status, created_at) 
               VALUES (@id, @senderId, @recipientId, 'pending', NOW())''',
            substitutionValues: {
              'id': inviteId,
              'senderId': senderId,
              'recipientId': recipientId,
            },
          );

          print('[InviteHandler] ✅ Invite created: $inviteId');

          final notificationService = NotificationService(database);
          await notificationService.notifyInvite(
            recipientUserId: recipientId,
            senderName: senderUsername,
            inviteId: inviteId,
          );

          WebSocketService().notifyUser(
            recipientId,
            WebSocketEvent(
              type: WebSocketEventType.invitationSent,
              data: {
                'inviteId': inviteId,
                'senderId': senderId,
                'senderName': senderUsername,
              },
            ),
          );

          // Fetch recipient info for response
          final recipientInfoResult = await database.query(
            'SELECT username, profile_picture_url FROM users WHERE id = @recipientId',
            substitutionValues: {'recipientId': recipientId},
          );

          final recipientName = recipientInfoResult.isNotEmpty
              ? recipientInfoResult[0][0] as String
              : 'Unknown';
          final recipientAvatarUrl = recipientInfoResult.isNotEmpty
              ? recipientInfoResult[0][1] as String?
              : null;

          return Response(
            201,
            body: jsonEncode({
              'id': inviteId,
              'senderId': senderId,
              'senderName': senderUsername,
              'senderAvatarUrl': null,
              'recipientId': recipientId,
              'recipientName': recipientName,
              'recipientAvatarUrl': recipientAvatarUrl,
              'status': 'pending',
              'createdAt': DateTime.now().toIso8601String(),
              'updatedAt': DateTime.now().toIso8601String(),
              'deletedAt': null,
            }),
            headers: {'Content-Type': 'application/json'},
          );
        } on AuthException catch (e) {
          return Response(
            401,
            body: jsonEncode({'error': 'Invalid token'}),
            headers: {'Content-Type': 'application/json'},
          );
        } catch (e) {
          print('[InviteHandler] ❌ Error sending invite: $e');
          return Response(
            400,
            body: jsonEncode({'error': e.toString()}),
            headers: {'Content-Type': 'application/json'},
          );
        }
      }

      // POST /api/invites/{inviteId}/accept - Accept an invite
      if (path.contains('api/invites/') &&
          path.endsWith('/accept') &&
          method == 'POST') {
        print('[InviteHandler] Accepting invite');
        try {
          final authHeader = request.headers['authorization'];
          if (authHeader == null || !authHeader.startsWith('Bearer ')) {
            return Response(
              401,
              body: jsonEncode(
                  {'error': 'Missing or invalid authorization header'}),
              headers: {'Content-Type': 'application/json'},
            );
          }

          final token = authHeader.substring('Bearer '.length);
          final payload = JwtService.validateToken(token);

          final inviteId =
              path.replaceFirst('api/invites/', '').replaceFirst('/accept', '');

          // Fetch full invite record
          final inviteResult = await database.query(
            'SELECT id, sender_id, receiver_id, status, created_at, responded_at FROM invites WHERE id = @inviteId',
            substitutionValues: {'inviteId': inviteId},
          );

          if (inviteResult.isEmpty) {
            return Response(
              404,
              body: jsonEncode({'error': 'Invite not found'}),
              headers: {'Content-Type': 'application/json'},
            );
          }

          final row = inviteResult[0];
          final senderId = row[1] as String;

          // Fetch sender info
          final senderResult = await database.query(
            'SELECT username FROM users WHERE id = @senderId',
            substitutionValues: {'senderId': senderId},
          );

          final senderUsername = senderResult.isNotEmpty
              ? senderResult[0][0] as String
              : 'Unknown';

          // Update invite status
          await database.execute(
            '''UPDATE invites SET status = 'accepted', responded_at = NOW() WHERE id = @inviteId''',
            substitutionValues: {'inviteId': inviteId},
          );

          print('[InviteHandler] ✅ Invite accepted: $inviteId');

          // Create a chat between the two users
          try {
            final receiverId = row[2] as String;

            // Ensure participant_1_id < participant_2_id for consistency
            final participant1Id =
                senderId.compareTo(receiverId) < 0 ? senderId : receiverId;
            final participant2Id =
                senderId.compareTo(receiverId) < 0 ? receiverId : senderId;

            final chatId = const Uuid().v4();
            final now = DateTime.now().toUtc();

            // Insert chat or update if already exists
            await database.execute(
              '''INSERT INTO chats 
                 (id, participant_1_id, participant_2_id, is_participant_1_archived, 
                  is_participant_2_archived, created_at, updated_at)
                 VALUES (@id, @participant1, @participant2, @archived1, @archived2, @now, @now)
                 ON CONFLICT (participant_1_id, participant_2_id) 
                 DO UPDATE SET updated_at = @now''',
              substitutionValues: {
                'id': chatId,
                'participant1': participant1Id,
                'participant2': participant2Id,
                'archived1': false,
                'archived2': false,
                'now': now,
              },
            );
            print(
                '[InviteHandler] ✓ Chat created for accepted invite: $chatId');
          } catch (e) {
            print('[InviteHandler] ⚠️ Warning: Failed to create chat: $e');
            // Continue - don't fail the whole accept, but log the warning
          }

          return Response.ok(
            jsonEncode({
              'id': inviteId,
              'senderId': senderId,
              'senderName': senderUsername,
              'senderAvatarUrl': null,
              'recipientId': row[2] as String,
              'status': 'accepted',
              'createdAt': (row[4] as DateTime).toIso8601String(),
              'updatedAt': DateTime.now().toIso8601String(),
              'deletedAt': null,
            }),
            headers: {'Content-Type': 'application/json'},
          );
        } on AuthException catch (e) {
          return Response(
            401,
            body: jsonEncode({'error': 'Invalid token'}),
            headers: {'Content-Type': 'application/json'},
          );
        } catch (e) {
          print('[InviteHandler] ❌ Error accepting invite: $e');
          return Response(
            400,
            body: jsonEncode({'error': e.toString()}),
            headers: {'Content-Type': 'application/json'},
          );
        }
      }

      // POST /api/invites/{inviteId}/decline - Decline an invite
      if (path.contains('api/invites/') &&
          path.endsWith('/decline') &&
          method == 'POST') {
        print('[InviteHandler] Declining invite');
        try {
          final authHeader = request.headers['authorization'];
          if (authHeader == null || !authHeader.startsWith('Bearer ')) {
            return Response(
              401,
              body: jsonEncode(
                  {'error': 'Missing or invalid authorization header'}),
              headers: {'Content-Type': 'application/json'},
            );
          }

          final token = authHeader.substring('Bearer '.length);
          final payload = JwtService.validateToken(token);

          final inviteId = path
              .replaceFirst('api/invites/', '')
              .replaceFirst('/decline', '');

          // Fetch full invite record
          final inviteResult = await database.query(
            'SELECT id, sender_id, receiver_id, status, created_at, responded_at FROM invites WHERE id = @inviteId',
            substitutionValues: {'inviteId': inviteId},
          );

          if (inviteResult.isEmpty) {
            return Response(
              404,
              body: jsonEncode({'error': 'Invite not found'}),
              headers: {'Content-Type': 'application/json'},
            );
          }

          final row = inviteResult[0];
          final senderId = row[1] as String;
          final recipientId = row[2] as String;
          final currentStatus = row[3] as String;

          // Ensure user can only decline their own invites
          if (payload.userId != recipientId) {
            return Response(
              403,
              body: jsonEncode({
                'error': 'Unauthorized - you can only decline your own invites'
              }),
              headers: {'Content-Type': 'application/json'},
            );
          }

          // Can only decline pending invitations
          if (currentStatus != 'pending') {
            return Response(
              400,
              body:
                  jsonEncode({'error': 'Can only decline pending invitations'}),
              headers: {'Content-Type': 'application/json'},
            );
          }

          // Fetch sender info
          final senderResult = await database.query(
            'SELECT username FROM users WHERE id = @senderId',
            substitutionValues: {'senderId': senderId},
          );

          final senderUsername = senderResult.isNotEmpty
              ? senderResult[0][0] as String
              : 'Unknown';

          // Update invite status
          await database.execute(
            '''UPDATE invites SET status = 'declined', responded_at = NOW() WHERE id = @inviteId''',
            substitutionValues: {'inviteId': inviteId},
          );

          print('[InviteHandler] ✅ Invite declined: $inviteId');

          return Response.ok(
            jsonEncode({
              'id': inviteId,
              'senderId': senderId,
              'senderName': senderUsername,
              'senderAvatarUrl': null,
              'recipientId': recipientId,
              'status': 'declined',
              'createdAt': (row[4] as DateTime).toIso8601String(),
              'updatedAt': DateTime.now().toIso8601String(),
              'deletedAt': null,
            }),
            headers: {'Content-Type': 'application/json'},
          );
        } on AuthException catch (e) {
          return Response(
            401,
            body: jsonEncode({'error': 'Invalid token'}),
            headers: {'Content-Type': 'application/json'},
          );
        } catch (e) {
          print('[InviteHandler] ❌ Error declining invite: $e');
          return Response(
            400,
            body: jsonEncode({'error': e.toString()}),
            headers: {'Content-Type': 'application/json'},
          );
        }
      }

      // POST /api/invites/{inviteId}/cancel - Cancel a sent invite
      if (path.contains('api/invites/') &&
          path.endsWith('/cancel') &&
          method == 'POST') {
        print('[InviteHandler] Canceling invite');
        try {
          final authHeader = request.headers['authorization'];
          if (authHeader == null || !authHeader.startsWith('Bearer ')) {
            return Response(
              401,
              body: jsonEncode(
                  {'error': 'Missing or invalid authorization header'}),
              headers: {'Content-Type': 'application/json'},
            );
          }

          final token = authHeader.substring('Bearer '.length);
          final payload = JwtService.validateToken(token);
          final userId = payload.userId;

          final inviteId =
              path.replaceFirst('api/invites/', '').replaceFirst('/cancel', '');

          // Fetch full invite record
          final inviteResult = await database.query(
            'SELECT id, sender_id, receiver_id, status, created_at, responded_at, canceled_at FROM invites WHERE id = @inviteId',
            substitutionValues: {'inviteId': inviteId},
          );

          if (inviteResult.isEmpty) {
            return Response(
              404,
              body: jsonEncode({'error': 'Invite not found'}),
              headers: {'Content-Type': 'application/json'},
            );
          }

          final row = inviteResult[0];
          final senderId = row[1] as String;
          final receiverId = row[2] as String;
          final status = row[3] as String;

          // Only sender can cancel
          if (userId != senderId) {
            return Response(
              403,
              body: jsonEncode(
                  {'error': 'Only the sender can cancel this invitation'}),
              headers: {'Content-Type': 'application/json'},
            );
          }

          // Can only cancel pending invitations
          if (status != 'pending') {
            return Response(
              400,
              body:
                  jsonEncode({'error': 'Can only cancel pending invitations'}),
              headers: {'Content-Type': 'application/json'},
            );
          }

          // Fetch sender info
          final senderResult = await database.query(
            'SELECT username FROM users WHERE id = @senderId',
            substitutionValues: {'senderId': senderId},
          );

          final senderUsername = senderResult.isNotEmpty
              ? senderResult[0][0] as String
              : 'Unknown';

          // Update invite status
          await database.execute(
            '''UPDATE invites SET status = 'canceled', canceled_at = NOW() WHERE id = @inviteId''',
            substitutionValues: {'inviteId': inviteId},
          );

          print('[InviteHandler] ✅ Invite canceled: $inviteId');

          return Response.ok(
            jsonEncode({
              'id': inviteId,
              'senderId': senderId,
              'senderName': senderUsername,
              'senderAvatarUrl': null,
              'recipientId': receiverId,
              'status': 'canceled',
              'createdAt': (row[4] as DateTime).toIso8601String(),
              'updatedAt': DateTime.now().toIso8601String(),
              'deletedAt': null,
            }),
            headers: {'Content-Type': 'application/json'},
          );
        } on AuthException catch (e) {
          return Response(
            401,
            body: jsonEncode({'error': 'Invalid token'}),
            headers: {'Content-Type': 'application/json'},
          );
        } catch (e) {
          print('[InviteHandler] ❌ Error canceling invite: $e');
          return Response(
            400,
            body: jsonEncode({'error': e.toString()}),
            headers: {'Content-Type': 'application/json'},
          );
        }
      }

      // DELETE /api/chats/{chatId} - Delete a chat (remove connection)
      if (path.startsWith('api/chats/') &&
          !path.contains('/messages') &&
          !path.contains('/notification-settings') &&
          !path.contains('/archive') &&
          !path.contains('/unarchive') &&
          method == 'DELETE') {
        try {
          final authHeader = request.headers['authorization'];
          if (authHeader == null || !authHeader.startsWith('Bearer ')) {
            return Response(
              401,
              body: jsonEncode(
                  {'error': 'Missing or invalid authorization header'}),
              headers: {'Content-Type': 'application/json'},
            );
          }

          final token = authHeader.substring('Bearer '.length);
          final payload = JwtService.validateToken(token);
          final userId = payload.userId;

          // Extract chatId from path: api/chats/{chatId}
          final chatId = path.replaceFirst('api/chats/', '').split('/').first;

          // Check if user is a participant in the chat
          final chatResult = await database.query(
            r'SELECT participant_1_id, participant_2_id FROM chats WHERE id = @chatId',
            substitutionValues: {'chatId': chatId},
          );

          if (chatResult.isEmpty) {
            return Response(
              404,
              body: jsonEncode({'error': 'Chat not found'}),
              headers: {'Content-Type': 'application/json'},
            );
          }

          final row = chatResult[0];
          final participant1 = row[0] as String;
          final participant2 = row[1] as String;

          if (userId != participant1 && userId != participant2) {
            return Response(
              403,
              body: jsonEncode({
                'error': 'Unauthorized - you are not a participant in this chat'
              }),
              headers: {'Content-Type': 'application/json'},
            );
          }

          // Soft-delete: mark chat as archived for this user by setting the appropriate flag
          // Archive for the user (participant_1 or participant_2)
          final isParticipant1 = userId == participant1;
          final archiveColumn = isParticipant1 ? 'is_participant_1_archived' : 'is_participant_2_archived';
          
          await database.execute(
            'UPDATE chats SET $archiveColumn = true WHERE id = @chatId',
            substitutionValues: {'chatId': chatId},
          );

          return Response(204);
        } on AuthException catch (e) {
          return Response(
            401,
            body: jsonEncode({'error': 'Invalid token'}),
            headers: {'Content-Type': 'application/json'},
          );
        } catch (e) {
          print('[ChatHandler] ❌ Error deleting chat: $e');
          return Response(
            500,
            body: jsonEncode({'error': 'Failed to delete chat: $e'}),
            headers: {'Content-Type': 'application/json'},
          );
        }
      }

      // Chat API endpoints (019-chat-list feature)
      // WebSocket endpoint for real-time messaging (T034, T035)
      // GET /ws/messages - Upgrade to WebSocket, authenticate, handle real-time events
      if (path == 'ws/messages' && method == 'GET') {
        try {
          // Let shelf_web_socket handle the upgrade, pass database for handler to use
          final wsHandler = WebSocketHandler.createWebSocketHandler(database,
              request: request);
          return await wsHandler(request);
        } catch (e) {
          print('[WebSocket] ❌ Error in WebSocket handler: $e');
          return Response.internalServerError(
            body: jsonEncode({'error': 'WebSocket error: $e'}),
            headers: {'Content-Type': 'application/json'},
          );
        }
      }

      // GET /api/chats - Fetch active chats for current user
      if (path == 'api/chats' && method == 'GET') {
        try {
          final authHeader = request.headers['authorization'];
          if (authHeader == null || !authHeader.startsWith('Bearer ')) {
            return Response(
              401,
              body: jsonEncode(
                  {'error': 'Missing or invalid authorization header'}),
              headers: {'Content-Type': 'application/json'},
            );
          }

          final token = authHeader.substring('Bearer '.length);
          final payload = JwtService.validateToken(token);
          final userId = payload.userId;

          // Import ChatHandlers to use
          final chatHandlers = ChatHandlers(database);

          // Add userId to request context
          final requestWithContext = request.change(
            context: {...request.context, 'userId': userId},
          );

          return await chatHandlers.getChats(requestWithContext);
        } on AuthException catch (e) {
          return Response(
            401,
            body: jsonEncode({'error': 'Invalid token'}),
            headers: {'Content-Type': 'application/json'},
          );
        } catch (e) {
          print('[ChatHandler] ❌ Error fetching chats: $e');
          return Response(
            500,
            body: jsonEncode({'error': 'Failed to fetch chats: $e'}),
            headers: {'Content-Type': 'application/json'},
          );
        }
      }

      // GET /api/chats/archived - Fetch archived chats for current user (check BEFORE other /api/chats/* routes)
      if (path == 'api/chats/archived' && method == 'GET') {
        if (_verboseBackendLogs) {
          print('[ROUTE MATCH] archived chats route matched');
        }
        try {
          final authHeader = request.headers['authorization'];
          if (authHeader == null || !authHeader.startsWith('Bearer ')) {
            return Response(
              401,
              body: jsonEncode(
                  {'error': 'Missing or invalid authorization header'}),
              headers: {'Content-Type': 'application/json'},
            );
          }

          final token = authHeader.substring('Bearer '.length);
          final payload = JwtService.validateToken(token);
          final userId = payload.userId;

          final chatService = ChatService(database);
          final archivedChats = await chatService.getArchivedChats(userId);

          return Response.ok(
            jsonEncode({
              'chats': archivedChats.map((c) => c.toJson()).toList(),
              'total': archivedChats.length,
            }),
            headers: {'Content-Type': 'application/json'},
          );
        } on AuthException catch (e) {
          return Response(
            401,
            body: jsonEncode({'error': 'Invalid token'}),
            headers: {'Content-Type': 'application/json'},
          );
        } catch (e) {
          print('[ChatHandler] ❌ Error fetching archived chats: $e');
          return Response(
            500,
            body: jsonEncode({'error': 'Failed to fetch archived chats: $e'}),
            headers: {'Content-Type': 'application/json'},
          );
        }
      }

      // GET /api/chats/{chatId}/messages - Fetch message history
      if (path.startsWith('api/chats/') &&
          path.endsWith('/messages') &&
          method == 'GET') {
        try {
          final authHeader = request.headers['authorization'];
          if (authHeader == null || !authHeader.startsWith('Bearer ')) {
            return Response(
              401,
              body: jsonEncode(
                  {'error': 'Missing or invalid authorization header'}),
              headers: {'Content-Type': 'application/json'},
            );
          }

          final token = authHeader.substring('Bearer '.length);
          final payload = JwtService.validateToken(token);
          final userId = payload.userId;

          // Extract chatId from path: api/chats/{chatId}/messages
          final chatId =
              path.replaceFirst('api/chats/', '').replaceFirst('/messages', '');

          // Import ChatHandlers to use
          final chatHandlers = ChatHandlers(database);

          // Add userId to request context
          final requestWithContext = request.change(
            context: {...request.context, 'userId': userId},
          );

          return await chatHandlers.getMessages(requestWithContext, chatId);
        } on AuthException catch (e) {
          return Response(
            401,
            body: jsonEncode({'error': 'Invalid token'}),
            headers: {'Content-Type': 'application/json'},
          );
        } catch (e) {
          print('[ChatHandler] ❌ Error fetching messages: $e');
          return Response(
            500,
            body: jsonEncode({'error': 'Failed to fetch messages: $e'}),
            headers: {'Content-Type': 'application/json'},
          );
        }
      }

      // POST /api/chats/{chatId}/messages - Send a message (T028-T029)
      if (path.startsWith('api/chats/') &&
          path.endsWith('/messages') &&
          method == 'POST') {
        try {
          // Extract chatId from path: api/chats/{chatId}/messages
          final chatId =
              path.replaceFirst('api/chats/', '').replaceFirst('/messages', '');

          return await MessageHandlers.sendMessage(request, chatId, database);
        } on AuthException catch (e) {
          return Response(
            401,
            body: jsonEncode({'error': 'Invalid token'}),
            headers: {'Content-Type': 'application/json'},
          );
        } catch (e) {
          print('[MessageHandler] ❌ Error sending message: $e');
          return Response(
            500,
            body: jsonEncode({'error': 'Failed to send message: $e'}),
            headers: {'Content-Type': 'application/json'},
          );
        }
      }

      // PUT /api/chats/{chatId}/messages/{messageId} - Edit a message (T049)
      if (path.startsWith('api/chats/') &&
          path.contains('/messages/') &&
          !path.endsWith('/status') &&
          !path.contains('/messages/') &&
          path != path.replaceAll(RegExp(r'/messages/[^/]+$'), '/messages/X') &&
          method == 'PUT') {
        try {
          final parts = path.split('/');
          // Path format: api/chats/{chatId}/messages/{messageId}
          if (parts.length >= 5 &&
              parts[0] == 'api' &&
              parts[1] == 'chats' &&
              parts[3] == 'messages') {
            final chatId = parts[2];
            final messageId = parts[4];
            return await MessageHandlers.editMessage(
                request, chatId, messageId, database);
          }
        } on AuthException catch (e) {
          return Response(
            401,
            body: jsonEncode({'error': 'Invalid token'}),
            headers: {'Content-Type': 'application/json'},
          );
        } catch (e) {
          print('[MessageHandler] ❌ Error editing message: $e');
          return Response(
            500,
            body: jsonEncode({'error': 'Failed to edit message: $e'}),
            headers: {'Content-Type': 'application/json'},
          );
        }
      }

      // DELETE /api/chats/{chatId}/messages/{messageId} - Delete a message (T060)
      if (path.startsWith('api/chats/') &&
          path.contains('/messages/') &&
          !path.endsWith('/status') &&
          method == 'DELETE') {
        try {
          final parts = path.split('/');
          // Path format: api/chats/{chatId}/messages/{messageId}
          if (parts.length >= 5 &&
              parts[0] == 'api' &&
              parts[1] == 'chats' &&
              parts[3] == 'messages') {
            final chatId = parts[2];
            final messageId = parts[4];
            return await MessageHandlers.deleteMessage(
                request, chatId, messageId, database);
          }
        } on AuthException catch (e) {
          return Response(
            401,
            body: jsonEncode({'error': 'Invalid token'}),
            headers: {'Content-Type': 'application/json'},
          );
        } catch (e) {
          print('[MessageHandler] ❌ Error deleting message: $e');
          return Response(
            500,
            body: jsonEncode({'error': 'Failed to delete message: $e'}),
            headers: {'Content-Type': 'application/json'},
          );
        }
      }

      // PUT /api/chats/{chatId}/messages/status - Update message status (T020 - Message Status System)
      if (path.startsWith('api/chats/') &&
          path.endsWith('/messages/status') &&
          method == 'PUT') {
        try {
          final parts = path.split('/');
          // Path format: api/chats/{chatId}/messages/status
          if (parts.length >= 4 &&
              parts[0] == 'api' &&
              parts[1] == 'chats' &&
              parts[3] == 'messages') {
            final chatId = parts[2];
            return await MessageHandlers.updateMessageStatus(
                request, chatId, database);
          }
        } on AuthException catch (e) {
          return Response(
            401,
            body: jsonEncode({'error': 'Invalid token'}),
            headers: {'Content-Type': 'application/json'},
          );
        } catch (e) {
          print('[MessageHandler] ❌ Error updating message status: $e');
          return Response(
            500,
            body: jsonEncode({'error': 'Failed to update message status: $e'}),
            headers: {'Content-Type': 'application/json'},
          );
        }
      }

      // POST /api/media/upload - Upload a media file (T070)
      if (path == 'api/media/upload' && method == 'POST') {
        try {
          return await MediaHandlers.uploadMedia(request, database);
        } on AuthException catch (e) {
          return Response(
            401,
            body: jsonEncode({'error': 'Invalid token'}),
            headers: {'Content-Type': 'application/json'},
          );
        } catch (e) {
          print('[MediaHandler] ❌ Error uploading media: $e');
          return Response(
            500,
            body: jsonEncode({'error': 'Failed to upload media: $e'}),
            headers: {'Content-Type': 'application/json'},
          );
        }
      }

      // GET /api/media/{mediaId}/download - Download a media file (T071)
      if (path.startsWith('api/media/') &&
          path.contains('/download') &&
          method == 'GET') {
        try {
          final parts = path.split('/');
          // Path format: api/media/{mediaId}/download
          if (parts.length >= 4 &&
              parts[0] == 'api' &&
              parts[1] == 'media' &&
              parts[3] == 'download') {
            final mediaId = parts[2];
            return await MediaHandlers.downloadMedia(request, mediaId);
          }
        } on AuthException catch (e) {
          return Response(
            401,
            body: jsonEncode({'error': 'Invalid token'}),
            headers: {'Content-Type': 'application/json'},
          );
        } catch (e) {
          print('[MediaHandler] ❌ Error downloading media: $e');
          return Response(
            500,
            body: jsonEncode({'error': 'Failed to download media: $e'}),
            headers: {'Content-Type': 'application/json'},
          );
        }
      }

      // PUT /api/messages/{messageId}/attach-media - Attach media to a message (T072)
      if (path.startsWith('api/messages/') &&
          path.contains('/attach-media') &&
          method == 'PUT') {
        try {
          final parts = path.split('/');
          // Path format: api/messages/{messageId}/attach-media
          if (parts.length >= 4 &&
              parts[0] == 'api' &&
              parts[1] == 'messages' &&
              parts[3] == 'attach-media') {
            final messageId = parts[2];
            return await MediaHandlers.attachMediaToMessage(
                request, messageId, database);
          }
        } on AuthException catch (e) {
          return Response(
            401,
            body: jsonEncode({'error': 'Invalid token'}),
            headers: {'Content-Type': 'application/json'},
          );
        } catch (e) {
          print('[MediaHandler] ❌ Error attaching media: $e');
          return Response(
            500,
            body: jsonEncode({'error': 'Failed to attach media: $e'}),
            headers: {'Content-Type': 'application/json'},
          );
        }
      }

      // POST /api/notifications/device-token - Register current device for notifications.
      if (path == 'api/notifications/device-token' && method == 'POST') {
        try {
          final authHeader = request.headers['authorization'];
          if (authHeader == null || !authHeader.startsWith('Bearer ')) {
            return Response(
              401,
              body: jsonEncode(
                  {'error': 'Missing or invalid authorization header'}),
              headers: {'Content-Type': 'application/json'},
            );
          }

          final token = authHeader.substring('Bearer '.length);
          final payload = JwtService.validateToken(token);
          final body =
              jsonDecode(await request.readAsString()) as Map<String, dynamic>;
          final deviceToken = body['token'] as String?;
          final platform = body['platform'] as String?;

          if (deviceToken == null || deviceToken.isEmpty) {
            return Response(
              400,
              body: jsonEncode({'error': 'token is required'}),
              headers: {'Content-Type': 'application/json'},
            );
          }

          final notificationService = NotificationService(database);
          await notificationService.upsertDeviceToken(
            userId: payload.userId,
            token: deviceToken,
            platform: platform,
          );

          return Response(204);
        } on AuthException {
          return Response(
            401,
            body: jsonEncode({'error': 'Invalid token'}),
            headers: {'Content-Type': 'application/json'},
          );
        } catch (e) {
          return Response(
            500,
            body: jsonEncode({'error': 'Failed to register device token: $e'}),
            headers: {'Content-Type': 'application/json'},
          );
        }
      }

      // GET /api/notifications/muted-chats - Fetch all muted chat ids for current user.
      if (path == 'api/notifications/muted-chats' && method == 'GET') {
        try {
          final authHeader = request.headers['authorization'];
          if (authHeader == null || !authHeader.startsWith('Bearer ')) {
            return Response(
              401,
              body: jsonEncode(
                  {'error': 'Missing or invalid authorization header'}),
              headers: {'Content-Type': 'application/json'},
            );
          }

          final token = authHeader.substring('Bearer '.length);
          final payload = JwtService.validateToken(token);
          final chatService = ChatService(database);
          final mutedChatIds =
              await chatService.getMutedChatIds(payload.userId);

          return Response.ok(
            jsonEncode({'chat_ids': mutedChatIds}),
            headers: {'Content-Type': 'application/json'},
          );
        } on AuthException {
          return Response(
            401,
            body: jsonEncode({'error': 'Invalid token'}),
            headers: {'Content-Type': 'application/json'},
          );
        } catch (e) {
          return Response(
            500,
            body: jsonEncode({'error': 'Failed to fetch muted chats: $e'}),
            headers: {'Content-Type': 'application/json'},
          );
        }
      }

      // GET /api/chats/{chatId}/notification-settings - Fetch per-chat notification preferences.
      if (path.startsWith('api/chats/') &&
          path.endsWith('/notification-settings') &&
          method == 'GET') {
        try {
          final authHeader = request.headers['authorization'];
          if (authHeader == null || !authHeader.startsWith('Bearer ')) {
            return Response(
              401,
              body: jsonEncode(
                  {'error': 'Missing or invalid authorization header'}),
              headers: {'Content-Type': 'application/json'},
            );
          }

          final token = authHeader.substring('Bearer '.length);
          final payload = JwtService.validateToken(token);
          final chatId = path
              .replaceFirst('api/chats/', '')
              .replaceFirst('/notification-settings', '');
          final chatService = ChatService(database);
          final isMuted = await chatService.isChatMuted(chatId, payload.userId);

          return Response.ok(
            jsonEncode({'chat_id': chatId, 'is_muted': isMuted}),
            headers: {'Content-Type': 'application/json'},
          );
        } on AuthException {
          return Response(
            401,
            body: jsonEncode({'error': 'Invalid token'}),
            headers: {'Content-Type': 'application/json'},
          );
        } catch (e) {
          return Response(
            500,
            body: jsonEncode(
                {'error': 'Failed to fetch notification settings: $e'}),
            headers: {'Content-Type': 'application/json'},
          );
        }
      }

      // PUT /api/chats/{chatId}/notification-settings - Update per-chat notification preferences.
      if (path.startsWith('api/chats/') &&
          path.endsWith('/notification-settings') &&
          method == 'PUT') {
        try {
          final authHeader = request.headers['authorization'];
          if (authHeader == null || !authHeader.startsWith('Bearer ')) {
            return Response(
              401,
              body: jsonEncode(
                  {'error': 'Missing or invalid authorization header'}),
              headers: {'Content-Type': 'application/json'},
            );
          }

          final token = authHeader.substring('Bearer '.length);
          final payload = JwtService.validateToken(token);
          final body =
              jsonDecode(await request.readAsString()) as Map<String, dynamic>;
          final isMuted = body['is_muted'] as bool?;
          if (isMuted == null) {
            return Response(
              400,
              body: jsonEncode({'error': 'is_muted is required'}),
              headers: {'Content-Type': 'application/json'},
            );
          }

          final chatId = path
              .replaceFirst('api/chats/', '')
              .replaceFirst('/notification-settings', '');
          final chatService = ChatService(database);
          final updated =
              await chatService.setChatMuted(chatId, payload.userId, isMuted);

          return Response.ok(
            jsonEncode({'chat_id': chatId, 'is_muted': updated}),
            headers: {'Content-Type': 'application/json'},
          );
        } on AuthException {
          return Response(
            401,
            body: jsonEncode({'error': 'Invalid token'}),
            headers: {'Content-Type': 'application/json'},
          );
        } catch (e) {
          return Response(
            500,
            body: jsonEncode(
                {'error': 'Failed to update notification settings: $e'}),
            headers: {'Content-Type': 'application/json'},
          );
        }
      }

      // PUT /api/chats/{chatId}/archive - Archive a chat for current user
      if (path.startsWith('api/chats/') &&
          path.endsWith('/archive') &&
          method == 'PUT') {
        try {
          final authHeader = request.headers['authorization'];
          if (authHeader == null || !authHeader.startsWith('Bearer ')) {
            return Response(
              401,
              body: jsonEncode(
                  {'error': 'Missing or invalid authorization header'}),
              headers: {'Content-Type': 'application/json'},
            );
          }

          final token = authHeader.substring('Bearer '.length);
          final payload = JwtService.validateToken(token);
          final userId = payload.userId;

          // Extract chatId from path: api/chats/{chatId}/archive
          final chatId =
              path.replaceFirst('api/chats/', '').replaceFirst('/archive', '');

          final chatService = ChatService(database);
          final updated = await chatService.archiveChat(chatId, userId);

          return Response.ok(
            jsonEncode(updated.toJson()),
            headers: {'Content-Type': 'application/json'},
          );
        } on AuthException catch (e) {
          return Response(
            401,
            body: jsonEncode({'error': 'Invalid token'}),
            headers: {'Content-Type': 'application/json'},
          );
        } catch (e) {
          print('[ChatHandler] ❌ Error archiving chat: $e');
          return Response(
            500,
            body: jsonEncode({'error': 'Failed to archive chat: $e'}),
            headers: {'Content-Type': 'application/json'},
          );
        }
      }

      // PUT /api/chats/{chatId}/unarchive - Unarchive a chat for current user
      if (path.startsWith('api/chats/') &&
          path.endsWith('/unarchive') &&
          method == 'PUT') {
        try {
          final authHeader = request.headers['authorization'];
          if (authHeader == null || !authHeader.startsWith('Bearer ')) {
            return Response(
              401,
              body: jsonEncode(
                  {'error': 'Missing or invalid authorization header'}),
              headers: {'Content-Type': 'application/json'},
            );
          }

          final token = authHeader.substring('Bearer '.length);
          final payload = JwtService.validateToken(token);
          final userId = payload.userId;

          // Extract chatId from path: api/chats/{chatId}/unarchive
          final chatId = path
              .replaceFirst('api/chats/', '')
              .replaceFirst('/unarchive', '');

          final chatService = ChatService(database);
          final updated = await chatService.unarchiveChat(chatId, userId);

          return Response.ok(
            jsonEncode(updated.toJson()),
            headers: {'Content-Type': 'application/json'},
          );
        } on AuthException catch (e) {
          return Response(
            401,
            body: jsonEncode({'error': 'Invalid token'}),
            headers: {'Content-Type': 'application/json'},
          );
        } catch (e) {
          print('[ChatHandler] ❌ Error unarchiving chat: $e');
          return Response(
            500,
            body: jsonEncode({'error': 'Failed to unarchive chat: $e'}),
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
        body: jsonEncode(
            {'error': 'Internal server error', 'message': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  };
}

/// Logging middleware that skips health checks to reduce log noise
Middleware _logRequestsExceptHealth() {
  return (Handler innerHandler) {
    return (Request request) async {
      final path = request.url.path;
      // Skip logging for health checks
      if (path == '/health' || path == 'health') {
        return await innerHandler(request);
      }
      // Log other requests
      return await logRequests()(innerHandler)(request);
    };
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
Future<Response> _handleRegister(
  Request request,
  Connection database,
  TokenService tokenService,
  EmailService emailService,
  VerificationService verificationService,
) async {
  // Validate required fields
  final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
  final email = (body['email'] as String?).toString().toLowerCase();
  final username = body['username'] as String?;
  final password = body['password'] as String?;
  print(
      '[Register] Incoming registration request: email=$email, username=$username');
  try {
    // ...existing code...

    // Validate required fields
    if (email.isEmpty) {
      return Response(
        400,
        body: jsonEncode({
          'error': 'Validation failed',
          'details': ['Email is required']
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }
    if (username?.isEmpty ?? true) {
      return Response(
        400,
        body: jsonEncode({
          'error': 'Validation failed',
          'details': ['Username is required']
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }
    if (password?.isEmpty ?? true) {
      return Response(
        400,
        body: jsonEncode({
          'error': 'Validation failed',
          'details': ['Password is required']
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }

    // Validate password strength
    final passwordErrors = _validatePasswordStrength(password!);
    if (passwordErrors.isNotEmpty) {
      return Response(
        400,
        body: jsonEncode(
            {'error': 'Password validation failed', 'details': passwordErrors}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    // Check for duplicate email in database
    final emailCheck = await database.query(
      'SELECT email FROM "users" WHERE email = @email',
      substitutionValues: {'email': email},
    );
    print(
        '[Register] Email check results: ${emailCheck.map((row) => row.toColumnMap()).toList()}');
    if (emailCheck.isNotEmpty) {
      print('[Register] Email already registered: $email');
      return Response(
        409,
        body: jsonEncode({'error': 'Email already registered'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
    // Check for duplicate username in database
    final usernameCheck = await database.query(
      'SELECT username FROM "users" WHERE username = @username',
      substitutionValues: {'username': username},
    );
    print(
        '[Register] Username check results: ${usernameCheck.map((row) => row.toColumnMap()).toList()}');
    if (usernameCheck.isNotEmpty) {
      print('[Register] Username already taken: $username');
      return Response(
        409,
        body: jsonEncode({'error': 'Username already taken'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
    final passwordHash = _hashPassword(password!);
    final userId = const Uuid().v4(); // Just UUID, no prefix
    print(
        '[Register] Creating new user: email=$email, username=$username, userId=$userId');

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

    print('[Register] Registration successful: userId=$userId');

    // Auto-send verification email
    String? devToken;
    try {
      final token =
          await verificationService.createVerificationToken(userId).timeout(
                const Duration(seconds: 3),
                onTimeout: () => throw TimeoutException(
                  'Verification token creation timed out',
                ),
              );
      final appBaseUrl =
          Platform.environment['APP_BASE_URL'] ?? 'http://localhost:8081';
      final verificationLink =
          '$appBaseUrl/auth/verify-email/confirm?token=$token';
      final emailMsg = emailService.buildVerificationEmail(
        recipientEmail: email,
        recipientName: username!,
        verificationLink: verificationLink,
        expiresIn: '24 hours',
        registeredAt: DateTime.now()
                .toUtc()
                .toString()
                .substring(0, 19)
                .replaceAll('T', ' ') +
            ' UTC',
      );
      devToken = token; // kept for dev response
      await emailService.sendEmail(emailMsg);
      print('[Register] Verification email dispatched to $email');
    } catch (emailErr) {
      print('[Register][WARNING] Could not send verification email: $emailErr');
      // Ensure account is not left behind when verification cannot be delivered.
      try {
        await database.execute(
          'DELETE FROM "users" WHERE id = @id',
          substitutionValues: {'id': userId},
        );
      } catch (cleanupErr) {
        print(
            '[Register][WARNING] Failed to rollback user after email failure: $cleanupErr');
      }
      return Response(
        502,
        body: jsonEncode({
          'error':
              'Account created, but verification email failed to send. Check SMTP sender configuration and retry.',
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }

    final bool isDev = !bool.fromEnvironment('dart.vm.product');
    final responseBody = <String, dynamic>{
      'user_id': userId,
      'email': email,
      'username': username,
    };
    if (isDev && devToken != null) {
      responseBody['dev_verification_token'] = devToken;
      responseBody['dev_note'] =
          'Development mode: use this token with POST /auth/verify-email/confirm {"token":"..."}';
    }

    return Response(
      201,
      body: jsonEncode(responseBody),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e, st) {
    print('[ERROR] Registration error: $e');
    print('[ERROR] Stack: $st');
    return Response(
      500,
      body: jsonEncode({'error': 'Server error - please try again later'}),
      headers: {'Content-Type': 'application/json'},
    );
  }
}

/// Handle POST /auth/login
Future<Response> _handleLogin(Request request, Connection database) async {
  try {
    final body =
        jsonDecode(await request.readAsString()) as Map<String, dynamic>;

    final email = (body['email'] as String?).toString().toLowerCase();
    final password = body['password'] as String?;

    if (email.isEmpty) {
      return Response(
        400,
        body: jsonEncode({
          'error': 'Validation failed',
          'details': ['Email is required']
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }
    if (password?.isEmpty ?? true) {
      return Response(
        400,
        body: jsonEncode({
          'error': 'Validation failed',
          'details': ['Password is required']
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }

    // Query database for user by email
    final result = await database.query(
      'SELECT id, email, username, password_hash, email_verified FROM "users" WHERE email = @email',
      substitutionValues: {'email': email},
    );

    if (result.isEmpty) {
      return Response(
        401,
        body: jsonEncode({'error': 'Invalid email or password'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    final user = result.first.toColumnMap();
    final storedHash = user['password_hash'] as String;

    // Verify password
    if (!_verifyPassword(password!, storedHash)) {
      return Response(
        401,
        body: jsonEncode({'error': 'Invalid email or password'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    final emailVerified = user['email_verified'] as bool? ?? false;
    if (!emailVerified) {
      return Response(
        403,
        body: jsonEncode({
          'error':
              'Email not verified. Please verify your email before logging in.'
        }),
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
    return Response(
      500,
      body: jsonEncode({'error': 'Server error - please try again later'}),
      headers: {'Content-Type': 'application/json'},
    );
  }
}

/// Handle GET /auth/me (protected)
Future<Response> _handleValidateSession(
    Request request, Connection database) async {
  try {
    final authHeader = request.headers['authorization'];
    if (authHeader == null || !authHeader.startsWith('Bearer ')) {
      return Response(
        401,
        body: jsonEncode({'error': 'Missing or invalid authorization header'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    // Validate JWT token
    try {
      final token = authHeader.substring('Bearer '.length);
      final payload = JwtService.validateToken(token);

      final result = await database.query(
        'SELECT email_verified FROM "users" WHERE id = @id',
        substitutionValues: {'id': payload.userId},
      );

      if (result.isEmpty) {
        return Response(
          401,
          body: jsonEncode({'error': 'Invalid token'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final userRow = result.first.toColumnMap();
      final emailVerified = userRow['email_verified'] as bool? ?? false;
      if (!emailVerified) {
        return Response(
          401,
          body: jsonEncode({'error': 'Email not verified'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      return Response.ok(
        jsonEncode({
          'is_authenticated': true,
          'user_id': payload.userId,
          'email': payload.email,
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } on AuthException catch (e) {
      return Response(
        401,
        body: jsonEncode({'error': 'Invalid token'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  } catch (e) {
    print('[ERROR] Session validation error: $e');
    return Response(
      500,
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
      return Response(
        401,
        body: jsonEncode({'error': 'Not authenticated'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    return Response.ok(
      jsonEncode({'message': 'Logged out successfully'}),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e) {
    return Response(
      500,
      body: jsonEncode({'error': 'Server error'}),
      headers: {'Content-Type': 'application/json'},
    );
  }
}

/// Validate password strength
List<String> _validatePasswordStrength(String password) {
  final errors = <String>[];

  if (password.length < 8) errors.add('Password must be at least 8 characters');
  if (!password.contains(RegExp(r'[a-z]')))
    errors.add('Password must contain a lowercase letter');
  if (!password.contains(RegExp(r'[A-Z]')))
    errors.add('Password must contain an uppercase letter');
  if (!password.contains(RegExp(r'[0-9]')))
    errors.add('Password must contain a digit');
  if (!password.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]')))
    errors.add('Password must contain a special character');

  return errors;
}

/// Handle search by username (mock implementation)
/// Handle search by username (real database query)
Future<Response> _handleSearchByUsername(
    Request request, Connection database) async {
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
          body: jsonEncode(
              {'error': 'Invalid limit parameter: must be an integer'}),
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
        body:
            jsonEncode({'error': 'Search query cannot exceed 100 characters'}),
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
Future<Response> _handleSearchByEmail(
    Request request, Connection database) async {
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
          body: jsonEncode(
              {'error': 'Invalid limit parameter: must be an integer'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    }

    // Validate query
    final trimmed = query.trim();
    if (trimmed.length < 2) {
      return Response.badRequest(
        body:
            jsonEncode({'error': 'Search query must be at least 2 characters'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
    // Allow partial email searches - just need @ or . (e.g., "alice.", "alice@", "alice.smith")
    if (!trimmed.contains('@') && !trimmed.contains('.')) {
      return Response.badRequest(
        body: jsonEncode({
          'error': 'Email search must contain @ or . for email-like queries'
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }
    if (trimmed.length > 100) {
      return Response.badRequest(
        body:
            jsonEncode({'error': 'Search query cannot exceed 100 characters'}),
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

/// Serve static files from the uploads directory
Response _serveStaticFile(Request request, String path) {
  try {
    // Security: prevent directory traversal attacks
    if (path.contains('..') || path.startsWith('/')) {
      return Response.forbidden(
        jsonEncode({'error': 'Access denied'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    // Construct file path
    final file = File(path);

    print('[StaticFileServer] Attempting to serve: $path');
    print('[StaticFileServer] Absolute path: ${file.absolute.path}');

    // Check if file exists
    if (!file.existsSync()) {
      print('[StaticFileServer] ❌ File not found: $path');
      // List directory contents for debugging
      final dir = Directory('uploads/profile_pictures');
      if (dir.existsSync()) {
        try {
          final files = dir.listSync();
          print(
              '[StaticFileServer] Files in uploads/profile_pictures: ${files.map((f) => f.path).toList()}');
        } catch (e) {
          print('[StaticFileServer] Error listing directory: $e');
        }
      }

      return Response.notFound(
        jsonEncode({'error': 'File not found', 'path': path}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    // Check if it's actually a file (not a directory)
    if (file.statSync().type == FileSystemEntityType.directory) {
      return Response.forbidden(
        jsonEncode({'error': 'Access denied'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    final stat = file.statSync();
    final totalLength = stat.size;

    // Determine content type based on file extension
    final ext = path.split('.').last.toLowerCase();
    String contentType = 'application/octet-stream';

    switch (ext) {
      case 'jpg':
      case 'jpeg':
        contentType = 'image/jpeg';
        break;
      case 'png':
        contentType = 'image/png';
        break;
      case 'gif':
        contentType = 'image/gif';
        break;
      case 'webp':
        contentType = 'image/webp';
        break;
      case 'mp4':
        contentType = 'video/mp4';
        break;
      case 'mov':
        contentType = 'video/quicktime';
        break;
      case 'avi':
        contentType = 'video/x-msvideo';
        break;
      case 'wav':
        contentType = 'audio/wav';
        break;
      case 'mp3':
        contentType = 'audio/mpeg';
        break;
      case 'm4a':
        contentType = 'audio/x-m4a';
        break;
      case 'aac':
        contentType = 'audio/aac';
        break;
      default:
        contentType = 'application/octet-stream';
    }

    final rangeHeader = request.headers['range'];
    final commonHeaders = {
      'Content-Type': contentType,
      'Cache-Control': 'public, max-age=31536000',
      'Accept-Ranges': 'bytes',
    };

    if (rangeHeader != null && rangeHeader.startsWith('bytes=')) {
      final match = RegExp(r'^bytes=(\d*)-(\d*)$').firstMatch(rangeHeader);
      if (match == null) {
        return Response(
          416,
          headers: {
            ...commonHeaders,
            'Content-Range': 'bytes */$totalLength',
          },
        );
      }

      final startGroup = match.group(1);
      final endGroup = match.group(2);

      int start;
      int end;

      if ((startGroup == null || startGroup.isEmpty) &&
          (endGroup == null || endGroup.isEmpty)) {
        return Response(
          416,
          headers: {
            ...commonHeaders,
            'Content-Range': 'bytes */$totalLength',
          },
        );
      }

      if (startGroup == null || startGroup.isEmpty) {
        final suffixLength = int.parse(endGroup!);
        start = (totalLength - suffixLength).clamp(0, totalLength - 1);
        end = totalLength - 1;
      } else {
        start = int.parse(startGroup);
        end = endGroup == null || endGroup.isEmpty
            ? totalLength - 1
            : int.parse(endGroup);
      }

      if (start < 0 || start >= totalLength || end < start) {
        return Response(
          416,
          headers: {
            ...commonHeaders,
            'Content-Range': 'bytes */$totalLength',
          },
        );
      }

      if (end >= totalLength) {
        end = totalLength - 1;
      }

      final stream = file.openRead(start, end + 1);
      final chunkLength = end - start + 1;

      print('[✓] Serving range: $path ($start-$end/$totalLength)');

      return Response(
        206,
        body: stream,
        headers: {
          ...commonHeaders,
          'Content-Length': '$chunkLength',
          'Content-Range': 'bytes $start-$end/$totalLength',
        },
      );
    }

    if (request.method == 'HEAD') {
      return Response.ok(
        null,
        headers: {
          ...commonHeaders,
          'Content-Length': '$totalLength',
        },
      );
    }

    // Read file bytes
    final bytes = file.readAsBytesSync();

    print('[✓] Serving: $path (${bytes.length} bytes)');

    return Response.ok(
      bytes,
      headers: commonHeaders,
    );
  } catch (e) {
    print('[StaticFileServer] Error serving file: $e');
    return Response.internalServerError(
      body: jsonEncode({
        'error': 'Failed to serve file',
        'message': e.toString(),
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }
}

/// Generate a random ID
String _generateId() {
  return const Uuid().v4();
}

/// Seed test users in the database for development
Future<void> _seedTestUsers(PostgreSQLConnection database) async {
  try {
    final testUsers = [
      {
        'username': 'alice',
        'email': 'alice@example.com',
        'password': 'alice123'
      },
      {'username': 'bob', 'email': 'bob@example.com', 'password': 'bob123'},
      {
        'username': 'charlie',
        'email': 'charlie@example.com',
        'password': 'charlie123'
      },
      {'username': 'diane', 'email': 'diane@test.org', 'password': 'diane123'},
    ];

    int created = 0;
    int updated = 0;
    for (final user in testUsers) {
      final username = user['username'] as String;
      final email = user['email'] as String;
      final password = user['password'] as String;
      final normalizedEmail = email.toLowerCase();
      final passwordHash = _hashPassword(password);

      // Check if user already exists
      final existing = await database.query(
        'SELECT id FROM "users" WHERE email = @email OR username = @username',
        substitutionValues: {'email': normalizedEmail, 'username': username},
      );

      if (existing.isNotEmpty) {
        final userId = existing.first[0] as String;
        await database.execute(
          '''UPDATE "users"
             SET email = @email,
                 username = @username,
                 password_hash = @password_hash,
                 email_verified = @email_verified
             WHERE id = @id''',
          substitutionValues: {
            'id': userId,
            'email': normalizedEmail,
            'username': username,
            'password_hash': passwordHash,
            'email_verified': true,
          },
        );
        print('[TestUsers] ↻ Synced @$username ($email)');
        updated++;
        continue;
      }

      try {
        final userId = const Uuid().v4();

        await database.execute(
          '''INSERT INTO "users" (id, email, username, password_hash, email_verified, created_at)
             VALUES (@id, @email, @username, @password_hash, @email_verified, @created_at)''',
          substitutionValues: {
            'id': userId,
            'email': normalizedEmail,
            'username': username,
            'password_hash': passwordHash,
            'email_verified': true,
            'created_at': DateTime.now().toUtc(),
          },
        );
        print('[TestUsers] ✓ Created @$username ($email)');
        created++;
      } catch (e) {
        print('[TestUsers] ✗ Failed to create @$username: $e');
      }
    }

    if (created > 0) {
      print('[TestUsers] Created $created test users');
    }
    if (updated > 0) {
      print('[TestUsers] Synced $updated existing test users');
    }
    if (created == 0 && updated == 0) {
      print('[TestUsers] All test users already exist');
    }
  } catch (e) {
    print('[TestUsers] ✗ Error seeding test users: $e');
  }
}

/// Helper: Convert database row to invitation JSON DTO
Map<String, dynamic> _invitationRowToJson(List<dynamic> row) {
  return {
    'id': row[0], // id
    'senderId': row[1], // sender_id
    'senderName': row[2], // sender_name
    'senderAvatarUrl': row[3], // sender_avatar
    'recipientId': row[4], // receiver_id
    'recipientName': row[5], // receiver_name
    'recipientAvatarUrl': row[6], // receiver_avatar
    'status': row[7], // status
    'createdAt': (row[8] as DateTime).toIso8601String(), // created_at
    'respondedAt': row[9] != null
        ? (row[9] as DateTime).toIso8601String()
        : null, // responded_at
    'canceledAt': row[10] != null
        ? (row[10] as DateTime).toIso8601String()
        : null, // canceled_at
  };
}

/// Unused - kept for reference
/// Each endpoint handles its own JWT validation
/// Pattern:
///   final token = authHeader.substring('Bearer '.length);
///   final payload = JwtService.validateToken(token);
///   final userId = payload.userId;
