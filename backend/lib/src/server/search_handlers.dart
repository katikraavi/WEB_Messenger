part of '../../server.dart';

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

Future<Response> _handleMessageSearch(
  Request request,
  Connection database,
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
    final chatId = request.url.queryParameters['chatId'];
    final query = request.url.queryParameters['q'];

    if (chatId == null || chatId.isEmpty || query == null || query.trim().isEmpty) {
      return Response(
        400,
        body: jsonEncode({'error': 'chatId and q are required'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    final membership = await database.query(
      '''SELECT 1 FROM chats
         WHERE id = @chatId
           AND (participant_1_id = @userId OR participant_2_id = @userId)
         LIMIT 1''',
      substitutionValues: {
        'chatId': chatId,
        'userId': payload.userId,
      },
    );

    if (membership.isEmpty) {
      return Response(
        403,
        body: jsonEncode({'error': 'Forbidden'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    final searchService = SearchService(database);
    final results = await searchService.searchMessageContent(chatId, query);

    return Response.ok(
      jsonEncode(results.map((result) => result.toMap()).toList()),
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
