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

  void _assertSuccess(http.Response response, String operation) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'GroupInviteService: $operation failed '
        '(HTTP ${response.statusCode}): ${response.body}',
      );
    }
  }
}
