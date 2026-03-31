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

    final senderMembership = await isGroupMember(groupId, senderId);
    if (!senderMembership) {
      throw Exception('Only group members can send invites');
    }

    final now = DateTime.now().toUtc();
    final inviteId = _uuid.v4();

    final result = await connection.query(
      '''INSERT INTO group_invites (id, group_id, sender_id, receiver_id, status, created_at)
         VALUES (@id, @group_id, @sender_id, @receiver_id, @status, @created_at)
         ON CONFLICT (group_id, receiver_id) DO UPDATE
         SET sender_id = EXCLUDED.sender_id,
             status = EXCLUDED.status,
             created_at = EXCLUDED.created_at
         RETURNING id, group_id, sender_id, receiver_id, status, created_at''',
      substitutionValues: {
        'id': inviteId,
        'group_id': groupId,
        'sender_id': senderId,
        'receiver_id': receiverId,
        'status': 'pending',
        'created_at': now,
      },
    );

    final row = result.first;
    return GroupInvite(
      id: row[0] as String,
      groupId: row[1] as String,
      senderId: row[2] as String,
      receiverId: row[3] as String,
      status: row[4] as String? ?? 'pending',
      createdAt: row[5] as DateTime,
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

  Future<bool> isGroupMember(String groupId, String userId) async {
    final result = await connection.query(
      '''SELECT 1
         FROM group_members
         WHERE group_id = @group_id AND user_id = @user_id
         LIMIT 1''',
      substitutionValues: {
        'group_id': groupId,
        'user_id': userId,
      },
    );
    return result.isNotEmpty;
  }

  Future<List<Map<String, dynamic>>> listGroupsForUser(String userId) async {
    final result = await connection.query(
      '''SELECT gc.id,
                gc.name,
                gc.created_by,
                gc.created_at,
                gc.is_public,
                gm_me.role,
                COUNT(gm_all.user_id) AS member_count,
                ARRAY_REMOVE(ARRAY_AGG(u.username ORDER BY gm_all.joined_at), NULL) AS participant_names
         FROM group_chats gc
         JOIN group_members gm_me
           ON gm_me.group_id = gc.id AND gm_me.user_id = @user_id
         LEFT JOIN group_members gm_all
           ON gm_all.group_id = gc.id
         LEFT JOIN users u
           ON u.id = gm_all.user_id
         WHERE gm_me.is_archived = false
         GROUP BY gc.id, gc.name, gc.created_by, gc.created_at, gc.is_public, gm_me.role
         ORDER BY gc.created_at DESC''',
      substitutionValues: {'user_id': userId},
    );

    final groups = <Map<String, dynamic>>[];
    for (final row in result) {
      final encryptedName = row[1] as String? ?? '';
      final createdBy = row[2] as String? ?? '';
      final participantNamesRaw = row[7];
      final participantNames = participantNamesRaw is List
          ? participantNamesRaw
                .whereType<String>()
                .map((name) => name.trim())
                .where((name) => name.isNotEmpty)
                .toList()
          : <String>[];
      groups.add({
        'id': row[0] as String,
        'name': await _safeDecryptGroupName(encryptedName, createdBy),
        'createdBy': createdBy,
        'createdAt': (row[3] as DateTime).toIso8601String(),
        'isPublic': row[4] as bool? ?? false,
        'myRole': row[5] as String? ?? 'member',
        'memberCount': (row[6] as int?) ?? 0,
        'participantNames': participantNames,
      });
    }
    return groups;
  }

  /// Get archived groups for a user (where is_archived = true for this member)
  Future<List<Map<String, dynamic>>> listArchivedGroupsForUser(String userId) async {
    final result = await connection.query(
      '''SELECT gc.id,
                gc.name,
                gc.created_by,
                gc.created_at,
                gc.is_public,
                gm_me.role,
                COUNT(gm_all.user_id) AS member_count,
                ARRAY_REMOVE(ARRAY_AGG(u.username ORDER BY gm_all.joined_at), NULL) AS participant_names
         FROM group_chats gc
         JOIN group_members gm_me
           ON gm_me.group_id = gc.id AND gm_me.user_id = @user_id
         LEFT JOIN group_members gm_all
           ON gm_all.group_id = gc.id
         LEFT JOIN users u
           ON u.id = gm_all.user_id
         WHERE gm_me.is_archived = true
         GROUP BY gc.id, gc.name, gc.created_by, gc.created_at, gc.is_public, gm_me.role
         ORDER BY gc.created_at DESC''',
      substitutionValues: {'user_id': userId},
    );

    final groups = <Map<String, dynamic>>[];
    for (final row in result) {
      final encryptedName = row[1] as String? ?? '';
      final createdBy = row[2] as String? ?? '';
      final participantNamesRaw = row[7];
      final participantNames = participantNamesRaw is List
          ? participantNamesRaw
                .whereType<String>()
                .map((name) => name.trim())
                .where((name) => name.isNotEmpty)
                .toList()
          : <String>[];
      groups.add({
        'id': row[0] as String,
        'name': await _safeDecryptGroupName(encryptedName, createdBy),
        'createdBy': createdBy,
        'createdAt': (row[3] as DateTime).toIso8601String(),
        'isPublic': row[4] as bool? ?? false,
        'myRole': row[5] as String? ?? 'member',
        'memberCount': (row[6] as int?) ?? 0,
        'participantNames': participantNames,
      });
    }
    return groups;
  }

  Future<Map<String, dynamic>?> getGroupDetails(String groupId, String userId) async {
    if (!await isGroupMember(groupId, userId)) {
      return null;
    }

    final result = await connection.query(
      '''SELECT gc.id,
                gc.name,
                gc.created_by,
                gc.created_at,
                gc.is_public,
                COUNT(gm.user_id) AS member_count
         FROM group_chats gc
         LEFT JOIN group_members gm ON gm.group_id = gc.id
         WHERE gc.id = @group_id
         GROUP BY gc.id, gc.name, gc.created_by, gc.created_at, gc.is_public
         LIMIT 1''',
      substitutionValues: {'group_id': groupId},
    );

    if (result.isEmpty) return null;
    final row = result.first;
    final encryptedName = row[1] as String? ?? '';
    final createdBy = row[2] as String? ?? '';
    return {
      'id': row[0] as String,
      'name': await _safeDecryptGroupName(encryptedName, createdBy),
      'createdBy': createdBy,
      'createdAt': (row[3] as DateTime).toIso8601String(),
      'isPublic': row[4] as bool? ?? false,
      'memberCount': (row[5] as int?) ?? 0,
    };
  }

  Future<List<Map<String, dynamic>>> listGroupMembersDetailed(
    String groupId,
    String requesterUserId,
  ) async {
    if (!await isGroupMember(groupId, requesterUserId)) {
      throw Exception('Not a group member');
    }

    final result = await connection.query(
      '''SELECT gm.id,
                gm.group_id,
                gm.user_id,
                gm.role,
                gm.joined_at,
                u.username,
                u.email,
                u.profile_picture_url
         FROM group_members gm
         JOIN users u ON u.id = gm.user_id
         WHERE gm.group_id = @group_id
         ORDER BY gm.joined_at ASC''',
      substitutionValues: {'group_id': groupId},
    );

    return result
        .map(
          (row) => {
            'id': row[0] as String,
            'groupId': row[1] as String,
            'userId': row[2] as String,
            'role': row[3] as String? ?? 'member',
            'joinedAt': (row[4] as DateTime).toIso8601String(),
            'username': row[5] as String? ?? 'Unknown',
            'email': row[6] as String? ?? '',
            'profilePictureUrl': row[7] as String?,
          },
        )
        .toList();
  }

  Future<List<String>> listGroupMemberIds(String groupId) async {
    final result = await connection.query(
      '''SELECT user_id
         FROM group_members
         WHERE group_id = @group_id
         ORDER BY joined_at ASC''',
      substitutionValues: {'group_id': groupId},
    );

    return result.map((row) => row[0] as String).toList();
  }

  Future<bool> groupExists(String groupId) async {
    final result = await connection.query(
      '''SELECT 1
         FROM group_chats
         WHERE id = @group_id
         LIMIT 1''',
      substitutionValues: {'group_id': groupId},
    );

    return result.isNotEmpty;
  }

  Future<List<Map<String, dynamic>>> listPendingSentInvites(
    String groupId,
    String requesterUserId,
  ) async {
    if (!await isGroupMember(groupId, requesterUserId)) {
      throw Exception('Not a group member');
    }

    final result = await connection.query(
      '''SELECT gi.id,
                gi.group_id,
                gi.sender_id,
                gi.receiver_id,
                gi.status,
                gi.created_at,
                sender.username,
                receiver.username,
                receiver.email,
                receiver.profile_picture_url
         FROM group_invites gi
         JOIN users sender ON sender.id = gi.sender_id
         JOIN users receiver ON receiver.id = gi.receiver_id
         WHERE gi.group_id = @group_id AND gi.status = 'pending'
         ORDER BY gi.created_at DESC''',
      substitutionValues: {'group_id': groupId},
    );

    return result
        .map(
          (row) => {
            'id': row[0] as String,
            'groupId': row[1] as String,
            'senderId': row[2] as String,
            'receiverId': row[3] as String,
            'status': row[4] as String? ?? 'pending',
            'createdAt': (row[5] as DateTime).toIso8601String(),
            'senderUsername': row[6] as String? ?? 'Unknown',
            'receiverUsername': row[7] as String? ?? 'Unknown',
            'receiverEmail': row[8] as String? ?? '',
            'receiverProfilePictureUrl': row[9] as String?,
          },
        )
        .toList();
  }

  Future<void> cancelInvite({
    required String inviteId,
    required String requesterUserId,
  }) async {
    final invite = await _getInviteById(inviteId);
    if (invite == null) {
      throw Exception('Invite not found');
    }

    final requesterIsMember = await isGroupMember(invite.groupId, requesterUserId);
    if (!requesterIsMember && invite.senderId != requesterUserId) {
      throw Exception('Not allowed to delete this invite');
    }

    await connection.execute(
      'DELETE FROM group_invites WHERE id = @id',
      substitutionValues: {'id': inviteId},
    );
  }

  Future<void> leaveGroup({
    required String groupId,
    required String userId,
  }) async {
    final isMember = await isGroupMember(groupId, userId);
    if (!isMember) {
      throw Exception('User is not a group member');
    }

    await connection.execute(
      '''DELETE FROM group_members
         WHERE group_id = @group_id AND user_id = @user_id''',
      substitutionValues: {
        'group_id': groupId,
        'user_id': userId,
      },
    );

    final remainingMembers = await connection.query(
      '''SELECT user_id, role
         FROM group_members
         WHERE group_id = @group_id
         ORDER BY joined_at ASC''',
      substitutionValues: {'group_id': groupId},
    );

    if (remainingMembers.isEmpty) {
      await connection.execute(
        'DELETE FROM group_chats WHERE id = @group_id',
        substitutionValues: {'group_id': groupId},
      );
      return;
    }

    final hasAdmin = remainingMembers.any((row) => (row[1] as String?) == 'admin');
    if (!hasAdmin) {
      final nextAdminUserId = remainingMembers.first[0] as String;
      await connection.execute(
        '''UPDATE group_members
           SET role = 'admin'
           WHERE group_id = @group_id AND user_id = @user_id''',
        substitutionValues: {
          'group_id': groupId,
          'user_id': nextAdminUserId,
        },
      );
    }
  }

  Future<String> _safeDecryptGroupName(String encryptedName, String createdBy) async {
    final raw = encryptedName.trim();
    if (raw.isEmpty) {
      return 'Group';
    }

    // Keep backward compatibility with older/plaintext rows.
    if (!encryptionService.isEncrypted(raw)) {
      return raw;
    }

    if (createdBy.isEmpty) {
      return 'Group';
    }

    try {
      final decrypted = await encryptionService.decrypt(raw, createdBy);
      return decrypted.trim().isEmpty ? 'Group' : decrypted.trim();
    } catch (_) {
      return 'Group';
    }
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
