import 'dart:convert';
import 'package:http/http.dart' as http;

/// Group invite model returned by the backend.
class GroupInviteModel {
  final String id;
  final String groupId;
  final String groupName;
  final String invitedByUserId;
  final String invitedByUsername;
  final String status; // pending | accepted | declined
  final DateTime createdAt;

  GroupInviteModel({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.invitedByUserId,
    required this.invitedByUsername,
    required this.status,
    required this.createdAt,
  });

  factory GroupInviteModel.fromJson(Map<String, dynamic> json) {
    return GroupInviteModel(
      id: json['id'] as String,
      groupId: json['groupId'] as String,
      groupName: json['groupName'] as String? ?? 'Group',
      invitedByUserId: json['invitedByUserId'] as String,
      invitedByUsername: json['invitedByUsername'] as String? ?? 'Unknown',
      status: json['status'] as String? ?? 'pending',
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class GroupSummaryModel {
  final String id;
  final String name;
  final String createdBy;
  final DateTime createdAt;
  final bool isPublic;
  final String myRole;
  final int memberCount;

  GroupSummaryModel({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.createdAt,
    required this.isPublic,
    required this.myRole,
    required this.memberCount,
  });

  factory GroupSummaryModel.fromJson(Map<String, dynamic> json) {
    return GroupSummaryModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Group',
      createdBy: json['createdBy'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
      isPublic: json['isPublic'] as bool? ?? false,
      myRole: json['myRole'] as String? ?? 'member',
      memberCount: json['memberCount'] as int? ?? 0,
    );
  }
}

class GroupMemberModel {
  final String id;
  final String groupId;
  final String userId;
  final String role;
  final DateTime joinedAt;
  final String username;
  final String email;
  final String? profilePictureUrl;

  GroupMemberModel({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.role,
    required this.joinedAt,
    required this.username,
    required this.email,
    this.profilePictureUrl,
  });

  factory GroupMemberModel.fromJson(Map<String, dynamic> json) {
    return GroupMemberModel(
      id: json['id'] as String,
      groupId: json['groupId'] as String,
      userId: json['userId'] as String,
      role: json['role'] as String? ?? 'member',
      joinedAt: DateTime.parse(json['joinedAt'] as String),
      username: json['username'] as String? ?? 'Unknown',
      email: json['email'] as String? ?? '',
      profilePictureUrl: json['profilePictureUrl'] as String?,
    );
  }
}

class GroupSentInviteModel {
  final String id;
  final String groupId;
  final String senderId;
  final String receiverId;
  final String status;
  final DateTime createdAt;
  final String senderUsername;
  final String receiverUsername;
  final String receiverEmail;
  final String? receiverProfilePictureUrl;

  GroupSentInviteModel({
    required this.id,
    required this.groupId,
    required this.senderId,
    required this.receiverId,
    required this.status,
    required this.createdAt,
    required this.senderUsername,
    required this.receiverUsername,
    required this.receiverEmail,
    this.receiverProfilePictureUrl,
  });

  factory GroupSentInviteModel.fromJson(Map<String, dynamic> json) {
    return GroupSentInviteModel(
      id: json['id'] as String,
      groupId: json['groupId'] as String,
      senderId: json['senderId'] as String,
      receiverId: json['receiverId'] as String,
      status: json['status'] as String? ?? 'pending',
      createdAt: DateTime.parse(json['createdAt'] as String),
      senderUsername: json['senderUsername'] as String? ?? 'Unknown',
      receiverUsername: json['receiverUsername'] as String? ?? 'Unknown',
      receiverEmail: json['receiverEmail'] as String? ?? '',
      receiverProfilePictureUrl: json['receiverProfilePictureUrl'] as String?,
    );
  }
}

/// HTTP client for the group invitation endpoints.
///
/// Endpoint contract (backend/lib/src/endpoints/invite_endpoints.dart):
///   POST   /api/groups                       — create group
///   POST   /api/groups/:id/invite            — send invite to user
///   PATCH  /api/groups/invites/:id/accept    — accept invite
///   PATCH  /api/groups/invites/:id/decline   — decline invite
///   GET    /api/groups/invites/pending       — list pending invites for current user
class GroupInviteService {
  final String baseUrl;
  final http.Client _client;

  GroupInviteService({
    required this.baseUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  /// Create a new group chat.
  ///
  /// Returns the newly created group id.
  Future<String> createGroup({
    required String token,
    required String name,
    required List<String> memberUserIds,
  }) async {
    final uri = Uri.parse('$baseUrl/api/groups');
    final response = await _client.post(
      uri,
      headers: _headers(token),
      body: jsonEncode({'name': name, 'memberUserIds': memberUserIds}),
    );
    _assertSuccess(response, 'create group');
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['id'] as String;
  }

  /// Invite a user to an existing group.
  Future<void> sendGroupInvite({
    required String token,
    required String groupId,
    required String targetUserId,
  }) async {
    final uri = Uri.parse('$baseUrl/api/groups/$groupId/invite');
    final response = await _client.post(
      uri,
      headers: _headers(token),
      body: jsonEncode({'userId': targetUserId}),
    );
    _assertSuccess(response, 'send group invite');
  }

  /// Accept a pending group invite.
  Future<void> acceptInvite({
    required String token,
    required String inviteId,
  }) async {
    final uri = Uri.parse('$baseUrl/api/groups/invites/$inviteId/accept');
    final response = await _client.patch(
      uri,
      headers: _headers(token),
    );
    _assertSuccess(response, 'accept group invite');
  }

  /// Decline a pending group invite.
  Future<void> declineInvite({
    required String token,
    required String inviteId,
  }) async {
    final uri = Uri.parse('$baseUrl/api/groups/invites/$inviteId/decline');
    final response = await _client.patch(
      uri,
      headers: _headers(token),
    );
    _assertSuccess(response, 'decline group invite');
  }

  /// Fetch pending group invites for the authenticated user.
  Future<List<GroupInviteModel>> fetchPendingInvites({
    required String token,
  }) async {
    final uri = Uri.parse('$baseUrl/api/groups/invites/pending');
    final response = await _client.get(uri, headers: _headers(token));
    _assertSuccess(response, 'fetch pending group invites');
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => GroupInviteModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<GroupSummaryModel>> fetchGroups({
    required String token,
  }) async {
    final uri = Uri.parse('$baseUrl/api/groups');
    final response = await _client.get(uri, headers: _headers(token));
    _assertSuccess(response, 'fetch groups');
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => GroupSummaryModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<GroupSummaryModel> fetchGroupDetails({
    required String token,
    required String groupId,
  }) async {
    final uri = Uri.parse('$baseUrl/api/groups/$groupId');
    final response = await _client.get(uri, headers: _headers(token));
    _assertSuccess(response, 'fetch group details');
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return GroupSummaryModel.fromJson(body);
  }

  Future<List<GroupMemberModel>> fetchGroupMembers({
    required String token,
    required String groupId,
  }) async {
    final uri = Uri.parse('$baseUrl/api/groups/$groupId/members');
    final response = await _client.get(uri, headers: _headers(token));
    _assertSuccess(response, 'fetch group members');
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => GroupMemberModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<GroupSentInviteModel>> fetchGroupSentInvites({
    required String token,
    required String groupId,
  }) async {
    final uri = Uri.parse('$baseUrl/api/groups/$groupId/invites');
    final response = await _client.get(uri, headers: _headers(token));
    _assertSuccess(response, 'fetch group sent invites');
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => GroupSentInviteModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> deleteInvite({
    required String token,
    required String inviteId,
  }) async {
    final uri = Uri.parse('$baseUrl/api/groups/invites/$inviteId');
    final response = await _client.delete(uri, headers: _headers(token));
    _assertSuccess(response, 'delete group invite');
  }

  Future<void> leaveGroup({
    required String token,
    required String groupId,
  }) async {
    final uri = Uri.parse('$baseUrl/api/groups/$groupId/leave');
    final response = await _client.delete(uri, headers: _headers(token));
    _assertSuccess(response, 'leave group');
  }

  void _assertSuccess(http.Response response, String operation) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'GroupInviteService: $operation failed '
        '(HTTP ${response.statusCode}): ${response.body}',
      );
    }
  }
}
