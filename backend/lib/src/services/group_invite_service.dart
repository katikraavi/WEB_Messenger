import 'package:postgres/postgres.dart';
import 'package:uuid/uuid.dart';

import '../models/group_chat.dart';
import 'encryption_service.dart';

typedef Connection = PostgreSQLConnection;

/// Service for group chat creation and invitation workflows.
class GroupInviteService {
  final Connection connection;
  final EncryptionService encryptionService;
  final Uuid _uuid = const Uuid();

  GroupInviteService({
    required this.connection,
    required this.encryptionService,
  });

  Future<GroupChat> createGroup({
    required String creatorUserId,
    required String name,
    bool isPublic = false,
  }) async {
    if (name.trim().isEmpty) {
      throw ArgumentError('Group name is required');
    }

    final id = _uuid.v4();
    final now = DateTime.now().toUtc();
    final encryptedName = await encryptionService.encrypt(name.trim(), creatorUserId);

    await connection.execute(
      '''INSERT INTO group_chats (id, name, created_by, created_at, is_public)
         VALUES (@id, @name, @created_by, @created_at, @is_public)''',
      substitutionValues: {
        'id': id,
        'name': encryptedName,
        'created_by': creatorUserId,
        'created_at': now,
        'is_public': isPublic,
      },
    );

    await connection.execute(
      '''INSERT INTO group_members (id, group_id, user_id, role, joined_at)
         VALUES (@id, @group_id, @user_id, @role, @joined_at)''',
      substitutionValues: {
        'id': _uuid.v4(),
        'group_id': id,
        'user_id': creatorUserId,
        'role': 'admin',
        'joined_at': now,
      },
    );

    return GroupChat(
      id: id,
      name: encryptedName,
      createdBy: creatorUserId,
      createdAt: now,
      isPublic: isPublic,
    );
  }

  Future<GroupInvite> sendGroupInvite({
    required String groupId,
    required String senderId,
    required String receiverId,
  }) async {
    if (senderId == receiverId) {
      throw ArgumentError('Cannot invite yourself');
    }

    final exists = await connection.query(
      '''SELECT id FROM group_members
         WHERE group_id = @group_id AND user_id = @user_id
         LIMIT 1''',
      substitutionValues: {
        'group_id': groupId,
        'user_id': receiverId,
      },
    );

    if (exists.isNotEmpty) {
      throw Exception('User is already a group member');
    }

    final now = DateTime.now().toUtc();
    final inviteId = _uuid.v4();

    await connection.execute(
      '''INSERT INTO group_invites (id, group_id, sender_id, receiver_id, status, created_at)
         VALUES (@id, @group_id, @sender_id, @receiver_id, @status, @created_at)''',
      substitutionValues: {
        'id': inviteId,
        'group_id': groupId,
        'sender_id': senderId,
        'receiver_id': receiverId,
        'status': 'pending',
        'created_at': now,
      },
    );

    return GroupInvite(
      id: inviteId,
      groupId: groupId,
      senderId: senderId,
      receiverId: receiverId,
      status: 'pending',
      createdAt: now,
    );
  }

  Future<void> acceptGroupInvite({
    required String inviteId,
    required String receiverId,
  }) async {
    final invite = await _getInviteById(inviteId);
    if (invite == null) {
      throw Exception('Invite not found');
    }
    if (invite.receiverId != receiverId) {
      throw Exception('Not allowed to accept this invite');
    }
    if (invite.status != 'pending') {
      throw Exception('Invite is no longer pending');
    }

    await connection.execute(
      '''UPDATE group_invites SET status = @status
         WHERE id = @id''',
      substitutionValues: {
        'status': 'accepted',
        'id': inviteId,
      },
    );

    await connection.execute(
      '''INSERT INTO group_members (id, group_id, user_id, role, joined_at)
         VALUES (@id, @group_id, @user_id, @role, @joined_at)
         ON CONFLICT (group_id, user_id) DO NOTHING''',
      substitutionValues: {
        'id': _uuid.v4(),
        'group_id': invite.groupId,
        'user_id': receiverId,
        'role': 'member',
        'joined_at': DateTime.now().toUtc(),
      },
    );
  }

  Future<void> declineGroupInvite({
    required String inviteId,
    required String receiverId,
  }) async {
    final invite = await _getInviteById(inviteId);
    if (invite == null) {
      throw Exception('Invite not found');
    }
    if (invite.receiverId != receiverId) {
      throw Exception('Not allowed to decline this invite');
    }
    if (invite.status != 'pending') {
      throw Exception('Invite is no longer pending');
    }

    await connection.execute(
      '''UPDATE group_invites SET status = @status
         WHERE id = @id''',
      substitutionValues: {
        'status': 'declined',
        'id': inviteId,
      },
    );
  }

  Future<List<GroupMember>> listGroupMembers(String groupId) async {
    final result = await connection.query(
      '''SELECT id, group_id, user_id, role, joined_at
         FROM group_members
         WHERE group_id = @group_id
         ORDER BY joined_at ASC''',
      substitutionValues: {'group_id': groupId},
    );

    return result
        .map((row) => GroupMember.fromMap({
              'id': row[0],
              'group_id': row[1],
              'user_id': row[2],
              'role': row[3],
              'joined_at': row[4],
            }))
        .toList();
  }

  Future<List<GroupInvite>> listPendingInvites(String receiverId) async {
    final result = await connection.query(
      '''SELECT id, group_id, sender_id, receiver_id, status, created_at
         FROM group_invites
         WHERE receiver_id = @receiver_id AND status = 'pending'
         ORDER BY created_at DESC''',
      substitutionValues: {'receiver_id': receiverId},
    );

    return result
        .map((row) => GroupInvite.fromMap({
              'id': row[0],
              'group_id': row[1],
              'sender_id': row[2],
              'receiver_id': row[3],
              'status': row[4],
              'created_at': row[5],
            }))
        .toList();
  }

  Future<GroupInvite?> _getInviteById(String inviteId) async {
    final result = await connection.query(
      '''SELECT id, group_id, sender_id, receiver_id, status, created_at
         FROM group_invites
         WHERE id = @id
         LIMIT 1''',
      substitutionValues: {'id': inviteId},
    );

    if (result.isEmpty) return null;
    final row = result.first;
    return GroupInvite.fromMap({
      'id': row[0],
      'group_id': row[1],
      'sender_id': row[2],
      'receiver_id': row[3],
      'status': row[4],
      'created_at': row[5],
    });
  }

  /// Validates a group name string.
  ///
  /// Throws [ArgumentError] if the name is empty or exceeds 100 characters.
  static void validateGroupName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Group name must not be empty.');
    }
    if (trimmed.length > 100) {
      throw ArgumentError('Group name must be 100 characters or fewer.');
    }
  }
}
