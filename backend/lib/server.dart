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
import 'src/models/poll.dart';
import 'src/handlers/chat_handlers.dart';
import 'src/handlers/message_handlers.dart';
import 'src/handlers/media_handlers.dart';
import 'src/handlers/websocket_handler.dart';
import 'src/services/websocket_service.dart';
import 'src/services/poll_service.dart';
part 'src/server/middleware.dart';
part 'src/server/auth_handlers.dart';
part 'src/server/group_handlers.dart';
part 'src/server/search_handlers.dart';
part 'src/server/server_utils.dart';
part 'src/server/router.dart';
part 'src/server/invite_handlers.dart';
part 'src/server/chat_route_handlers.dart';

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
