import 'package:postgres/postgres.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import '../models/message_model.dart';

/// MessageService handles message operations including validation and encryption
/// 
/// Implements business logic for:
/// - Validating message content and structure
/// - End-to-end encryption/decryption wrapper
/// - Storing and retrieving encrypted messages
/// - Ensuring sender is a participant in the chat
class MessageService {
  final PostgreSQLConnection connection;
  static const String _tableName = 'messages';
  static const _uuid = Uuid();

  // Message content validation rules
  static const int maxMessageLength = 5000;
  static const int minMessageLength = 1;

  MessageService(this.connection);

  /// Send a message to a chat
  /// 
  /// Validates that:
  /// - Message content is within length limits (1-5000 chars before encryption)
  /// - Sender is a participant in the chat
  /// - Encrypted content is valid Base64
  /// 
  /// Returns the created Message entity.
  /// 
  /// Parameters:
  /// - chatId: The chat to send the message to
  /// - senderId: The user sending the message
  /// - encryptedContent: Base64-encoded encrypted message content
  /// 
  /// Throws: ArgumentError for validation failures, Exception for DB errors
  Future<Message> sendMessage({
    required String chatId,
    required String senderId,
    required String encryptedContent,
    String? mediaUrl,
    String? mediaType,
  }) async {
    // Validate encrypted content format
    // Supports both:
    // - New format: base64(nonce)::base64(ciphertext)::base64(mac)
    // - Old format (legacy): valid base64 string
    try {
      final parts = encryptedContent.split('::');
      if (parts.length == 3) {
        // New format: validate each part is base64
        for (final part in parts) {
          base64Decode(part);
        }
      } else {
        // Old format: validate entire string is base64
        base64Decode(encryptedContent);
      }
    } catch (e) {
      throw ArgumentError(
        'Invalid encrypted content: must be valid Base64 encoding. Error: $e',
      );
    }

    try {
      final directChatResult = await connection.query(
        'SELECT participant_1_id, participant_2_id FROM chats WHERE id = @chatId',
        substitutionValues: {'chatId': chatId},
      );

      String? recipientId;
      List<String> trackedRecipientIds = const [];
      final isDirectChat = directChatResult.isNotEmpty;

      if (isDirectChat) {
        final participant1 = directChatResult.first[0] as String;
        final participant2 = directChatResult.first[1] as String;

        if (senderId != participant1 && senderId != participant2) {
          throw ArgumentError(
            'Sender $senderId is not a participant in chat $chatId',
          );
        }

        recipientId = senderId == participant1 ? participant2 : participant1;
        trackedRecipientIds = [recipientId];
      } else {
        final groupResult = await connection.query(
          '''SELECT 1
             FROM group_members
             WHERE group_id = @chatId AND user_id = @senderId
             LIMIT 1''',
          substitutionValues: {
            'chatId': chatId,
            'senderId': senderId,
          },
        );

        if (groupResult.isEmpty) {
          throw ArgumentError('Chat not found: $chatId');
        }

        trackedRecipientIds = await _listOtherGroupMemberIds(chatId, senderId);
      }

      // Create and store the message
      final messageId = _uuid.v4();
      final now = DateTime.now();

      await connection.execute(
        '''
        INSERT INTO $_tableName (id, chat_id, sender_id, recipient_id, encrypted_content, status, created_at, media_url, media_type)
        VALUES (@id, @chatId, @senderId, @recipientId, @encryptedContent, 'sent', @createdAt, @mediaUrl, @mediaType)
        ''',
        substitutionValues: {
          'id': messageId,
          'chatId': chatId,
          'senderId': senderId,
          'recipientId': recipientId,
          'encryptedContent': encryptedContent,
          'createdAt': now,
          'mediaUrl': mediaUrl,
          'mediaType': mediaType,
        },
      );

      for (final trackedRecipientId in trackedRecipientIds) {
        await connection.execute(
          '''
          INSERT INTO message_delivery_status (id, message_id, recipient_id, status, updated_at)
          VALUES (@statusId, @messageId, @recipientId, 'sent', @now)
          ''',
          substitutionValues: {
            'statusId': _uuid.v4(),
            'messageId': messageId,
            'recipientId': trackedRecipientId,
            'now': now,
          },
        );
      }

      if (recipientId != null) {
        await connection.execute(
          'UPDATE chats SET updated_at = NOW() WHERE id = @chatId',
          substitutionValues: {'chatId': chatId},
        );
      }

      return Message(
        id: messageId,
        chatId: chatId,
        senderId: senderId,
        recipientId: recipientId,
        encryptedContent: encryptedContent,
        status: 'sent',
        createdAt: now,
        mediaUrl: mediaUrl,
        mediaType: mediaType,
        recipientCount: trackedRecipientIds.length,
        deliveredCount: 0,
        readCount: 0,
      );
    } catch (e) {
      throw Exception(
        'Failed to send message to chat $chatId from user $senderId: $e',
      );
    }
  }

  /// Validate message content (plaintext) before encryption
  /// 
  /// Ensures:
  /// - Content is not empty or null
  /// - Content length is within allowed range (1-5000 characters)
  /// - Content contains only printable characters (optional stricter validation)
  /// 
  /// Throws: ArgumentError if validation fails
  void validateMessageContent(String plaintext) {
    if (plaintext.isEmpty) {
      throw ArgumentError('Message content cannot be empty');
    }

    if (plaintext.length > maxMessageLength) {
      throw ArgumentError(
        'Message content exceeds maximum length of $maxMessageLength characters '
        '(received: ${plaintext.length})',
      );
    }

    // Optional: Check for null bytes or other invalid content
    if (plaintext.contains('\x00')) {
      throw ArgumentError('Message content contains invalid null bytes');
    }
  }

  /// Validate receiver of a message
  /// 
  /// Ensures the receiver is a participant in the chat
  /// 
  /// Throws: ArgumentError if receiver is not a valid participant
  Future<void> validateReceiver(String chatId, String receiverId) async {
    try {
      final result = await connection.query(
        '''
        SELECT 1 FROM chats 
        WHERE id = @chatId AND (participant_1_id = @userId OR participant_2_id = @userId)
        ''',
        substitutionValues: {
          'chatId': chatId,
          'userId': receiverId,
        },
      );

      if (result.isEmpty) {
        throw ArgumentError(
          'Receiver $receiverId is not a participant in chat $chatId',
        );
      }
    } catch (e) {
      throw Exception('Failed to validate receiver: $e');
    }
  }

  Future<bool> isGroupMessage(String messageId) async {
    try {
      final result = await connection.query(
        '''SELECT recipient_id
           FROM $_tableName
           WHERE id = @messageId
           LIMIT 1''',
        substitutionValues: {'messageId': messageId},
      );

      if (result.isEmpty) {
        return false;
      }

      return result.first[0] == null;
    } catch (e) {
      throw Exception('Failed to check message type: $e');
    }
  }

  Future<Map<String, int>> getMessageReceiptCounts(String messageId) async {
    try {
      final result = await connection.query(
        '''SELECT COUNT(*)::int AS recipient_count,
                  COUNT(CASE WHEN status IN ('delivered', 'read') THEN 1 END)::int AS delivered_count,
                  COUNT(CASE WHEN status = 'read' THEN 1 END)::int AS read_count
           FROM message_delivery_status
           WHERE message_id = @messageId''',
        substitutionValues: {'messageId': messageId},
      );

      if (result.isEmpty) {
        return {
          'recipient_count': 0,
          'delivered_count': 0,
          'read_count': 0,
        };
      }

      return {
        'recipient_count': result.first[0] as int? ?? 0,
        'delivered_count': result.first[1] as int? ?? 0,
        'read_count': result.first[2] as int? ?? 0,
      };
    } catch (e) {
      throw Exception('Failed to get receipt counts: $e');
    }
  }

  Future<String> getAggregateMessageStatus(String messageId) async {
    try {
      final counts = await getMessageReceiptCounts(messageId);
      final recipientCount = counts['recipient_count'] ?? 0;
      final deliveredCount = counts['delivered_count'] ?? 0;
      final readCount = counts['read_count'] ?? 0;

      if (recipientCount == 0) {
        final message = await getMessageById(messageId);
        return message?.status ?? 'sent';
      }

      if (readCount == recipientCount) {
        return 'read';
      }

      if (deliveredCount > 0) {
        return 'delivered';
      }

      return 'sent';
    } catch (e) {
      throw Exception('Failed to get aggregate status: $e');
    }
  }

  Future<Map<String, dynamic>> getReceiptSummary(String messageId) async {
    final counts = await getMessageReceiptCounts(messageId);
    final aggregateStatus = await getAggregateMessageStatus(messageId);

    return {
      ...counts,
      'aggregate_status': aggregateStatus,
    };
  }

  Future<List<String>> _listOtherGroupMemberIds(
    String groupId,
    String senderId,
  ) async {
    final result = await connection.query(
      '''SELECT user_id
         FROM group_members
         WHERE group_id = @groupId AND user_id != @senderId''',
      substitutionValues: {
        'groupId': groupId,
        'senderId': senderId,
      },
    );

    return result.map((row) => row[0] as String).toList();
  }

  /// Encrypt plaintext message content (MVP: Base64 encoding)
  /// 
  /// For MVP, uses simple Base64 encoding.
  /// Production should use ChaCha20-Poly1305.
  /// 
  /// Parameters:
  /// - plaintext: The message content to encrypt
  /// - keyBytes: The encryption key (unused in MVP)
  /// - nonce: Optional nonce (unused in MVP)
  /// 
  /// Returns: Base64-encoded plaintext
  Future<String> encryptMessage(
    String plaintext,
    SecretKey keyBytes, {
    List<int>? nonce,
  }) async {
    validateMessageContent(plaintext);
    try {
      return base64Encode(utf8.encode(plaintext));
    } catch (e) {
      throw Exception('Failed to encrypt message: $e');
    }
  }

  /// Decrypt message content (MVP: Base64 decoding)
  /// 
  /// For MVP, uses simple Base64 decoding.
  /// Production should use ChaCha20-Poly1305.
  /// 
  /// Parameters:
  /// - encryptedContent: Base64-encoded plaintext
  /// - keyBytes: The decryption key (unused in MVP)
  /// 
  /// Returns: Decrypted plaintext message
  Future<String> decryptMessage(
    String encryptedContent,
    SecretKey keyBytes,
  ) async {
    try {
      // Decode from Base64
      final bytes = base64Decode(encryptedContent);
      return utf8.decode(bytes);
    } catch (e) {
      throw Exception('Failed to decrypt message: $e');
    }
  }

  /// Get a message by ID, optionally decrypting it
  /// 
  /// Parameters:
  /// - messageId: The message to retrieve
  /// - keyBytes: Optional key for decryption (if provided, decrypts the message)
  /// 
  /// Returns: Message entity, with decryptedContent populated if key was provided
  Future<Message?> getMessageById(
    String messageId, {
    SecretKey? keyBytes,
  }) async {
    try {
      final result = await connection.query(
        '''
        SELECT id, chat_id, sender_id, recipient_id, encrypted_content,
               status, created_at, edited_at, deleted_at, is_deleted,
               media_url, media_type
        FROM $_tableName
        WHERE id = @messageId
        ''',
        substitutionValues: {'messageId': messageId},
      );

      if (result.isEmpty) return null;

      final message = Message(
        id: result.first[0] as String,
        chatId: result.first[1] as String,
        senderId: result.first[2] as String,
        recipientId: result.first[3] as String?,
        encryptedContent: result.first[4] as String,
        status: result.first[5] as String? ?? 'sent',
        createdAt: result.first[6] as DateTime,
        editedAt: result.first[7] as DateTime?,
        deletedAt: result.first[8] as DateTime?,
        isDeleted: result.first[9] as bool? ?? false,
        mediaUrl: result.first[10] as String?,
        mediaType: result.first[11] as String?,
      );

      // Decrypt if key provided
      if (keyBytes != null) {
        message.decryptedContent = await decryptMessage(
          message.encryptedContent,
          keyBytes,
        );
      }

      return message;
    } catch (e) {
      throw Exception('Failed to get message $messageId: $e');
    }
  }

  /// Fetch messages for a chat with pagination
  /// 
  /// Parameters:
  /// - chatId: The chat to fetch messages from
  /// - limit: Maximum number of messages to return (default 50)
  /// - offset: Number of messages to skip (for pagination)
  /// 
  /// Returns: List of Message objects in reverse chronological order (newest first)
  Future<List<Message>> fetchMessages(
    String chatId, {
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      if (limit < 1 || limit > 200) {
        throw ArgumentError('limit must be between 1 and 200');
      }
      if (offset < 0) {
        throw ArgumentError('offset must be >= 0');
      }

      final result = await connection.query(
        '''
        SELECT id, chat_id, sender_id, recipient_id, encrypted_content, 
               status, created_at, edited_at, deleted_at, is_deleted,
               media_url, media_type
        FROM $_tableName
        WHERE chat_id = @chatId
        ORDER BY created_at DESC
        LIMIT @limit OFFSET @offset
        ''',
        substitutionValues: {
          'chatId': chatId,
          'limit': limit,
          'offset': offset,
        },
      );

      return result.map((row) {
        return Message(
          id: row[0] as String,
          chatId: row[1] as String,
          senderId: row[2] as String,
          recipientId: row[3] as String?,
          encryptedContent: row[4] as String,
          status: row[5] as String,
          createdAt: row[6] as DateTime,
          editedAt: row[7] as DateTime?,
          deletedAt: row[8] as DateTime?,
          isDeleted: row[9] as bool,
          mediaUrl: row[10] as String?,
          mediaType: row[11] as String?,
        );
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch messages for chat $chatId: $e');
    }
  }

  /// Update message delivery status
  /// 
  /// Parameters:
  /// - messageId: The message to update
  /// - recipientId: The recipient user
  /// - newStatus: New status (sent, delivered, read)
  /// 
  /// Returns: Updated MessageStatus object
  Future<dynamic> updateMessageStatus(
    String messageId,
    String recipientId,
    String newStatus,
  ) async {
    try {
      if (!['sent', 'delivered', 'read'].contains(newStatus)) {
        throw ArgumentError('Invalid status: $newStatus');
      }

      // Build update columns based on status
      String updateClauses = 'status = @newStatus, updated_at = NOW()';
      var substitutions = {
        'messageId': messageId,
        'recipientId': recipientId,
        'newStatus': newStatus,
      };

      if (newStatus == 'delivered') {
        updateClauses += ', delivered_at = NOW()';
      } else if (newStatus == 'read') {
        updateClauses += ', delivered_at = COALESCE(delivered_at, NOW()), read_at = NOW()';
      }

      await connection.execute(
        '''
        UPDATE message_delivery_status
        SET $updateClauses
        WHERE message_id = @messageId AND recipient_id = @recipientId
        ''',
        substitutionValues: substitutions,
      );

      // Return the updated status record
      final result = await connection.query(
        '''
        SELECT id, message_id, recipient_id, status, delivered_at, read_at, updated_at
        FROM message_delivery_status
        WHERE message_id = @messageId AND recipient_id = @recipientId
        ''',
        substitutionValues: {
          'messageId': messageId,
          'recipientId': recipientId,
        },
      );

      if (result.isEmpty) {
        throw Exception('Status record not found after update');
      }

      return result.first; // Return raw row for now
    } catch (e) {
      throw Exception('Failed to update message status: $e');
    }
  }

  /// Edit a message
  /// 
  /// Parameters:
  /// - messageId: The message to edit
  /// - newEncryptedContent: New encrypted message content
  /// - editedByUserId: UUID of user making the edit
  /// 
  /// Returns: Updated Message object

  /// 
  /// Validates that:
  /// - Message exists
  /// - Editor is the original sender
  /// - New content is different from original
  /// - Stores previous content in message_edits table
  /// 
  /// Parameters:
  /// - messageId: The message to edit
  /// - newEncryptedContent: New Base64-encoded encrypted content
  /// - editedByUserId: User ID of the editor (must be original sender)
  /// 
  /// Returns: Updated Message with editedAt timestamp
  Future<Message> editMessage({
    required String messageId,
    required String newEncryptedContent,
    required String editedByUserId,
  }) async {
    try {
      // Validate encrypted content format: supports both new (with ::) and old (plain base64) formats
      try {
        final parts = newEncryptedContent.split('::');
        if (parts.length == 3) {
          // New format: validate each part is base64
          for (final part in parts) {
            base64Decode(part);
          }
        } else {
          // Old format: validate entire string is base64
          base64Decode(newEncryptedContent);
        }
      } catch (e) {
        throw ArgumentError('Invalid encrypted content: must be valid Base64 encoding. Error: $e');
      }

      final message = await getMessageById(messageId);
      if (message == null) {
        throw ArgumentError('Message not found: $messageId');
      }

      // Validate only sender can edit
      if (message.senderId != editedByUserId) {
        throw ArgumentError('Only the message sender can edit a message');
      }

      if (message.isDeleted) {
        throw ArgumentError('Deleted messages cannot be edited');
      }

      if (message.encryptedContent == newEncryptedContent) {
        throw ArgumentError('Edited content must be different from the current message');
      }

      // Get current edit count to generate next edit number
      final editCountResult = await connection.query(
        '''
        SELECT COALESCE(MAX(edit_number), 0) as max_edit_number
        FROM message_edits
        WHERE message_id = @messageId
        ''',
        substitutionValues: {'messageId': messageId},
      );

      final currentEditCount =
          editCountResult.isNotEmpty ? editCountResult.first[0] as int : 0;
      final nextEditNumber = currentEditCount + 1;

      // Store previous content in message_edits table
      await connection.execute(
        '''
        INSERT INTO message_edits (
          id,
          message_id,
          edit_number,
          previous_content,
          edited_at,
          edited_by
        )
        VALUES (@editId, @messageId, @editNumber, @previousContent, @now, @editedBy)
        ''',
        substitutionValues: {
          'editId': _uuid.v4(),
          'messageId': messageId,
          'editNumber': nextEditNumber,
          'previousContent': message.encryptedContent,
          'now': DateTime.now(),
          'editedBy': editedByUserId,
        },
      );

      // Update message with new content and edited_at timestamp
      await connection.execute(
        '''
        UPDATE $_tableName
        SET encrypted_content = @newContent, edited_at = NOW()
        WHERE id = @messageId
        ''',
        substitutionValues: {
          'newContent': newEncryptedContent,
          'messageId': messageId,
        },
      );

      final updated = await getMessageById(messageId);
      if (updated == null) {
        throw Exception('Message not found after edit');
      }

      return updated;
    } on ArgumentError {
      rethrow;
    } catch (e) {
      throw Exception('Failed to edit message: $e');
    }
  }

  /// Soft-delete a message (marks as deleted but preserves in database)
  /// 
  /// Parameters:
  /// - messageId: The message to delete
  /// - deletedByUserId: UUID of user deleting the message
  /// 
  /// Returns: Updated Message with deleted_at timestamp
  Future<Message> deleteMessage(String messageId, String deletedByUserId) async {
    try {
      // Verify the deleter is the sender
      final message = await getMessageById(messageId);
      if (message == null) {
        throw ArgumentError('Message not found: $messageId');
      }

      if (message.senderId != deletedByUserId) {
        throw ArgumentError('Only the message sender can delete a message');
      }

      if (message.isDeleted) {
        throw ArgumentError('Message is already deleted');
      }

      // Soft-delete by marking is_deleted = true and setting deleted_at
      await connection.execute(
        '''
        UPDATE $_tableName
        SET is_deleted = TRUE, deleted_at = NOW()
        WHERE id = @messageId
        ''',
        substitutionValues: {'messageId': messageId},
      );

      // Fetch and return updated message
      final updated = await getMessageById(messageId);
      if (updated == null) {
        throw Exception('Message not found after delete');
      }

      return updated;
    } on ArgumentError {
      rethrow;
    } catch (e) {
      throw Exception('Failed to delete message: $e');
    }
  }

  /// Get count of unread messages for a user in a specific chat
  /// 
  /// Parameters:
  /// - chatId: The chat to check
  /// - userId: The recipient user
  /// 
  /// Returns: Number of unread messages
  Future<int> getUnreadCount(String chatId, String userId) async {
    try {
      final result = await connection.query(
        '''
        SELECT COUNT(*) as unread_count
        FROM message_delivery_status mds
        WHERE mds.recipient_id = @userId 
          AND mds.status != 'read'
          AND mds.message_id IN (
            SELECT id FROM messages WHERE chat_id = @chatId
          )
        ''',
        substitutionValues: {
          'userId': userId,
          'chatId': chatId,
        },
      );

      if (result.isEmpty) return 0;
      return result.first[0] as int;
    } catch (e) {
      throw Exception('Failed to get unread count: $e');
    }
  }
}
