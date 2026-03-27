part of '../../server.dart';

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

// ════════════════════════════════════════════════════════════════════════════
// POLL HANDLERS
// ════════════════════════════════════════════════════════════════════════════

Future<Response> _handleCreatePoll(
  Request request,
  PostgreSQLConnection database,
  PollService pollService,
) async {
  final userId = _extractUserIdFromRequest(request);
  if (userId == null) {
    return Response.unauthorized(
      jsonEncode({'error': 'Unauthorized'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  try {
    final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
    final groupId = body['groupId'] as String?;
    final question = body['question'] as String?;
    final options = (body['options'] as List<dynamic>?)?.map((e) => e as String).toList();
    final isAnonymous = (body['isAnonymous'] as bool?) ?? false;
    final closesAtRaw = body['closesAt'] as String?;
    final closesAt = closesAtRaw != null ? DateTime.parse(closesAtRaw) : null;

    if (groupId == null || question == null || options == null) {
      return Response.badRequest(
        body: jsonEncode({'error': 'groupId, question, and options are required'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    print('[PollHandler] Creating poll in group $groupId by user $userId');

    late final Poll poll;
    try {
      poll = await pollService.createPoll(
        groupId: groupId,
        creatorUserId: userId,
        question: question,
        optionTexts: options,
        isAnonymous: isAnonymous,
        closesAt: closesAt,
      );
    } catch (e) {
      final errorMsg = e.toString();
      print('[PollHandler] ❌ Service error: $errorMsg');
      return Response.badRequest(
        body: jsonEncode({'error': errorMsg}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    print('[PollHandler] Poll created successfully: ${poll.id}');

    // Return poll details
    return Response.ok(
      jsonEncode({
        'id': poll.id,
        'groupId': poll.groupId,
        'question': poll.question,
        'createdBy': poll.createdBy,
      }),
      headers: {'Content-Type': 'application/json'},
    );
  } on ArgumentError catch (e) {
    return Response.badRequest(
      body: jsonEncode({'error': e.message}),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e) {
    final errorStr = e.toString();
    print('[PollHandler] ❌ Error creating poll: $errorStr');
    return Response.internalServerError(
      body: jsonEncode({'error': 'Failed to create poll: $errorStr'}),
      headers: {'Content-Type': 'application/json'},
    );
  }
}

Future<Response> _handleGetPoll(
  Request request,
  PostgreSQLConnection database,
  PollService pollService,
  String pollId,
) async {
  final userId = _extractUserIdFromRequest(request);
  if (userId == null) {
    return Response.unauthorized(
      jsonEncode({'error': 'Unauthorized'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  try {
    print('[PollHandler] Getting poll $pollId for user $userId');
    final result = await pollService.getPollWithResults(
      pollId: pollId,
      requestingUserId: userId,
    );
    return Response.ok(
      jsonEncode(result),
      headers: {'Content-Type': 'application/json'},
    );
  } on StateError catch (e) {
    return Response.notFound(
      jsonEncode({'error': e.message}),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e) {
    print('[PollHandler] ❌ Error getting poll: $e');
    return Response.internalServerError(
      body: jsonEncode({'error': 'Failed to fetch poll: $e'}),
      headers: {'Content-Type': 'application/json'},
    );
  }
}

Future<Response> _handleVotePoll(
  Request request,
  PostgreSQLConnection database,
  PollService pollService,
  String pollId,
) async {
  final userId = _extractUserIdFromRequest(request);
  if (userId == null) {
    return Response.unauthorized(
      jsonEncode({'error': 'Unauthorized'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  try {
    final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
    final optionId = body['optionId'] as String?;

    if (optionId == null) {
      return Response.badRequest(
        body: jsonEncode({'error': 'optionId is required'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    print('[PollHandler] User $userId voting on poll $pollId for option $optionId');

    await pollService.vote(
      pollId: pollId,
      optionId: optionId,
      userId: userId,
    );

    return Response.ok(
      jsonEncode({'message': 'Vote recorded'}),
      headers: {'Content-Type': 'application/json'},
    );
  } on StateError catch (e) {
    return Response(409,
        body: jsonEncode({'error': e.message}),
        headers: {'Content-Type': 'application/json'});
  } catch (e) {
    print('[PollHandler] ❌ Error recording vote: $e');
    return Response.internalServerError(
      body: jsonEncode({'error': 'Failed to record vote: $e'}),
      headers: {'Content-Type': 'application/json'},
    );
  }
}

Future<Response> _handleRetractVote(
  Request request,
  PostgreSQLConnection database,
  PollService pollService,
  String pollId,
) async {
  final userId = _extractUserIdFromRequest(request);
  if (userId == null) {
    return Response.unauthorized(
      jsonEncode({'error': 'Unauthorized'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  try {
    print('[PollHandler] User $userId retracting vote on poll $pollId');

    await pollService.retractVote(
      pollId: pollId,
      userId: userId,
    );

    return Response.ok(
      jsonEncode({'message': 'Vote retracted'}),
      headers: {'Content-Type': 'application/json'},
    );
  } on StateError catch (e) {
    return Response(409,
        body: jsonEncode({'error': e.message}),
        headers: {'Content-Type': 'application/json'});
  } catch (e) {
    print('[PollHandler] ❌ Error retracting vote: $e');
    return Response.internalServerError(
      body: jsonEncode({'error': 'Failed to retract vote: $e'}),
      headers: {'Content-Type': 'application/json'},
    );
  }
}

Future<Response> _handleClosePoll(
  Request request,
  PostgreSQLConnection database,
  PollService pollService,
  String pollId,
) async {
  final userId = _extractUserIdFromRequest(request);
  if (userId == null) {
    return Response.unauthorized(
      jsonEncode({'error': 'Unauthorized'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  try {
    print('[PollHandler] User $userId closing poll $pollId');

    await pollService.closePoll(
      pollId: pollId,
      requestingUserId: userId,
    );

    return Response.ok(
      jsonEncode({'message': 'Poll closed'}),
      headers: {'Content-Type': 'application/json'},
    );
  } on StateError catch (e) {
    return Response(403,
        body: jsonEncode({'error': e.message}),
        headers: {'Content-Type': 'application/json'});
  } catch (e) {
    print('[PollHandler] ❌ Error closing poll: $e');
    return Response.internalServerError(
      body: jsonEncode({'error': 'Failed to close poll: $e'}),
      headers: {'Content-Type': 'application/json'},
    );
  }
}

String? _extractUserIdFromRequest(Request request) {
  final authHeader = request.headers['authorization'] ??
      request.headers['Authorization'];
  if (authHeader == null || !authHeader.startsWith('Bearer ')) return null;

  final token = authHeader.substring('Bearer '.length);
  try {
    final payload = JwtService.validateToken(token);
    return payload.userId;
  } catch (_) {
    return null;
  }
}
