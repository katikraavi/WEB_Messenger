part of '../../server.dart';

Future<Response> _handleInvitePendingCount(
  Request request,
  Connection database,
  String userId,
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
    final authenticatedUserId = payload.userId;

    if (authenticatedUserId != userId) {
      print(
          '[InviteHandler] ⚠️  Unauthorized access attempt: user $authenticatedUserId tried to access count for user $userId');
      return Response(
        403,
        body: jsonEncode(
            {'error': 'Unauthorized - you can only view your own invitations'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

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

Future<Response> _handleInvitePending(
  Request request,
  Connection database,
  String userId,
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
    final authenticatedUserId = payload.userId;

    if (authenticatedUserId != userId) {
      return Response(
        403,
        body: jsonEncode(
            {'error': 'Unauthorized - you can only view your own invitations'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

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

Future<Response> _handleInviteSent(
  Request request,
  Connection database,
  String userId,
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
    final authenticatedUserId = payload.userId;

    if (authenticatedUserId != userId) {
      return Response(
        403,
        body: jsonEncode(
            {'error': 'Unauthorized - you can only view your own invitations'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

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

Future<Response> _handleSendInvite(
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

    final pendingInviteCheck = await database.query(
      '''SELECT id FROM invites 
         WHERE sender_id = @senderId AND receiver_id = @recipientId AND status IN ('pending', 'accepted') 
         LIMIT 1''',
      substitutionValues: {'senderId': senderId, 'recipientId': recipientId},
    );

    if (pendingInviteCheck.isNotEmpty) {
      return Response(
        409,
        body: jsonEncode(
            {'error': 'Pending invitation already exists to this user'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

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

Future<Response> _handleAcceptInvite(
  Request request,
  Connection database,
  String inviteId,
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
    JwtService.validateToken(token);

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

    final senderResult = await database.query(
      'SELECT username FROM users WHERE id = @senderId',
      substitutionValues: {'senderId': senderId},
    );

    final senderUsername =
        senderResult.isNotEmpty ? senderResult[0][0] as String : 'Unknown';

    await database.execute(
      '''UPDATE invites SET status = 'accepted', responded_at = NOW() WHERE id = @inviteId''',
      substitutionValues: {'inviteId': inviteId},
    );

    try {
      final receiverId = row[2] as String;
      final participant1Id =
          senderId.compareTo(receiverId) < 0 ? senderId : receiverId;
      final participant2Id =
          senderId.compareTo(receiverId) < 0 ? receiverId : senderId;
      final chatId = const Uuid().v4();
      final now = DateTime.now().toUtc();

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
    } catch (e) {
      print('[InviteHandler] ⚠️ Warning: Failed to create chat: $e');
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

Future<Response> _handleDeclineInvite(
  Request request,
  Connection database,
  String inviteId,
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

    if (payload.userId != recipientId) {
      return Response(
        403,
        body: jsonEncode(
            {'error': 'Unauthorized - you can only decline your own invites'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    if (currentStatus != 'pending') {
      return Response(
        400,
        body: jsonEncode({'error': 'Can only decline pending invitations'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    final senderResult = await database.query(
      'SELECT username FROM users WHERE id = @senderId',
      substitutionValues: {'senderId': senderId},
    );

    final senderUsername =
        senderResult.isNotEmpty ? senderResult[0][0] as String : 'Unknown';

    await database.execute(
      '''UPDATE invites SET status = 'declined', responded_at = NOW() WHERE id = @inviteId''',
      substitutionValues: {'inviteId': inviteId},
    );

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

Future<Response> _handleCancelInvite(
  Request request,
  Connection database,
  String inviteId,
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
    final userId = payload.userId;

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

    if (userId != senderId) {
      return Response(
        403,
        body:
            jsonEncode({'error': 'Only the sender can cancel this invitation'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    if (status != 'pending') {
      return Response(
        400,
        body: jsonEncode({'error': 'Can only cancel pending invitations'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    final senderResult = await database.query(
      'SELECT username FROM users WHERE id = @senderId',
      substitutionValues: {'senderId': senderId},
    );

    final senderUsername =
        senderResult.isNotEmpty ? senderResult[0][0] as String : 'Unknown';

    await database.execute(
      '''UPDATE invites SET status = 'canceled', canceled_at = NOW() WHERE id = @inviteId''',
      substitutionValues: {'inviteId': inviteId},
    );

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
