part of '../../server.dart';

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
            Platform.environment['FRONTEND_URL'] ?? 'http://localhost:5000';
          final verificationLink = '$appBaseUrl/verify?token=$token';
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
Future<Response> _handleLogin(
  Request request,
  Connection database,
  TokenService tokenService,
) async {
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
    final deviceId =
        await tokenService.extractOrGenerateDeviceId(request.headers);
    final deviceName = tokenService.inferDeviceName(request.headers);

    await tokenService.createDeviceSession(
      connection: database,
      userId: userId,
      deviceId: deviceId,
      deviceName: deviceName,
      refreshToken: jwtToken,
    );

    return Response.ok(
      jsonEncode({
        'user_id': userId,
        'email': email,
        'username': user['username'],
        'device_id': deviceId,
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
        'SELECT username, email_verified FROM "users" WHERE id = @id',
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
      final username = userRow['username'] as String?;
      final emailVerified = userRow['email_verified'] as bool? ?? false;
      if (!emailVerified) {
        return Response(
          401,
          body: jsonEncode({'error': 'Email not verified'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      if (username == null || username.isEmpty) {
        return Response(
          500,
          body: jsonEncode({'error': 'User session is missing profile data'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      return Response.ok(
        jsonEncode({
          'user_id': payload.userId,
          'email': payload.email,
          'username': username,
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
Future<Response> _handleLogout(
  Request request,
  Connection database,
  TokenService tokenService,
) async {
  try {
    final authHeader = request.headers['authorization'];
    if (authHeader == null || !authHeader.startsWith('Bearer ')) {
      return Response(
        401,
        body: jsonEncode({'error': 'Not authenticated'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    final token = authHeader.substring('Bearer '.length);
    final payload = JwtService.validateToken(token);
    final deviceId =
        await tokenService.extractOrGenerateDeviceId(request.headers);

    await tokenService.revokeDeviceSession(
      connection: database,
      userId: payload.userId,
      deviceId: deviceId,
    );

    return Response.ok(
      jsonEncode({'message': 'Logged out from current device successfully'}),
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

Future<Response> _handleListDeviceSessions(
  Request request,
  Connection database,
  TokenService tokenService,
) async {
  try {
    final authHeader = request.headers['authorization'];
    if (authHeader == null || !authHeader.startsWith('Bearer ')) {
      return Response(
        401,
        body: jsonEncode({'error': 'Missing or invalid authorization header'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    final token = authHeader.substring('Bearer '.length);
    final payload = JwtService.validateToken(token);
    final sessions = await tokenService.listDeviceSessions(
      connection: database,
      userId: payload.userId,
    );

    return Response.ok(
      jsonEncode(
        sessions
            .map(
              (session) => {
                'deviceId': session.deviceId,
                'deviceName': session.deviceName,
                'createdAt': session.createdAt.toIso8601String(),
                'lastSeenAt': session.lastSeenAt.toIso8601String(),
              },
            )
            .toList(),
      ),
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

Future<Response> _handleRevokeDeviceSession(
  Request request,
  Connection database,
  TokenService tokenService,
  String deviceId,
) async {
  try {
    final authHeader = request.headers['authorization'];
    if (authHeader == null || !authHeader.startsWith('Bearer ')) {
      return Response(
        401,
        body: jsonEncode({'error': 'Missing or invalid authorization header'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    final token = authHeader.substring('Bearer '.length);
    final payload = JwtService.validateToken(token);
    final sessions = await tokenService.listDeviceSessions(
      connection: database,
      userId: payload.userId,
    );

    final ownsSession = sessions.any((session) => session.deviceId == deviceId);
    if (!ownsSession) {
      return Response(
        403,
        body: jsonEncode({'error': 'Forbidden'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    await tokenService.revokeDeviceSession(
      connection: database,
      userId: payload.userId,
      deviceId: deviceId,
    );

    return Response.ok(
      jsonEncode({'message': 'Session revoked successfully'}),
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
