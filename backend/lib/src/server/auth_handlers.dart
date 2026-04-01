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

    final usersTable = await _resolveUsersTable(database);

    // Check for duplicate email in database
    final emailCheck = await database.query(
      'SELECT email FROM ${usersTable.sqlName} WHERE email = @email',
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
      'SELECT username FROM ${usersTable.sqlName} WHERE username = @username',
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
    final passwordHash = PasswordHasher.hashPassword(password!);
    final userId = const Uuid().v4(); // Just UUID, no prefix
    print(
        '[Register] Creating new user: email=$email, username=$username, userId=$userId');

    // Insert user into database.
    if (usersTable.hasEmailVerified) {
      await database.execute(
        '''INSERT INTO ${usersTable.sqlName} (id, email, username, password_hash, email_verified, created_at)
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
    } else {
      await database.execute(
        '''INSERT INTO ${usersTable.sqlName} (id, email, username, password_hash, created_at)
           VALUES (@id, @email, @username, @password_hash, @created_at)''',
        substitutionValues: {
          'id': userId,
          'email': email,
          'username': username,
          'password_hash': passwordHash,
          'created_at': DateTime.now().toUtc(),
        },
      );
    }

    print('[Register] Registration successful: userId=$userId');

    // Auto-send verification email
    String? devToken;
    bool emailDeliveryFailed = false;
    String? emailDeliveryWarning;
    try {
      final token =
          await verificationService.createVerificationToken(userId).timeout(
                const Duration(seconds: 3),
                onTimeout: () => throw TimeoutException(
                  'Verification token creation timed out',
                ),
              );
      final configuredFrontendUrl = Platform.environment['FRONTEND_URL']?.trim();
      final frontendBaseUrl =
          (configuredFrontendUrl != null && configuredFrontendUrl.isNotEmpty)
              ? configuredFrontendUrl
              : '${request.requestedUri.scheme}://${request.requestedUri.authority}';
      final verificationLink = '$frontendBaseUrl/verify?token=$token';
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
      await emailService.sendEmail(emailMsg).timeout(
        const Duration(seconds: 60),
            onTimeout: () => throw TimeoutException(
              'Verification email send timed out',
            ),
          );
      print('[Register] Verification email dispatched to $email');
    } catch (emailErr) {
      print('[Register][WARNING] Could not send verification email: $emailErr');
      emailDeliveryFailed = true;
      emailDeliveryWarning =
          'Account created, but verification email failed to send. Use resend verification after login screen opens.';
    }

    final bool isDev =
      (Platform.environment['SERVERPOD_ENV'] ?? 'development') !=
      'production';
    final responseBody = <String, dynamic>{
      'user_id': userId,
      'email': email,
      'username': username,
    };
    if (emailDeliveryFailed) {
      responseBody['email_delivery_failed'] = true;
      responseBody['warning'] = emailDeliveryWarning;
    }
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

    final usersTable = await _resolveUsersTable(database);

    // Query database for user by email
    final result = await database.query(
      'SELECT id, email, username, password_hash${usersTable.hasEmailVerified ? ', email_verified' : ''} FROM ${usersTable.sqlName} WHERE email = @email',
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
    if (!PasswordHasher.verifyPassword(password!, storedHash)) {
      return Response(
        401,
        body: jsonEncode({'error': 'Invalid email or password'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    final emailVerified = usersTable.hasEmailVerified
      ? (user['email_verified'] as bool? ?? false)
      : true;
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

    // Device session tracking must not block successful login.
    // Some deployed databases may lag migrations for device_sessions.
    try {
      await tokenService.createDeviceSession(
        connection: database,
        userId: userId,
        deviceId: deviceId,
        deviceName: deviceName,
        refreshToken: jwtToken,
      );
    } catch (e) {
      print('[WARN] Device session persistence failed during login: $e');
    }

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
  Request request, Connection database, TokenService tokenService) async {
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

      final hasActiveSession = await tokenService.hasActiveDeviceSessionForToken(
        connection: database,
        userId: payload.userId,
        token: token,
      );
      if (!hasActiveSession) {
        return Response(
          401,
          body: jsonEncode({'error': 'Session expired or revoked'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final usersTable = await _resolveUsersTable(database);
      final result = await database.query(
        'SELECT username${usersTable.hasEmailVerified ? ', email_verified' : ''} FROM ${usersTable.sqlName} WHERE id = @id',
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
        final emailVerified = usersTable.hasEmailVerified
          ? (userRow['email_verified'] as bool? ?? false)
          : true;
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

Future<Response> _handleAdminDeletePreview(
  Request request,
  Connection database,
) async {
  try {
    final keyError = _validateAdminDeleteKey(request);
    if (keyError != null) {
      return keyError;
    }

    final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
    final email = (body['email'] as String? ?? '').trim().toLowerCase();

    if (email.isEmpty || !email.contains('@')) {
      return Response(
        400,
        body: jsonEncode({'error': 'A valid email is required'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    final usersTable = await _resolveUsersTable(database);
    final userResult = await database.query(
      'SELECT id, email, username${usersTable.hasEmailVerified ? ', email_verified' : ''}, created_at FROM ${usersTable.sqlName} WHERE email = @email LIMIT 1',
      substitutionValues: {'email': email},
    );

    if (userResult.isEmpty) {
      return Response(
        404,
        body: jsonEncode({'error': 'User not found'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    final user = userResult.first.toColumnMap();
    final userId = user['id'] as String;

    final relatedCounts = <String, int>{
      'messages_sent': await _countIfExists(
        database,
        table: 'messages',
        column: 'sender_id',
        userId: userId,
      ),
      'message_edits': await _countIfExists(
        database,
        table: 'message_edits',
        column: 'edited_by',
        userId: userId,
      ),
      'device_sessions': await _countIfExists(
        database,
        table: 'device_sessions',
        column: 'user_id',
        userId: userId,
      ),
      'verification_tokens': await _countIfExists(
        database,
        table: 'verification_token',
        column: 'user_id',
        userId: userId,
      ),
      'password_reset_tokens': await _countIfExists(
        database,
        table: 'password_reset_token',
        column: 'user_id',
        userId: userId,
      ),
    };

    return Response.ok(
      jsonEncode({
        'user': {
          'id': user['id'],
          'email': user['email'],
          'username': user['username'],
          'email_verified': usersTable.hasEmailVerified
              ? user['email_verified']
              : true,
          'created_at': user['created_at'].toString(),
        },
        'related_counts': relatedCounts,
        'required_confirm_phrase': 'DELETE USER',
      }),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e, st) {
    print('[ADMIN][ERROR] Preview delete user failed: $e');
    print('[ADMIN][ERROR] Stack: $st');
    return Response(
      500,
      body: jsonEncode({'error': 'Server error'}),
      headers: {'Content-Type': 'application/json'},
    );
  }
}

Future<Response> _handleAdminDeleteUser(
  Request request,
  Connection database,
) async {
  try {
    final keyError = _validateAdminDeleteKey(request);
    if (keyError != null) {
      return keyError;
    }

    final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
    final email = (body['email'] as String? ?? '').trim().toLowerCase();
    final confirmEmail =
        (body['confirm_email'] as String? ?? '').trim().toLowerCase();
    final confirmPhrase = (body['confirm_phrase'] as String? ?? '').trim();

    if (email.isEmpty || !email.contains('@')) {
      return Response(
        400,
        body: jsonEncode({'error': 'A valid email is required'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    if (confirmEmail != email) {
      return Response(
        400,
        body: jsonEncode({'error': 'Confirmation email must exactly match'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    if (confirmPhrase != 'DELETE USER') {
      return Response(
        400,
        body: jsonEncode({'error': 'Invalid confirmation phrase'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    final usersTable = await _resolveUsersTable(database);
    final userResult = await database.query(
      'SELECT id, email, username FROM ${usersTable.sqlName} WHERE email = @email LIMIT 1',
      substitutionValues: {'email': email},
    );

    if (userResult.isEmpty) {
      return Response(
        404,
        body: jsonEncode({'error': 'User not found'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    final user = userResult.first.toColumnMap();
    final userId = user['id'] as String;

    // Explicitly remove RESTRICT-linked rows first, then delete user.
    await _deleteIfExists(
      database,
      table: 'message_edits',
      column: 'edited_by',
      userId: userId,
    );
    await _deleteIfExists(
      database,
      table: 'messages',
      column: 'sender_id',
      userId: userId,
    );

    final deletedUsers = await database.execute(
      'DELETE FROM ${usersTable.sqlName} WHERE id = @userId',
      substitutionValues: {'userId': userId},
    );

    if (deletedUsers <= 0) {
      return Response(
        500,
        body: jsonEncode({'error': 'Delete failed unexpectedly'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    print('[ADMIN] Deleted user id=$userId email=$email');

    return Response.ok(
      jsonEncode({
        'deleted': true,
        'user': {
          'id': user['id'],
          'email': user['email'],
          'username': user['username'],
        },
      }),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e, st) {
    print('[ADMIN][ERROR] Delete user failed: $e');
    print('[ADMIN][ERROR] Stack: $st');
    return Response(
      500,
      body: jsonEncode({'error': 'Server error while deleting user'}),
      headers: {'Content-Type': 'application/json'},
    );
  }
}

Response? _validateAdminDeleteKey(Request request) {
  final configuredKey = Platform.environment['ADMIN_DELETE_KEY']?.trim();
  if (configuredKey == null || configuredKey.isEmpty) {
    return Response(
      503,
      body: jsonEncode({
        'error':
            'Admin delete endpoint is disabled. Set ADMIN_DELETE_KEY to enable it.',
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  final providedKey = request.headers['x-admin-delete-key']?.trim();
  if (providedKey == null || providedKey.isEmpty || providedKey != configuredKey) {
    return Response(
      401,
      body: jsonEncode({'error': 'Unauthorized'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  return null;
}

Future<bool> _tableExists(Connection database, String table) async {
  final result = await database.query(
    'SELECT to_regclass(@tableName) IS NOT NULL AS exists',
    substitutionValues: {'tableName': 'public.$table'},
  );
  return (result.first[0] as bool?) ?? false;
}

Future<int> _countIfExists(
  Connection database, {
  required String table,
  required String column,
  required String userId,
}) async {
  final exists = await _tableExists(database, table);
  if (!exists) return 0;

  final result = await database.query(
    'SELECT COUNT(*)::int AS count FROM $table WHERE $column = @userId',
    substitutionValues: {'userId': userId},
  );
  return (result.first[0] as int?) ?? 0;
}

Future<void> _deleteIfExists(
  Connection database, {
  required String table,
  required String column,
  required String userId,
}) async {
  final exists = await _tableExists(database, table);
  if (!exists) return;

  await database.execute(
    'DELETE FROM $table WHERE $column = @userId',
    substitutionValues: {'userId': userId},
  );
}

class _UsersTableResolution {
  final String sqlName;
  final String plainName;
  final bool hasEmailVerified;

  const _UsersTableResolution({
    required this.sqlName,
    required this.plainName,
    required this.hasEmailVerified,
  });
}

Future<_UsersTableResolution> _resolveUsersTable(Connection database) async {
  final hasUsers = await _relationExists(database, 'users');
  final hasLegacyUser = hasUsers ? false : await _relationExists(database, '"user"');

  final sqlName = hasUsers
      ? 'users'
      : (hasLegacyUser ? '"user"' : 'users');
  final plainName = hasUsers
      ? 'users'
      : (hasLegacyUser ? 'user' : 'users');

  final hasEmailVerified = await _columnExists(
    database,
    tableName: plainName,
    columnName: 'email_verified',
  );

  return _UsersTableResolution(
    sqlName: sqlName,
    plainName: plainName,
    hasEmailVerified: hasEmailVerified,
  );
}

Future<bool> _relationExists(Connection database, String relationName) async {
  final result = await database.query(
    "SELECT to_regclass('public.$relationName') IS NOT NULL AS exists",
  );
  return (result.first[0] as bool?) ?? false;
}

Future<bool> _columnExists(
  Connection database, {
  required String tableName,
  required String columnName,
}) async {
  final result = await database.query(
    '''SELECT EXISTS (
         SELECT 1
         FROM information_schema.columns
         WHERE table_schema = 'public'
           AND table_name = @tableName
           AND column_name = @columnName
       )''',
    substitutionValues: {
      'tableName': tableName,
      'columnName': columnName,
    },
  );
  return (result.first[0] as bool?) ?? false;
}

Future<bool> _ensureDatabaseConnection(Connection database) async {
  try {
    await database.query('SELECT 1');
    return true;
  } catch (e) {
    print('[WARN] Database probe failed, attempting reconnect: $e');
  }

  try {
    // Best effort cleanup in case the underlying socket is half-open.
    await database.close();
  } catch (_) {}

  try {
    await database.open();
    await database.query('SELECT 1');
    print('[INFO] Database reconnect successful');
    return true;
  } catch (e) {
    print('[ERROR] Database reconnect failed: $e');
    return false;
  }
}
