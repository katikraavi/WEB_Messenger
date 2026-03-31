part of '../../server.dart';

Future<Response> _handleGetChats(
  Request request,
  Connection database,
  EncryptionService encryptionService,
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

    final chatHandlers = ChatHandlers(database, encryptionService);
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

Future<Response> _handleGetArchivedChats(
  Request request,
  Connection database,
  EncryptionService encryptionService,
) async {
  if (_verboseBackendLogs) {
    print('[ROUTE MATCH] archived chats route matched');
  }
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

    final chatService = ChatService(database);
    final archivedChats = await chatService.getArchivedChats(userId);

    final groupService = GroupInviteService(
      connection: database,
      encryptionService: encryptionService,
    );
    final archivedGroups = await groupService.listArchivedGroupsForUser(userId);

    final combinedChatJsonList = <Map<String, dynamic>>[
      for (final chat in archivedChats) chat.toJson(),
      for (final group in archivedGroups)
        {
          'id': group['id'],
          'participant_1_id': userId,
          'participant_2_id': 'group:${group['id']}',
          'is_participant_1_archived': true,
          'is_participant_2_archived': true,
          'created_at': group['createdAt'],
          'updated_at': group['createdAt'],
          'last_message_preview': 'Group chat',
          'last_message_timestamp': group['createdAt'],
          'chat_type': 'group',
          'display_name': group['name'],
          'member_count': group['memberCount'],
          'participant_names': group['participantNames'],
          'my_role': group['myRole'],
        },
    ];

    combinedChatJsonList.sort((a, b) {
      final aTime = DateTime.parse(
        (a['last_message_timestamp'] ?? a['updated_at']) as String,
      );
      final bTime = DateTime.parse(
        (b['last_message_timestamp'] ?? b['updated_at']) as String,
      );
      return bTime.compareTo(aTime);
    });

    return Response.ok(
      jsonEncode({
        'chats': combinedChatJsonList,
        'total': combinedChatJsonList.length,
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

Future<Response> _handleDeleteChat(
  Request request,
  Connection database,
  String chatId,
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

    // First check if this is a group chat
    final groupChatResult = await database.query(
      r'SELECT created_by FROM group_chats WHERE id = @chatId',
      substitutionValues: {'chatId': chatId},
    );

    if (groupChatResult.isNotEmpty) {
      // It's a group chat
      final createdBy = groupChatResult[0][0] as String;
      
      // Only the group creator can delete the entire group
      if (userId != createdBy) {
        return Response(
          403,
          body: jsonEncode({
            'error': 'Unauthorized - only the group creator can delete this group'
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // Delete the group chat (cascade will handle group_members and group_invites)
      await database.execute(
        'DELETE FROM group_chats WHERE id = @chatId',
        substitutionValues: {'chatId': chatId},
      );

      return Response(204);
    }

    // Not a group chat, check if it's a single chat
    final singleChatResult = await database.query(
      r'SELECT participant_1_id, participant_2_id FROM chats WHERE id = @chatId',
      substitutionValues: {'chatId': chatId},
    );

    if (singleChatResult.isEmpty) {
      return Response(
        404,
        body: jsonEncode({'error': 'Chat not found'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    final row = singleChatResult[0];
    final participant1 = row[0] as String;
    final participant2 = row[1] as String;

    if (userId != participant1 && userId != participant2) {
      return Response(
        403,
        body: jsonEncode(
            {'error': 'Unauthorized - you are not a participant in this chat'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    final isParticipant1 = userId == participant1;
    final otherUserId = isParticipant1 ? participant2 : participant1;

    // Actually DELETE the chat (not archive) so they can send new invitations
    await database.execute(
      'DELETE FROM chats WHERE id = @chatId',
      substitutionValues: {'chatId': chatId},
    );

    // Notify the other participant that the chat was deleted
    try {
      final wsService = WebSocketService();
      wsService.notifyChatDeleted(chatId, otherUserId);
    } catch (e) {
      print('[ChatHandler] ⚠️ Failed to notify chat deletion: $e');
    }

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

Future<Response> _handleGetChatMessages(
  Request request,
  Connection database,
  EncryptionService encryptionService,
  String chatId,
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

    final chatHandlers = ChatHandlers(database, encryptionService);
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

Future<Response> _handleRegisterDeviceToken(
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

Future<Response> _handleGetMutedChats(
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
    final chatService = ChatService(database);
    final mutedChatIds = await chatService.getMutedChatIds(payload.userId);

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

Future<Response> _handleGetChatNotificationSettings(
  Request request,
  Connection database,
  String chatId,
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
      body: jsonEncode({'error': 'Failed to fetch notification settings: $e'}),
      headers: {'Content-Type': 'application/json'},
    );
  }
}

Future<Response> _handleSetChatNotificationSettings(
  Request request,
  Connection database,
  String chatId,
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

Future<Response> _handleArchiveChat(
  Request request,
  Connection database,
  String chatId,
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

Future<Response> _handleUnarchiveChat(
  Request request,
  Connection database,
  String chatId,
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
