import 'package:postgres/postgres.dart';
import '../models/chat_invite.dart';
import 'package:uuid/uuid.dart';

/// Database-backed service for managing chat invitations
/// 
/// Handles business logic:
/// - Preventing self-invites (FR-001)
/// - Preventing duplicate pending invites
/// - Validating users exist and aren't already chatting (FR-002)
/// - CRUD operations on invitations (FR-003, FR-007, FR-008)
class InviteService {
  final Connection connection;

  InviteService(this.connection);

  /// Send a new invitation from sender to recipient (FR-001, FR-002, FR-003)
  Future<ChatInvite> sendInvite({
    required String senderId,
    required String recipientId,
  }) async {
    // Validation: No self-invites (FR-001)
    if (senderId == recipientId) {
      throw Exception('Cannot send invitation to yourself');
    }

    // Validation: Check both users exist
    final senderExists = await _userExists(senderId);
    if (!senderExists) {
      throw Exception('Sender user not found');
    }

    final recipientExists = await _userExists(recipientId);
    if (!recipientExists) {
      throw Exception('Recipient user not found');
    }

    // Validation: Check if users already have a chat (FR-002)
    final existingChat = await _chatExistsBetweenUsers(senderId, recipientId);
    if (existingChat) {
      throw Exception('Users already have an active chat');
    }

    // Validation: Check for existing pending invite from same sender
    // If one exists, delete it to allow re-inviting (handles case where recipient ignored/cleared notification)
    final existingPending = await _getExistingPendingInvite(senderId, recipientId);
    if (existingPending != null) {
      // Delete the old pending invite to allow a fresh invite attempt
      await connection.execute(
        Sql.named('DELETE FROM invites WHERE id = @inviteId'),
        parameters: {'inviteId': existingPending.id},
      );
    }

    // Create new invite (FR-003)
    final now = DateTime.now().toUtc();
    final id = const Uuid().v4();

    await connection.execute(
      Sql.named(
        '''INSERT INTO invites (id, sender_id, receiver_id, status, created_at)
           VALUES (@id, @sender_id, @receiver_id, @status, @created_at)''',
      ),
      parameters: {
        'id': id,
        'sender_id': senderId,
        'receiver_id': recipientId,
        'status': 'pending',
        'created_at': now,
      },
    );

    return ChatInvite(
      id: id,
      senderId: senderId,
      recipientId: recipientId,
      status: 'pending',
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
    );
  }

  /// Get all pending invitations for a recipient (FR-004)
  Future<List<Map<String, dynamic>>> getPendingInvites(String recipientId) async {
    final result = await connection.execute(
      Sql.named(
        '''SELECT 
             i.id, i.sender_id, i.receiver_id, i.status, 
             i.created_at, i.responded_at,
             u.username, u.profile_picture_url
           FROM invites i
           JOIN users u ON i.sender_id = u.id
           WHERE i.receiver_id = @receiver_id 
             AND i.status = 'pending'
           ORDER BY i.created_at DESC''',
      ),
      parameters: {'receiver_id': recipientId},
    );

    return result.map((row) {
      final map = row.toColumnMap() as Map<String, dynamic>;
      // Normalize column names for frontend compatibility
      map['recipient_id'] = map.remove('receiver_id');
      map['updated_at'] = map.remove('responded_at');
      map['deleted_at'] = null;
      return map;
    }).toList();
  }

  /// Get all sent invitations for a sender (FR-015)
  Future<List<Map<String, dynamic>>> getSentInvites(String senderId) async {
    final result = await connection.execute(
      Sql.named(
        '''SELECT 
             i.id, i.sender_id, i.receiver_id, i.status, 
             i.created_at, i.responded_at
           FROM invites i
           WHERE i.sender_id = @sender_id 
           ORDER BY i.created_at DESC''',
      ),
      parameters: {'sender_id': senderId},
    );

    return result.map((row) {
      final map = row.toColumnMap() as Map<String, dynamic>;
      // Normalize column names for frontend compatibility
      map['recipient_id'] = map.remove('receiver_id');
      map['updated_at'] = map.remove('responded_at');
      map['deleted_at'] = null;
      return map;
    }).toList();
  }

  /// Get count of pending invitations for a recipient (for badge - FR-012, FR-014)
  Future<int> getPendingInviteCount(String recipientId) async {
    final result = await connection.execute(
      Sql.named(
        '''SELECT COUNT(*) as count
           FROM invites
           WHERE receiver_id = @receiver_id 
             AND status = 'pending' ''',
      ),
      parameters: {'receiver_id': recipientId},
    );

    final row = result.first.toColumnMap();
    return (row['count'] as int?) ?? 0;
  }

  /// Accept an invitation - mark as accepted and creates a chat (FR-005)
  Future<ChatInvite> acceptInvite(String inviteId) async {
    final invite = await _getInviteById(inviteId);
    if (invite == null) {
      throw Exception('Invite not found');
    }

    if (invite.status != 'pending') {
      throw Exception('Invite is no longer pending');
    }

    final now = DateTime.now().toUtc();
    
    // Update invite status to accepted
    await connection.execute(
      Sql.named(
        '''UPDATE invites 
           SET status = @status, responded_at = @responded_at
           WHERE id = @id''',
      ),
      parameters: {
        'id': inviteId,
        'status': 'accepted',
        'responded_at': now,
      },
    );

    // Create a chat between the two users
    print('[InviteService] Creating chat for accepted invite ${invite.id}...');
    try {
      print('[InviteService] Calling _createChatBetweenUsers(${invite.senderId}, ${invite.recipientId})');
      await _createChatBetweenUsers(invite.senderId, invite.recipientId);
      print('[InviteService] ✓ Chat creation completed');
    } catch (e) {
      print('[InviteService] ✗ Failed to create chat after accepting invite: $e');
      // Don't fail the accept operation, but log the warning
    }

    return ChatInvite(
      id: invite.id,
      senderId: invite.senderId,
      recipientId: invite.recipientId,
      status: 'accepted',
      createdAt: invite.createdAt,
      updatedAt: now,
      deletedAt: null,
    );
  }

  /// Decline an invitation (FR-011)
  Future<ChatInvite> declineInvite(String inviteId) async {
    final invite = await _getInviteById(inviteId);
    if (invite == null) {
      throw Exception('Invite not found');
    }

    if (invite.status != 'pending') {
      throw Exception('Invite is no longer pending');
    }

    final now = DateTime.now().toUtc();

    // Update invite status to declined
    await connection.execute(
      Sql.named(
        '''UPDATE invites 
           SET status = @status, responded_at = @responded_at
           WHERE id = @id''',
      ),
      parameters: {
        'id': inviteId,
        'status': 'declined',
        'responded_at': now,
      },
    );

    return ChatInvite(
      id: invite.id,
      senderId: invite.senderId,
      recipientId: invite.recipientId,
      status: 'declined',
      createdAt: invite.createdAt,
      updatedAt: now,
      deletedAt: null,
    );
  }

  // Private helper methods

  Future<bool> _userExists(String userId) async {
    final result = await connection.execute(
      Sql.named('SELECT 1 FROM users WHERE id = @id LIMIT 1'),
      parameters: {'id': userId},
    );
    return result.isNotEmpty;
  }

  Future<bool> _chatExistsBetweenUsers(String userId1, String userId2) async {
    final result = await connection.execute(
      Sql.named(
        '''SELECT 1 FROM chats 
           WHERE (participant_1_id = @user1 AND participant_2_id = @user2)
              OR (participant_1_id = @user2 AND participant_2_id = @user1)
           LIMIT 1''',
      ),
      parameters: {'user1': userId1, 'user2': userId2},
    );
    return result.isNotEmpty;
  }

  Future<ChatInvite?> _getExistingPendingInvite(String senderId, String recipientId) async {
    final result = await connection.execute(
      Sql.named(
        '''SELECT * FROM invites 
           WHERE sender_id = @sender_id 
             AND receiver_id = @receiver_id 
             AND status = 'pending'
           LIMIT 1''',
      ),
      parameters: {'sender_id': senderId, 'receiver_id': recipientId},
    );

    if (result.isEmpty) return null;

    final row = result.first.toColumnMap();
    return ChatInvite(
      id: row['id'] as String,
      senderId: row['sender_id'] as String,
      recipientId: row['receiver_id'] as String,
      status: row['status'] as String,
      createdAt: row['created_at'] as DateTime,
      updatedAt: row['responded_at'] as DateTime?,
      deletedAt: null,
    );
  }

  Future<ChatInvite?> _getInviteById(String inviteId) async {
    final result = await connection.execute(
      Sql.named('SELECT * FROM invites WHERE id = @id LIMIT 1'),
      parameters: {'id': inviteId},
    );

    if (result.isEmpty) return null;

    final row = result.first.toColumnMap();
    return ChatInvite(
      id: row['id'] as String,
      senderId: row['sender_id'] as String,
      recipientId: row['receiver_id'] as String,
      status: row['status'] as String,
      createdAt: row['created_at'] as DateTime,
      updatedAt: row['responded_at'] as DateTime?,
      deletedAt: null,
    );
  }

  /// Create a 1:1 chat between two users for accepted invitation
  /// 
  /// Helper method to create a chat when an invitation is accepted.
  /// The chat will appear in both users' messenger tabs automatically.
  Future<void> _createChatBetweenUsers(String userId1, String userId2) async {
    try {
      // Ensure participant_1_id < participant_2_id for consistency
      final participant1Id = userId1.compareTo(userId2) < 0 ? userId1 : userId2;
      final participant2Id = userId1.compareTo(userId2) < 0 ? userId2 : userId1;

      final now = DateTime.now().toUtc();
      
      // Insert chat or update if already exists
      await connection.execute(
        Sql.named(
          '''INSERT INTO chats 
             (id, participant_1_id, participant_2_id, is_participant_1_archived, 
              is_participant_2_archived, created_at, updated_at)
             VALUES (@id, @participant1, @participant2, @archived1, @archived2, @now, @now)
             ON CONFLICT (participant_1_id, participant_2_id) 
             DO UPDATE SET updated_at = @now''',
        ),
        parameters: {
          'id': const Uuid().v4(),
          'participant1': participant1Id,
          'participant2': participant2Id,
          'archived1': false,
          'archived2': false,
          'now': now,
        },
      );
      print('[InviteService] ✓ Chat created between $userId1 and $userId2');
    } catch (e) {
      throw Exception('Failed to create chat between users: $e');
    }
  }
}
