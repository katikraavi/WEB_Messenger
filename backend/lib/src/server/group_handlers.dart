part of '../../server.dart';

Future<Response> _handleCreateGroup(
  Request request,
  Connection database,
  EncryptionService encryptionService,
) async {
  try {
    final authHeader = request.headers['authorization'];
    if (authHeader == null || !authHeader.startsWith('Bearer ')) {
      return Response(401,
          body: jsonEncode({'error': 'Missing or invalid authorization header'}),
          headers: {'Content-Type': 'application/json'});
    }

    final token = authHeader.substring('Bearer '.length);
    final payload = JwtService.validateToken(token);
    final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
    final name = (body['name'] as String?)?.trim() ?? '';
    final isPublic = body['is_public'] as bool? ?? false;

    final service = GroupInviteService(
      connection: database,
      encryptionService: encryptionService,
    );
    final group = await service.createGroup(
      creatorUserId: payload.userId,
      name: name,
      isPublic: isPublic,
    );

    return Response.ok(
      jsonEncode({
        'id': group.id,
        'name': name,
        'created_by': group.createdBy,
        'created_at': group.createdAt.toIso8601String(),
        'is_public': group.isPublic,
      }),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e, st) {
    print('[_handleCreateGroup] ERROR: $e\n$st');
    return Response(500,
        body: jsonEncode({'error': 'Failed to create group', 'details': e.toString()}),
        headers: {'Content-Type': 'application/json'});
  }
}

Future<Response> _handleSendGroupInvite(
  Request request,
  Connection database,
  EncryptionService encryptionService,
  String groupId,
) async {
  try {
    final authHeader = request.headers['authorization'];
    if (authHeader == null || !authHeader.startsWith('Bearer ')) {
      return Response(401,
          body: jsonEncode({'error': 'Missing or invalid authorization header'}),
          headers: {'Content-Type': 'application/json'});
    }

    final token = authHeader.substring('Bearer '.length);
    final payload = JwtService.validateToken(token);
    final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
    final receiverId = (body['receiver_id'] ?? body['userId']) as String?;
    if (receiverId == null || receiverId.isEmpty) {
      return Response(400,
          body: jsonEncode({'error': 'receiver_id is required'}),
          headers: {'Content-Type': 'application/json'});
    }

    final service = GroupInviteService(
      connection: database,
      encryptionService: encryptionService,
    );
    final invite = await service.sendGroupInvite(
      groupId: groupId,
      senderId: payload.userId,
      receiverId: receiverId,
    );

    String senderName = 'Someone';
    try {
      final senderResult = await database.query(
        'SELECT username FROM users WHERE id = @sender_id LIMIT 1',
        substitutionValues: {'sender_id': payload.userId},
      );
      if (senderResult.isNotEmpty) {
        senderName = senderResult.first[0] as String? ?? senderName;
      }
    } catch (_) {}

    WebSocketService().notifyUser(
      receiverId,
      WebSocketEvent(
        type: WebSocketEventType.invitationSent,
        data: {
          'inviteId': invite.id,
          'senderId': invite.senderId,
          'senderName': senderName,
          'groupId': invite.groupId,
          'kind': 'group',
        },
      ),
    );

    return Response.ok(
      jsonEncode({
        'id': invite.id,
        'group_id': invite.groupId,
        'sender_id': invite.senderId,
        'receiver_id': invite.receiverId,
        'status': invite.status,
        'created_at': invite.createdAt.toIso8601String(),
      }),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e) {
    return Response(500,
        body: jsonEncode({'error': 'Server error'}),
        headers: {'Content-Type': 'application/json'});
  }
}

Future<Response> _handleListGroups(
  Request request,
  Connection database,
  EncryptionService encryptionService,
) async {
  try {
    final authHeader = request.headers['authorization'];
    if (authHeader == null || !authHeader.startsWith('Bearer ')) {
      return Response(401,
          body: jsonEncode({'error': 'Missing or invalid authorization header'}),
          headers: {'Content-Type': 'application/json'});
    }

    final token = authHeader.substring('Bearer '.length);
    final payload = JwtService.validateToken(token);
    final service = GroupInviteService(
      connection: database,
      encryptionService: encryptionService,
    );
    final groups = await service.listGroupsForUser(payload.userId);

    return Response.ok(
      jsonEncode(groups),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e) {
    return Response(500,
        body: jsonEncode({'error': 'Server error'}),
        headers: {'Content-Type': 'application/json'});
  }
}

Future<Response> _handleGetGroupDetails(
  Request request,
  Connection database,
  EncryptionService encryptionService,
  String groupId,
) async {
  try {
    final authHeader = request.headers['authorization'];
    if (authHeader == null || !authHeader.startsWith('Bearer ')) {
      return Response(401,
          body: jsonEncode({'error': 'Missing or invalid authorization header'}),
          headers: {'Content-Type': 'application/json'});
    }

    final token = authHeader.substring('Bearer '.length);
    final payload = JwtService.validateToken(token);
    final service = GroupInviteService(
      connection: database,
      encryptionService: encryptionService,
    );
    final group = await service.getGroupDetails(groupId, payload.userId);
    if (group == null) {
      return Response(404,
          body: jsonEncode({'error': 'Group not found'}),
          headers: {'Content-Type': 'application/json'});
    }

    return Response.ok(
      jsonEncode(group),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e) {
    return Response(500,
        body: jsonEncode({'error': 'Server error'}),
        headers: {'Content-Type': 'application/json'});
  }
}

Future<Response> _handleListGroupMembers(
  Request request,
  Connection database,
  EncryptionService encryptionService,
  String groupId,
) async {
  try {
    final authHeader = request.headers['authorization'];
    if (authHeader == null || !authHeader.startsWith('Bearer ')) {
      return Response(401,
          body: jsonEncode({'error': 'Missing or invalid authorization header'}),
          headers: {'Content-Type': 'application/json'});
    }

    final token = authHeader.substring('Bearer '.length);
    final payload = JwtService.validateToken(token);
    final service = GroupInviteService(
      connection: database,
      encryptionService: encryptionService,
    );
    final members = await service.listGroupMembersDetailed(groupId, payload.userId);

    return Response.ok(
      jsonEncode(members),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e) {
    return Response(500,
        body: jsonEncode({'error': 'Server error'}),
        headers: {'Content-Type': 'application/json'});
  }
}

Future<Response> _handleListGroupSentInvites(
  Request request,
  Connection database,
  EncryptionService encryptionService,
  String groupId,
) async {
  try {
    final authHeader = request.headers['authorization'];
    if (authHeader == null || !authHeader.startsWith('Bearer ')) {
      return Response(401,
          body: jsonEncode({'error': 'Missing or invalid authorization header'}),
          headers: {'Content-Type': 'application/json'});
    }

    final token = authHeader.substring('Bearer '.length);
    final payload = JwtService.validateToken(token);
    final service = GroupInviteService(
      connection: database,
      encryptionService: encryptionService,
    );
    final invites = await service.listPendingSentInvites(groupId, payload.userId);

    return Response.ok(
      jsonEncode(invites),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e) {
    return Response(500,
        body: jsonEncode({'error': 'Server error'}),
        headers: {'Content-Type': 'application/json'});
  }
}

Future<Response> _handleDeleteGroupInvite(
  Request request,
  Connection database,
  EncryptionService encryptionService,
  String inviteId,
) async {
  try {
    final authHeader = request.headers['authorization'];
    if (authHeader == null || !authHeader.startsWith('Bearer ')) {
      return Response(401,
          body: jsonEncode({'error': 'Missing or invalid authorization header'}),
          headers: {'Content-Type': 'application/json'});
    }

    final token = authHeader.substring('Bearer '.length);
    final payload = JwtService.validateToken(token);
    final service = GroupInviteService(
      connection: database,
      encryptionService: encryptionService,
    );
    await service.cancelInvite(
      inviteId: inviteId,
      requesterUserId: payload.userId,
    );

    return Response.ok(
      jsonEncode({'message': 'Invitation deleted'}),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e) {
    return Response(500,
        body: jsonEncode({'error': 'Server error'}),
        headers: {'Content-Type': 'application/json'});
  }
}

Future<Response> _handleLeaveGroup(
  Request request,
  Connection database,
  EncryptionService encryptionService,
  String groupId,
) async {
  try {
    final authHeader = request.headers['authorization'];
    if (authHeader == null || !authHeader.startsWith('Bearer ')) {
      return Response(401,
          body: jsonEncode({'error': 'Missing or invalid authorization header'}),
          headers: {'Content-Type': 'application/json'});
    }

    final token = authHeader.substring('Bearer '.length);
    final payload = JwtService.validateToken(token);
    final service = GroupInviteService(
      connection: database,
      encryptionService: encryptionService,
    );
    await service.leaveGroup(groupId: groupId, userId: payload.userId);

    return Response.ok(
      jsonEncode({'message': 'Left group successfully'}),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e) {
    return Response(500,
        body: jsonEncode({'error': 'Server error'}),
        headers: {'Content-Type': 'application/json'});
  }
}

Future<Response> _handleAcceptGroupInvite(
  Request request,
  Connection database,
  EncryptionService encryptionService,
  String inviteId,
) async {
  try {
    final authHeader = request.headers['authorization'];
    if (authHeader == null || !authHeader.startsWith('Bearer ')) {
      return Response(401,
          body: jsonEncode({'error': 'Missing or invalid authorization header'}),
          headers: {'Content-Type': 'application/json'});
    }

    final token = authHeader.substring('Bearer '.length);
    final payload = JwtService.validateToken(token);
    final service = GroupInviteService(
      connection: database,
      encryptionService: encryptionService,
    );

    // Accept the invite
    final groupId = await service.acceptGroupInvite(
      inviteId: inviteId,
      receiverId: payload.userId,
    );

    // Get the new member's username
    String memberName = 'Someone';
    try {
      final result = await database.query(
        'SELECT username FROM users WHERE id = @user_id LIMIT 1',
        substitutionValues: {'user_id': payload.userId},
      );
      if (result.isNotEmpty) {
        memberName = result.first[0] as String? ?? memberName;
      }
    } catch (_) {}

    // Notify all group members that a new member joined
    try {
      final members = await database.query(
        'SELECT user_id FROM group_members WHERE group_id = @group_id',
        substitutionValues: {'group_id': groupId},
      );

      for (final row in members) {
        final memberId = row[0] as String;
        if (memberId != payload.userId) {
          WebSocketService().notifyUser(
            memberId,
            WebSocketEvent(
              type: WebSocketEventType.groupMemberJoined,
              data: {
                'groupId': groupId,
                'newMemberId': payload.userId,
                'newMemberName': memberName,
              },
            ),
          );
        }
      }
    } catch (_) {}

    return Response.ok(
      jsonEncode({'message': 'Group invite accepted', 'groupId': groupId}),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e) {
    return Response(500,
        body: jsonEncode({'error': 'Server error: ${e.toString()}'}),
        headers: {'Content-Type': 'application/json'});
  }
}

Future<Response> _handleDeclineGroupInvite(
  Request request,
  Connection database,
  EncryptionService encryptionService,
  String inviteId,
) async {
  try {
    final authHeader = request.headers['authorization'];
    if (authHeader == null || !authHeader.startsWith('Bearer ')) {
      return Response(401,
          body: jsonEncode({'error': 'Missing or invalid authorization header'}),
          headers: {'Content-Type': 'application/json'});
    }

    final token = authHeader.substring('Bearer '.length);
    final payload = JwtService.validateToken(token);
    final service = GroupInviteService(
      connection: database,
      encryptionService: encryptionService,
    );

    await service.declineGroupInvite(
      inviteId: inviteId,
      receiverId: payload.userId,
    );

    return Response.ok(
      jsonEncode({'message': 'Group invite declined'}),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e) {
    return Response(500,
        body: jsonEncode({'error': 'Server error'}),
        headers: {'Content-Type': 'application/json'});
  }
}

Future<Response> _handlePendingGroupInvites(
  Request request,
  Connection database,
  EncryptionService encryptionService,
) async {
  try {
    final authHeader = request.headers['authorization'];
    if (authHeader == null || !authHeader.startsWith('Bearer ')) {
      return Response(401,
          body: jsonEncode({'error': 'Missing or invalid authorization header'}),
          headers: {'Content-Type': 'application/json'});
    }

    final token = authHeader.substring('Bearer '.length);
    final payload = JwtService.validateToken(token);

    // Enriched query: join group_chats and users to get groupName and senderUsername
    // row indices: 0=gi.id, 1=gi.group_id, 2=gi.sender_id, 3=gi.receiver_id,
    //              4=gi.status, 5=gi.created_at, 6=gc.name, 7=gc.created_by,
    //              8=u.username
    final rows = await database.query(
      '''SELECT gi.id, gi.group_id, gi.sender_id, gi.receiver_id, gi.status,
                gi.created_at, gc.name, gc.created_by, u.username
         FROM group_invites gi
         JOIN group_chats gc ON gc.id = gi.group_id
         JOIN users u ON u.id = gi.sender_id
         WHERE gi.receiver_id = @receiver_id AND gi.status = 'pending'
         ORDER BY gi.created_at DESC''',
      substitutionValues: {'receiver_id': payload.userId},
    );

    final result = <Map<String, dynamic>>[];
    for (final row in rows) {
      final encryptedName = row[6] as String? ?? '';
      final createdBy = row[7] as String? ?? '';
      String groupName;
      try {
        final rawName = encryptedName.trim();
        if (rawName.isEmpty) {
          groupName = 'Group';
        } else if (!encryptionService.isEncrypted(rawName)) {
          groupName = rawName;
        } else if (createdBy.isEmpty) {
          groupName = 'Group';
        } else {
          groupName = await encryptionService.decrypt(rawName, createdBy);
        }
      } catch (_) {
        groupName = 'Group';
      }
      result.add({
        'id': row[0] as String,
        'groupId': row[1] as String,
        'invitedByUserId': row[2] as String,
        'receiverId': row[3] as String,
        'status': row[4] as String? ?? 'pending',
        'createdAt': (row[5] as DateTime).toIso8601String(),
        'groupName': groupName,
        'invitedByUsername': row[8] as String? ?? 'Unknown',
      });
    }

    return Response.ok(
      jsonEncode(result),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e) {
    return Response(500,
        body: jsonEncode({'error': 'Server error'}),
        headers: {'Content-Type': 'application/json'});
  }
}

/// Validate password strength
