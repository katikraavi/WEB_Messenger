import 'package:postgres/postgres.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';

/// ChatService manages chat operations including creation, retrieval, and archival
/// 
/// Implements business logic for:
/// - Getting active chats for a user (unarchived, sorted by recency)
/// - Getting message history for a chat (with pagination)
/// - Creating new 1:1 chats between users
/// - Managing archive status
class ChatService {
  final PostgreSQLConnection connection;
  static const String _chatTable = 'chats';
  static const String _messagesTable = 'messages';
  static const _uuid = Uuid();

  ChatService(this.connection);

  /// Get all active (unarchived) chats for a user, sorted by recency
  /// 
  /// Returns chats where the user is a participant and has not archived the chat.
  /// Results sorted by created_at DESC (most recent first).
  /// 
  /// Throws: Exception if database query fails
  Future<List<Chat>> getActiveChats(String userId) async {
    try {
      print('[ChatService] 📡 Querying active chats for user: $userId');
      
      final result = await connection.query(
        '''
        SELECT 
          id,
          participant_1_id,
          participant_2_id,
          is_participant_1_archived,
          is_participant_2_archived,
          created_at,
          updated_at
        FROM $_chatTable
        WHERE (participant_1_id = @userId::UUID OR participant_2_id = @userId::UUID)
          AND CASE 
            WHEN participant_1_id = @userId::UUID THEN NOT is_participant_1_archived
            WHEN participant_2_id = @userId::UUID THEN NOT is_participant_2_archived
          END
        ORDER BY updated_at DESC
        ''',
        substitutionValues: {'userId': userId},
      );

      print('[ChatService] 📦 Query returned ${result.length} rows');
      
      final chats = result.map((row) {
        print('[ChatService] 🔍 Processing row: $row');
        return _rowToChat(row, userId);
      }).toList();
      
      print('[ChatService] ✅ Converted ${chats.length} chats');
      return chats;
    } catch (e, st) {
      print('[ChatService] ❌ Error fetching active chats: $e');
      print('[ChatService] Stack trace: $st');
      throw Exception('Failed to get active chats for user $userId: $e');
    }
  }

  /// Get all chats for a user, including archived ones
  /// 
  /// Returns all chats where the user is a participant.
  /// Results sorted by created_at DESC.
  Future<List<Chat>> getAllChats(String userId) async {
    try {
      final result = await connection.query(
        '''
        SELECT 
          id,
          participant_1_id,
          participant_2_id,
          is_participant_1_archived,
          is_participant_2_archived,
          created_at,
          updated_at
        FROM $_chatTable
        WHERE participant_1_id = @userId::UUID OR participant_2_id = @userId::UUID
        ORDER BY updated_at DESC
        ''',
        substitutionValues: {'userId': userId},
      );

      return result.map((row) => _rowToChat(row, userId)).toList();
    } catch (e) {
      throw Exception('Failed to get all chats for user $userId: $e');
    }
  }

  /// Get message history for a chat with cursor pagination
  /// 
  /// Returns up to [limit] messages from the specified chat,
  /// optionally starting before a cursor (for pagination).
  /// Results sorted by created_at DESC (most recent first).
  /// 
  /// Parameters:
  /// - chatId: The chat ID to fetch messages from
  /// - limit: Maximum number of messages to return (default: 20)
  /// - beforeCursor: Optional cursor (timestamp) to fetch messages before this point
  /// 
  /// Throws: Exception if database query fails
  Future<List<Message>> getMessages(
    String chatId, {
    required String viewerUserId,
    int limit = 20,
    DateTime? beforeCursor,
  }) async {
    try {
      String query = '''
        SELECT m.id,
               m.chat_id,
               m.sender_id,
               m.recipient_id,
               m.encrypted_content,
               CASE
                 WHEN m.sender_id = @viewerUserId THEN
                   CASE
                     WHEN COUNT(mds.recipient_id) = 0 THEN m.status
                     WHEN COUNT(CASE WHEN mds.status = 'read' THEN 1 END) = COUNT(mds.recipient_id) THEN 'read'
                     WHEN COUNT(CASE WHEN mds.status IN ('delivered', 'read') THEN 1 END) > 0 THEN 'delivered'
                     ELSE 'sent'
                   END
                 ELSE COALESCE(MAX(CASE WHEN mds.recipient_id = @viewerUserId THEN mds.status END), m.status)
               END as effective_status,
               m.created_at,
               m.edited_at,
               m.deleted_at,
               m.is_deleted,
               m.media_url,
               m.media_type,
               COUNT(mds.recipient_id)::int AS recipient_count,
               COUNT(CASE WHEN mds.status IN ('delivered', 'read') THEN 1 END)::int AS delivered_count,
               COUNT(CASE WHEN mds.status = 'read' THEN 1 END)::int AS read_count,
               u.username as sender_username,
               u.profile_picture_url as sender_avatar
        FROM $_messagesTable m
        LEFT JOIN message_delivery_status mds ON mds.message_id = m.id
        LEFT JOIN users u ON m.sender_id = u.id
        WHERE m.chat_id = @chatId
      ''';

      Map<String, dynamic> substitutionValues = {
        'chatId': chatId,
        'limit': limit,
        'viewerUserId': viewerUserId,
      };

      if (beforeCursor != null) {
        query += ' AND m.created_at < @beforeCursor';
        substitutionValues['beforeCursor'] = beforeCursor;
      }

      query += '''
        GROUP BY m.id, m.chat_id, m.sender_id, m.recipient_id, m.encrypted_content,
                 m.status, m.created_at, m.edited_at, m.deleted_at, m.is_deleted,
                 m.media_url, m.media_type, u.username, u.profile_picture_url
        ORDER BY m.created_at DESC
        LIMIT @limit''';

      final result = await connection.query(
        query,
        substitutionValues: substitutionValues,
      );

      return result.map((row) {
        final message = _rowToMessage(row);
        // Add sender username and avatar to response
        message.senderUsername = row[15] as String?;
        message.senderAvatarUrl = row[16] as String?;
        return message;
      }).toList();
    } catch (e) {
      throw Exception('Failed to get messages for chat $chatId: $e');
    }
  }

  /// Create a new 1:1 chat between two users
  /// 
  /// Returns the created Chat entity.
  /// If a chat already exists between these users, returns the existing chat.
  /// 
  /// Parameters:
  /// - userId1: First participant ID
  /// - userId2: Second participant ID
  /// 
  /// Throws: Exception if users are the same, if users don't exist, or if DB query fails
  Future<Chat> createChat(String userId1, String userId2) async {
    if (userId1 == userId2) {
      throw ArgumentError('Cannot create chat between a user and themselves');
    }

    try {
      // Ensure consistent ordering of participant IDs
      final ids = [userId1, userId2]..sort();
      final sortedUserId1 = ids[0];
      final sortedUserId2 = ids[1];

      // Try to insert or get existing chat
      final result = await connection.query(
        '''
        INSERT INTO $_chatTable (id, participant_1_id, participant_2_id, 
                                 is_participant_1_archived, is_participant_2_archived,
                                 created_at, updated_at)
        VALUES (@id, @userId1::UUID, @userId2::UUID, false, false, NOW(), NOW())
        ON CONFLICT (participant_1_id, participant_2_id) DO UPDATE 
        SET updated_at = NOW()
        RETURNING id, participant_1_id, participant_2_id, 
                  is_participant_1_archived, is_participant_2_archived, 
                  created_at, updated_at
        ''',
        substitutionValues: {
          'id': _uuid.v4(),
          'userId1': sortedUserId1,
          'userId2': sortedUserId2,
        },
      );

      if (result.isEmpty) {
        throw Exception('Failed to create or retrieve chat');
      }

      return _rowToChat(result.first, userId1);
    } catch (e) {
      throw Exception('Failed to create chat between $userId1 and $userId2: $e');
    }
  }

  /// Get a specific chat by ID
  /// 
  /// Returns null if chat not found.
  Future<Chat?> getChatById(String chatId) async {
    try {
      final result = await connection.query(
        '''
        SELECT 
          id,
          participant_1_id,
          participant_2_id,
          is_participant_1_archived,
          is_participant_2_archived,
          created_at,
          updated_at
        FROM $_chatTable
        WHERE id = @chatId::UUID
        ''',
        substitutionValues: {'chatId': chatId},
      );

      if (result.isEmpty) return null;
      
      // For getChatById, we need to know which participant is requesting
      // Since we don't have that context, we'll just return the first participant's view
      // This will be fixed by the caller if needed
      return _rowToChatForId(result.first);
    } catch (e) {
      throw Exception('Failed to get chat $chatId: $e');
    }
  }

  /// Update archive status for a user in a chat
  /// 
  /// Parameters:
  /// - chatId: The chat to archive/unarchive
  /// - userId: The user whose archive status to update
  /// - isArchived: true to archive, false to unarchive
  /// 
  /// Throws: Exception if user is not a participant in the chat or if DB query fails
  Future<void> setArchiveStatus(
    String chatId,
    String userId,
    bool isArchived,
  ) async {
    try {
      // First, check which participant this user is
      final chatResult = await connection.query(
        '''
        SELECT participant_1_id, participant_2_id
        FROM $_chatTable
        WHERE id = @chatId::UUID
        ''',
        substitutionValues: {'chatId': chatId},
      );

      if (chatResult.isEmpty) {
        throw Exception('Chat not found: $chatId');
      }

      final participant1 = chatResult.first[0] as String;
      final participant2 = chatResult.first[1] as String;

      if (userId == participant1) {
        await connection.execute(
          '''
          UPDATE $_chatTable
          SET is_participant_1_archived = @isArchived, updated_at = NOW()
          WHERE id = @chatId::UUID
          ''',
          substitutionValues: {
            'chatId': chatId,
            'isArchived': isArchived,
          },
        );
      } else if (userId == participant2) {
        await connection.execute(
          '''
          UPDATE $_chatTable
          SET is_participant_2_archived = @isArchived, updated_at = NOW()
          WHERE id = @chatId::UUID
          ''',
          substitutionValues: {
            'chatId': chatId,
            'isArchived': isArchived,
          },
        );
      } else {
        throw Exception(
          'User $userId is not a participant in chat $chatId',
        );
      }
    } catch (e) {
      throw Exception(
        'Failed to set archive status for user $userId in chat $chatId: $e',
      );
    }
  }

  /// Get whether notifications are muted for this chat and user.
  Future<bool> isChatMuted(String chatId, String userId) async {
    final result = await connection.query(
      '''
      SELECT is_muted
      FROM chat_notification_preferences
      WHERE chat_id = @chatId::UUID AND user_id = @userId::UUID
      ''',
      substitutionValues: {'chatId': chatId, 'userId': userId},
    );

    if (result.isEmpty) {
      return false;
    }

    return result.first[0] as bool? ?? false;
  }

  /// Upsert the notification preference for a user in a chat.
  Future<bool> setChatMuted(String chatId, String userId, bool isMuted) async {
    await connection.execute(
      '''
      INSERT INTO chat_notification_preferences (chat_id, user_id, is_muted, updated_at)
      VALUES (@chatId::UUID, @userId::UUID, @isMuted, NOW())
      ON CONFLICT (chat_id, user_id)
      DO UPDATE SET is_muted = EXCLUDED.is_muted, updated_at = NOW()
      ''',
      substitutionValues: {
        'chatId': chatId,
        'userId': userId,
        'isMuted': isMuted,
      },
    );

    return isMuted;
  }

  /// Fetch all chat ids muted by the current user.
  Future<List<String>> getMutedChatIds(String userId) async {
    final result = await connection.query(
      '''
      SELECT chat_id
      FROM chat_notification_preferences
      WHERE user_id = @userId::UUID AND is_muted = TRUE
      ORDER BY updated_at DESC
      ''',
      substitutionValues: {'userId': userId},
    );

    return result.map((row) => row[0] as String).toList();
  }

  /// Convert database row to Chat model
  /// 
  /// Expected row structure: [id, participant_1_id, participant_2_id, 
  ///                         is_participant_1_archived, is_participant_2_archived,
  ///                         created_at, updated_at]
  Chat _rowToChat(List<dynamic> row, String requesterId) {
    try {
      final id = row[0] as String?;
      if (id == null || id.isEmpty) {
        throw Exception('Chat ID is null or empty');
      }

      final participant1Id = row[1] as String;
      final participant2Id = row[2] as String;
      final isParticipant1Archived = row[3] as bool;
      final isParticipant2Archived = row[4] as bool;
      final createdAt = row[5] as DateTime;
      final updatedAt = row[6] as DateTime;

      final chat = Chat(
        id: id,
        participant1Id: participant1Id,
        participant2Id: participant2Id,
        isParticipant1Archived: isParticipant1Archived,
        isParticipant2Archived: isParticipant2Archived,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

      print('[ChatService] ✅ Converted chat: id=$id, p1=$participant1Id, p2=$participant2Id, requester=$requesterId');
      return chat;
    } catch (e) {
      print('[ChatService] ❌ Error converting row to chat: $e');
      print('[ChatService] Row data: $row');
      rethrow;
    }
  }

  /// Convert database row to Chat model (without requester context)
  Chat _rowToChatForId(List<dynamic> row) {
    try {
      final id = row[0] as String?;
      if (id == null || id.isEmpty) {
        throw Exception('Chat ID is null or empty');
      }

      final participant1Id = row[1] as String;
      final participant2Id = row[2] as String;
      final isParticipant1Archived = row[3] as bool;
      final isParticipant2Archived = row[4] as bool;
      final createdAt = row[5] as DateTime;
      final updatedAt = row[6] as DateTime;

      return Chat(
        id: id,
        participant1Id: participant1Id,
        participant2Id: participant2Id,
        isParticipant1Archived: isParticipant1Archived,
        isParticipant2Archived: isParticipant2Archived,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
    } catch (e) {
      print('[ChatService] ❌ Error converting row to chat: $e');
      rethrow;
    }
  }

  /// Get all archived chats for a user
  /// 
  /// Returns chats where the user is a participant and has archived the chat.
  /// Results sorted by created_at DESC (most recent first).
  Future<List<Chat>> getArchivedChats(String userId) async {
    try {
      print('[ChatService] 📡 Querying archived chats for user: $userId');
      
      final result = await connection.query(
        '''
        SELECT 
          id,
          participant_1_id,
          participant_2_id,
          is_participant_1_archived,
          is_participant_2_archived,
          created_at,
          updated_at
        FROM $_chatTable
        WHERE (participant_1_id = @userId::UUID OR participant_2_id = @userId::UUID)
          AND CASE 
            WHEN participant_1_id = @userId::UUID THEN is_participant_1_archived
            WHEN participant_2_id = @userId::UUID THEN is_participant_2_archived
          END
        ORDER BY updated_at DESC
        ''',
        substitutionValues: {'userId': userId},
      );

      print('[ChatService] 📦 Query returned ${result.length} archived rows');
      
      final chats = result.map((row) => _rowToChat(row, userId)).toList();
      
      print('[ChatService] ✅ Converted ${chats.length} archived chats');
      return chats;
    } catch (e, st) {
      print('[ChatService] ❌ Error fetching archived chats: $e');
      print('[ChatService] Stack trace: $st');
      throw Exception('Failed to get archived chats for user $userId: $e');
    }
  }

  /// Archive a chat for the current user
  /// 
  /// Marks a chat as archived for the specified user without affecting the other participant.
  /// Throws: Exception if the user is not a participant of the chat
  Future<Chat> archiveChat(String chatId, String userId) async {
    try {
      print('[ChatService] 📌 Archiving chat $chatId for user $userId');
      
      // First, get the chat to verify the user is a participant
      final chatResult = await connection.query(
        '''
        SELECT participant_1_id, participant_2_id, is_participant_1_archived, is_participant_2_archived
        FROM $_chatTable WHERE id = @chatId::UUID
        ''',
        substitutionValues: {'chatId': chatId},
      );
      
      if (chatResult.isEmpty) {
        throw Exception('Chat not found');
      }
      
      final row = chatResult.first;
      final participant1Id = row[0] as String;
      final participant2Id = row[1] as String;
      
      // Determine which participant this user is and update the correct field
      String sql;
      if (userId == participant1Id) {
        sql = '''
          UPDATE $_chatTable 
          SET is_participant_1_archived = true, updated_at = NOW()
          WHERE id = @chatId::UUID
        ''';
      } else if (userId == participant2Id) {
        sql = '''
          UPDATE $_chatTable 
          SET is_participant_2_archived = true, updated_at = NOW()
          WHERE id = @chatId::UUID
        ''';
      } else {
        throw Exception('User is not a participant of this chat');
      }
      
      await connection.query(sql, substitutionValues: {'chatId': chatId});
      
      // Fetch and return the updated chat
      final updatedResult = await connection.query(
        '''
        SELECT 
          id, participant_1_id, participant_2_id, is_participant_1_archived,
          is_participant_2_archived, created_at, updated_at
        FROM $_chatTable WHERE id = @chatId::UUID
        ''',
        substitutionValues: {'chatId': chatId},
      );
      
      print('[ChatService] ✅ Chat $chatId archived for user $userId');
      return _rowToChat(updatedResult.first, userId);
    } catch (e, st) {
      print('[ChatService] ❌ Error archiving chat: $e');
      print('[ChatService] Stack trace: $st');
      throw Exception('Failed to archive chat $chatId: $e');
    }
  }

  /// Unarchive a chat for the current user
  /// 
  /// Marks a chat as unarchived for the specified user without affecting the other participant.
  /// Throws: Exception if the user is not a participant of the chat
  Future<Chat> unarchiveChat(String chatId, String userId) async {
    try {
      print('[ChatService] 📌 Unarchiving chat $chatId for user $userId');
      
      // First, get the chat to verify the user is a participant
      final chatResult = await connection.query(
        '''
        SELECT participant_1_id, participant_2_id
        FROM $_chatTable WHERE id = @chatId::UUID
        ''',
        substitutionValues: {'chatId': chatId},
      );
      
      if (chatResult.isEmpty) {
        throw Exception('Chat not found');
      }
      
      final row = chatResult.first;
      final participant1Id = row[0] as String;
      final participant2Id = row[1] as String;
      
      // Determine which participant this user is and update the correct field
      String sql;
      if (userId == participant1Id) {
        sql = '''
          UPDATE $_chatTable 
          SET is_participant_1_archived = false, updated_at = NOW()
          WHERE id = @chatId::UUID
        ''';
      } else if (userId == participant2Id) {
        sql = '''
          UPDATE $_chatTable 
          SET is_participant_2_archived = false, updated_at = NOW()
          WHERE id = @chatId::UUID
        ''';
      } else {
        throw Exception('User is not a participant of this chat');
      }
      
      await connection.query(sql, substitutionValues: {'chatId': chatId});
      
      // Fetch and return the updated chat
      final updatedResult = await connection.query(
        '''
        SELECT 
          id, participant_1_id, participant_2_id, is_participant_1_archived,
          is_participant_2_archived, created_at, updated_at
        FROM $_chatTable WHERE id = @chatId::UUID
        ''',
        substitutionValues: {'chatId': chatId},
      );
      
      print('[ChatService] ✅ Chat $chatId unarchived for user $userId');
      return _rowToChat(updatedResult.first, userId);
    } catch (e, st) {
      print('[ChatService] ❌ Error unarchiving chat: $e');
      print('[ChatService] Stack trace: $st');
      throw Exception('Failed to unarchive chat $chatId: $e');
    }
  }

  /// Convert database row to Message model
  Message _rowToMessage(List<dynamic> row) {
    return Message(
      id: row[0] as String,
      chatId: row[1] as String,
      senderId: row[2] as String,
      recipientId: row[3] as String?,
      encryptedContent: row[4] as String,
      status: row[5] as String? ?? 'sent',
      createdAt: row[6] as DateTime,
      editedAt: row[7] as DateTime?,
      deletedAt: row[8] as DateTime?,
      isDeleted: row[9] as bool? ?? false,
      mediaUrl: row[10] as String?,
      mediaType: row[11] as String?,
      recipientCount: row[12] as int? ?? 0,
      deliveredCount: row[13] as int? ?? 0,
      readCount: row[14] as int? ?? 0,
    );
  }
}
