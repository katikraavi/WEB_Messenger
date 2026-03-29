import 'dart:async';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:postgres/postgres.dart';
import 'src/database/database_connection_config.dart';
import 'src/services/token_service.dart';
import 'src/services/email_service.dart';
import 'src/services/rate_limit_service.dart';
import 'src/services/migration_runner.dart';
import 'src/services/jwt_service.dart';
import 'src/services/auth_exception.dart';
import 'src/services/password_reset_service.dart';
import 'src/services/chat_service.dart';
import 'src/services/encryption_service.dart';
import 'src/services/group_invite_service.dart';
import 'src/services/notification_service.dart';
import 'src/services/service_config.dart';
import 'src/services/search_service.dart';
import 'src/endpoints/verification_handler.dart';
import 'src/endpoints/password_reset_handler.dart';
import 'src/services/verification_service.dart';
import 'src/endpoints/profile.dart' as profileEndpoint;
import 'src/models/user_search_result.dart';
import 'src/models/chat_invite_model.dart';
import 'src/models/poll.dart';
import 'src/handlers/chat_handlers.dart';
import 'src/handlers/message_handlers.dart';
import 'src/handlers/media_handlers.dart';
import 'src/handlers/websocket_handler.dart';
import 'src/services/websocket_service.dart';
import 'src/services/poll_service.dart';
import 'src/endpoints/poll_endpoints.dart';

part 'src/server/middleware.dart';
part 'src/server/auth_handlers.dart';
part 'src/server/group_handlers.dart';
part 'src/server/search_handlers.dart';
part 'src/server/server_utils.dart';

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
  final isProduction = env == 'production';

  print('[INFO] Starting Messenger Server (environment: $env)');

  // Initialize database connection
  print('[INFO] Connecting to PostgreSQL database...');
  late Connection dbConnection;
  try {
    final databaseConfig = DatabaseConnectionConfig.fromEnvironment(
      Platform.environment,
    );
    print(
      '[INFO] Database target: ${databaseConfig.maskedDescription} '
      '(ssl: ${databaseConfig.requireSsl ? 'enabled' : 'disabled'})',
    );
    dbConnection = PostgreSQLConnection(
      databaseConfig.host,
      databaseConfig.port,
      databaseConfig.database,
      username: databaseConfig.username,
      password: databaseConfig.password,
      useSSL: databaseConfig.requireSsl,
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
  final smtpPort = int.tryParse(Platform.environment['SMTP_PORT'] ?? '');
  final smtpSecureRaw = Platform.environment['SMTP_SECURE']?.toLowerCase();
  final smtpSecure = smtpSecureRaw == 'true' ||
      (smtpSecureRaw == null && smtpPort == 465);
  final resendApiKey = Platform.environment['RESEND_API_KEY'];
  final resendFromEmail = Platform.environment['RESEND_FROM_EMAIL'];
  final emailService = EmailService(
    smtpHost: Platform.environment['SMTP_HOST'],
    smtpPort: smtpPort,
    senderEmail: Platform.environment['SMTP_FROM_EMAIL'],
    senderName: Platform.environment['SMTP_FROM_NAME'] ?? 'Mobile Messenger',
    smtpUser: Platform.environment['SMTP_USER'],
    smtpPassword: Platform.environment['SMTP_PASSWORD'],
    smtpSecure: smtpSecure,
    requireConfiguration: isProduction,
    resendApiKey: resendApiKey,
    resendFromEmail: resendFromEmail,
  );
  if (resendApiKey != null && resendApiKey.isNotEmpty) {
    print('[✓] Email: Resend HTTP API (bypasses SMTP port restrictions)');
  } else if (Platform.environment['SMTP_HOST'] != null) {
    print(
        '[✓] Email: SMTP → ${Platform.environment['SMTP_HOST']}:${Platform.environment['SMTP_PORT'] ?? '?'}');
  } else {
    print(
        '[INFO] Email: No provider configured — tokens returned in API response (dev mode)');
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

  // Initialize poll service
  final pollService = PollService(
    connection: dbConnection,
    encryptionService: encryptionService,
  );

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
        pollService,
      ));

  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);

  print('╔═══════════════════════════════════════════════════════╗');
  print('║ 🚀 Messenger Backend Started                          ║');
  print('║ Port: ${server.port}                                  ║');
  print('║ Health: http://localhost:${server.port}/health        ║');
  print('║ Schema: http://localhost:${server.port}/schema        ║');
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
  PollService pollService,
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

      // Compatibility routing for reverse proxies that only forward /api/*.
      if (path.startsWith('api/auth/') || path == 'api/auth') {
        path = path.replaceFirst('api/', '');
      }
      if (path.startsWith('api/ws/') || path == 'api/ws') {
        path = path.replaceFirst('api/', '');
      }

      if (_verboseBackendLogs) {
        print(
            '[DEBUG] Received request: $method /$path (raw: ${request.url.path})');
      }

      // Root endpoint (public)
      if (path.isEmpty && method == 'GET') {
        return Response.ok(
          jsonEncode({
            'service': 'messenger-backend',
            'status': 'healthy',
            'environment': Platform.environment['SERVERPOD_ENV'] ?? 'development',
            'timestamp': DateTime.now().toIso8601String(),
            'endpoints': {
              'health': '/health',
              'schema': '/schema',
            },
          }),
          headers: {'Content-Type': 'application/json'},
        );
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
        const res = await fetch('/api/auth/password-reset/confirm', {
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
        return await _handleLogin(request, database, tokenService);
      }

      // Auth endpoints (validate session - protected)
      if (path == 'auth/me' && method == 'GET') {
        return await _handleValidateSession(request, database);
      }

      // Auth endpoints (logout - protected)
      if (path == 'auth/logout' && method == 'POST') {
        return await _handleLogout(request, database, tokenService);
      }

      // Admin endpoints (manual user deletion; requires ADMIN_DELETE_KEY)
      if (path == 'api/admin/users/delete-preview' && method == 'POST') {
        return await _handleAdminDeletePreview(request, database);
      }

      if (path == 'api/admin/users/delete' && method == 'POST') {
        return await _handleAdminDeleteUser(request, database);
      }

      if (path == 'api/auth/sessions' && method == 'GET') {
        return await _handleListDeviceSessions(request, database, tokenService);
      }

      if (path.startsWith('api/auth/sessions/') && method == 'DELETE') {
        final deviceId = path.replaceFirst('api/auth/sessions/', '');
        return await _handleRevokeDeviceSession(
          request,
          database,
          tokenService,
          deviceId,
        );
      }

      if (path == 'api/groups' && method == 'POST') {
        return await _handleCreateGroup(request, database, encryptionService);
      }

      if (path == 'api/groups' && method == 'GET') {
        return await _handleListGroups(request, database, encryptionService);
      }

      if (path.startsWith('api/groups/') &&
          path.endsWith('/invite') &&
          method == 'POST') {
        final groupId =
            path.replaceFirst('api/groups/', '').replaceFirst('/invite', '');
        return await _handleSendGroupInvite(
          request,
          database,
          encryptionService,
          groupId,
        );
      }

      if (path.startsWith('api/groups/') &&
          path.endsWith('/members') &&
          method == 'GET') {
        final groupId =
            path.replaceFirst('api/groups/', '').replaceFirst('/members', '');
        return await _handleListGroupMembers(
          request,
          database,
          encryptionService,
          groupId,
        );
      }

      if (path.startsWith('api/groups/') &&
          path.endsWith('/invites') &&
          method == 'GET') {
        final groupId =
            path.replaceFirst('api/groups/', '').replaceFirst('/invites', '');
        return await _handleListGroupSentInvites(
          request,
          database,
          encryptionService,
          groupId,
        );
      }

      if (path.startsWith('api/groups/') &&
          path.endsWith('/leave') &&
          method == 'DELETE') {
        final groupId =
            path.replaceFirst('api/groups/', '').replaceFirst('/leave', '');
        return await _handleLeaveGroup(
          request,
          database,
          encryptionService,
          groupId,
        );
      }

      if (path.startsWith('api/groups/invites/') &&
          path.endsWith('/accept') &&
          method == 'PATCH') {
        final inviteId = path
            .replaceFirst('api/groups/invites/', '')
            .replaceFirst('/accept', '');
        return await _handleAcceptGroupInvite(
          request,
          database,
          encryptionService,
          inviteId,
        );
      }

      if (path.startsWith('api/groups/invites/') &&
          path.endsWith('/decline') &&
          method == 'PATCH') {
        final inviteId = path
            .replaceFirst('api/groups/invites/', '')
            .replaceFirst('/decline', '');
        return await _handleDeclineGroupInvite(
          request,
          database,
          encryptionService,
          inviteId,
        );
      }

      if (path.startsWith('api/groups/invites/') && method == 'DELETE') {
        final inviteId = path.replaceFirst('api/groups/invites/', '');
        return await _handleDeleteGroupInvite(
          request,
          database,
          encryptionService,
          inviteId,
        );
      }

      if (path == 'api/groups/invites/pending' && method == 'GET') {
        return await _handlePendingGroupInvites(
            request, database, encryptionService);
      }

      if (path.startsWith('api/groups/') && method == 'GET') {
        final groupId = path.replaceFirst('api/groups/', '');
        return await _handleGetGroupDetails(
          request,
          database,
          encryptionService,
          groupId,
        );
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

      if (path == 'api/messages/search' && method == 'GET') {
        return await _handleMessageSearch(request, database);
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
          final archiveColumn = isParticipant1
              ? 'is_participant_1_archived'
              : 'is_participant_2_archived';

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
          final chatHandlers = ChatHandlers(database, encryptionService);

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
          final chatHandlers = ChatHandlers(database, encryptionService);

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
          method == 'PUT') {
        try {
          print(
              '[MessageHandler] ✏️ Edit route matched: method=$method path=$path');
          final parts = path.split('/');
          // Path format: api/chats/{chatId}/messages/{messageId}
          if (parts.length == 5 &&
              parts[0] == 'api' &&
              parts[1] == 'chats' &&
              parts[3] == 'messages') {
            final chatId = parts[2];
            final messageId = parts[4];
            print(
                '[MessageHandler] ✏️ Dispatching edit: chatId=$chatId messageId=$messageId');
            return await MessageHandlers.editMessage(
                request, chatId, messageId, database);
          }
          print(
              '[MessageHandler] ⚠️ Edit route matched but path format was invalid: $path');
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
          print(
              '[MessageHandler] 🗑️ Delete route matched: method=$method path=$path');
          final parts = path.split('/');
          // Path format: api/chats/{chatId}/messages/{messageId}
          if (parts.length >= 5 &&
              parts[0] == 'api' &&
              parts[1] == 'chats' &&
              parts[3] == 'messages') {
            final chatId = parts[2];
            final messageId = parts[4];
            print(
                '[MessageHandler] 🗑️ Dispatching delete: chatId=$chatId messageId=$messageId');
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

      // Poll endpoints - create poll
      if (path == 'api/polls' && method == 'POST') {
        return await _handleCreatePoll(request, database, pollService);
      }

      // Poll endpoints - get poll
      if (path.startsWith('api/polls/') && method == 'GET' && !path.contains('/vote') && !path.contains('/close')) {
        final pollId = path.replaceFirst('api/polls/', '');
        return await _handleGetPoll(request, database, pollService, pollId);
      }

      // Poll endpoints - vote
      if (path.startsWith('api/polls/') && path.endsWith('/vote') && method == 'POST') {
        final pollId = path
            .replaceFirst('api/polls/', '')
            .replaceFirst('/vote', '');
        return await _handleVotePoll(request, database, pollService, pollId);
      }

      // Poll endpoints - retract vote
      if (path.startsWith('api/polls/') && path.endsWith('/vote') && method == 'DELETE') {
        final pollId = path
            .replaceFirst('api/polls/', '')
            .replaceFirst('/vote', '');
        return await _handleRetractVote(request, database, pollService, pollId);
      }

      // Poll endpoints - close poll
      if (path.startsWith('api/polls/') && path.endsWith('/close') && method == 'POST') {
        final pollId = path
            .replaceFirst('api/polls/', '')
            .replaceFirst('/close', '');
        return await _handleClosePoll(request, database, pollService, pollId);
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
