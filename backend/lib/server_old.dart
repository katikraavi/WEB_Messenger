import 'dart:async';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:postgres/postgres.dart';
import 'src/endpoints/auth.dart';
import 'src/services/user_auth_service.dart';
import 'src/middleware/jwt_middleware.dart';
import 'src/middleware/rate_limit_middleware.dart';

void main() async {
  final port = int.parse(Platform.environment['SERVERPOD_PORT'] ?? '8081');
  final env = Platform.environment['SERVERPOD_ENV'] ?? 'development';

  print('[INFO] Starting Messenger Server (environment: $env)');

  Connection? dbConnection;
  try {
    // Initialize database connection
    dbConnection = await Connection.open(
      Endpoint(
        host: Platform.environment['DATABASE_HOST'] ?? 'postgres',
        port: int.parse(Platform.environment['DATABASE_PORT'] ?? '5432'),
        database: Platform.environment['DATABASE_NAME'] ?? 'messenger_db',
        username: Platform.environment['DATABASE_USER'] ?? 'messenger_user',
        password: Platform.environment['DATABASE_PASSWORD'] ?? 'messenger_password',
      ),
    );

    print('[INFO] Connected to PostgreSQL database');

    // Initialize auth service
    final authService = UserAuthService(connection: dbConnection);

    // Initialize endpoints
    final authEndpoint = AuthEndpoint(authService: authService);

    // Setup middleware pipeline
    final handler = Pipeline()
        .addMiddleware(logRequests())
        .addMiddleware(_corsMiddleware())
        .addMiddleware(_createJwtMiddleware())
        .addMiddleware(_createRateLimitMiddleware())
        .addHandler((Request request) async {
      try {
        // Health check endpoint (public)
        if (request.url.path == '/health' && request.method == 'GET') {
          return Response.ok(
            '{"status":"healthy","timestamp":"${DateTime.now().toIso8601String()}"}',
            headers: {'Content-Type': 'application/json'},
          );
        }

        // Schema status endpoint (public)
        if (request.url.path == '/schema' && request.method == 'GET') {
          return Response.ok(
            '{"status":"Schema tables created via migrations: users, chats, chat_members, messages, invites"}',
            headers: {'Content-Type': 'application/json'},
          );
        }

        // Auth endpoints (registration - public)
        if (request.url.path == '/auth/register' && request.method == 'POST') {
          return await authEndpoint.register(request);
        }

        // Auth endpoints (login - public)
        if (request.url.path == '/auth/login' && request.method == 'POST') {
          return await authEndpoint.login(request);
        }

        // Auth endpoints (validate session - protected)
        if (request.url.path == '/auth/me' && request.method == 'GET') {
          return await authEndpoint.validateSession(request);
        }

        // Auth endpoints (logout - protected)
        if (request.url.path == '/auth/logout' && request.method == 'POST') {
          return await authEndpoint.logout(request);
        }

        return Response.notFound(
          '{"error":"Endpoint not found"}',
          headers: {'Content-Type': 'application/json'},
        );
      } catch (e) {
        print('[ERROR] Request handler error: $e');
        return Response.internalServerError(
          body: '{"error":"Internal server error"}',
          headers: {'Content-Type': 'application/json'},
        );
      }
    });

    final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
    
    print('╔═══════════════════════════════════════════════════════╗');
    print('║ 🚀 Messenger Backend Started                          ║');
    print('║ Port: ${server.port}                                         ║');
    print('║ Health: http://localhost:${server.port}/health              ║');
    print('║ Schema: http://localhost:${server.port}/schema              ║');
    print('║ Auth Register: POST /auth/register                   ║');
    print('║ Auth Login: POST /auth/login                         ║');
    print('║ Auth Me: GET /auth/me                                ║');
    print('║ Auth Logout: POST /auth/logout                       ║');
    print('║                                                       ║');
    print('║ Database tables ready (via migrations)                ║');
    print('╚═══════════════════════════════════════════════════════╝\n');

    // Graceful shutdown
    ProcessSignal.sigint.watch().listen((_) async {
      print('\n[INFO] Shutting down gracefully...');
      await server.close(force: true);
      if (dbConnection != null) {
        await dbConnection.close();
      }
      exit(0);
    });
  } catch (e) {
    print('[ERROR] Failed to start server: $e');
    if (dbConnection != null) {
      await dbConnection.close();
    }
    exit(1);
  }
}

/// CORS middleware to allow cross-origin requests
Middleware _corsMiddleware() {
  return (Handler innerHandler) {
    return (Request request) async {
      if (request.method == 'OPTIONS') {
        return Response.ok('',
          headers: {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type, Authorization',
          },
        );
      }

      final response = await innerHandler(request);
      return response.change(headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      });
    };
  };
}

/// JWT validation middleware
Middleware _createJwtMiddleware() {
  return JwtMiddleware.jwtValidation();
}

/// Rate limiting middleware
Middleware _createRateLimitMiddleware() {
  return RateLimitMiddleware.rateLimitMiddleware();
}
