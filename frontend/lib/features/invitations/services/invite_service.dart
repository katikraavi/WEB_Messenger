import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:frontend/core/services/api_client.dart';
import 'resilient_http_client.dart';

class User {
  final String id;
  final String username;
  final String email;
  final String? profilePictureUrl;

  User({
    required this.id,
    required this.username,
    required this.email,
    this.profilePictureUrl,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      username: json['username'] as String,
      email: json['email'] as String,
      profilePictureUrl: json['profilePictureUrl'] as String?,
    );
  }
}

class Invite {
  final String id;
  final String senderId;
  final String recipientId;
  final String senderName;
  final String? senderAvatar;
  final String status; // pending, accepted, declined
  final DateTime createdAt;

  Invite({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.senderName,
    this.senderAvatar,
    required this.status,
    required this.createdAt,
  });

  factory Invite.fromJson(Map<String, dynamic> json) {
    return Invite(
      id: json['id'] as String,
      senderId: json['senderId'] as String,
      recipientId: json['recipientId'] as String,
      senderName: json['senderName'] as String? ?? 'Unknown',
      senderAvatar: json['senderAvatar'] as String?,
      status: json['status'] as String? ?? 'pending',
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class InviteService {
  static const Duration defaultTimeout = Duration(seconds: 30);
  static const int maxRetries = 3;
  
  final ResilientHttpClient _client;
  String? _authToken;
  
  InviteService({String? authToken, http.Client? httpClient, Duration? timeout, int? maxRetries})
      : _authToken = authToken,
        _client = ResilientHttpClient(
          client: httpClient,
          timeout: timeout ?? defaultTimeout,
          maxRetryAttempts: maxRetries ?? 3,
        );

  static String get baseUrl => ApiClient.getBaseUrl();
  
  /// Search for users by username or email
  Future<List<User>> searchUsers(String query) async {
    try {
      if (query.isEmpty) {
        // Return empty list for empty search
        return [];
      }

      final response = await _client.get(
        Uri.parse('$baseUrl/api/users/search?q=${Uri.encodeQueryComponent(query)}'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => User.fromJson(json as Map<String, dynamic>)).toList();
      } else if (response.statusCode == 404) {
        return [];
      } else {
        throw Exception('Failed to search users: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Send a new invite to a user with timeout and retry
  Future<Invite> sendInvite(String recipientId) async {
    try {
      final token = await _getAuthToken();
      final response = await _client.post(
        Uri.parse('$baseUrl/api/invites'),
        headers: _buildHeaders(token),
        body: jsonEncode({'recipientId': recipientId}),
        retryOn401: false,
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Invite.fromJson(data as Map<String, dynamic>);
      } else if (response.statusCode == 400) {
        throw Exception('Invalid request: ${response.body}');
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed - please login again');
      } else {
        throw Exception('Failed to send invite: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Send multiple invites to recipients
  Future<List<Invite>> sendBulkInvites(List<String> recipientIds) async {
    try {
      final List<Invite> invites = [];
      for (final recipientId in recipientIds) {
        final invite = await sendInvite(recipientId);
        invites.add(invite);
      }
      return invites;
    } catch (e) {
      rethrow;
    }
  }

  /// Get pending invites for current user with timeout and retry
  Future<List<Invite>> getPendingInvites(String userId) async {
    try {
      final token = await _getAuthToken();
      final response = await _client.get(
        Uri.parse('$baseUrl/api/users/$userId/invites/pending'),
        headers: _buildHeaders(token),
        retryOn401: false,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Invite.fromJson(json as Map<String, dynamic>)).toList();
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed - please login again');
      } else {
        throw Exception('Failed to get pending invites: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Get count of pending invites with timeout and retry
  Future<int> getPendingInviteCount(String userId) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/api/users/$userId/invites/pending/count'),
        retryOn401: false,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['count'] as int? ?? 0;
      } else {
        throw Exception('Failed to get invite count: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Get sent invites for current user with timeout and retry
  Future<List<Invite>> getSentInvites(String userId) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/api/users/$userId/invites/sent'),
        retryOn401: false,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Invite.fromJson(json as Map<String, dynamic>)).toList();
      } else {
        throw Exception('Failed to get sent invites: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Accept a pending invite with timeout and retry
  Future<void> acceptInvite(String inviteId) async {
    try {
      final token = await _getAuthToken();
      final response = await _client.post(
        Uri.parse('$baseUrl/api/invites/$inviteId/accept'),
        headers: _buildHeaders(token),
        retryOn401: false,
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        if (response.statusCode == 401) {
          throw Exception('Authentication failed - please login again');
        } else if (response.statusCode == 404) {
          throw Exception('Invitation not found');
        } else {
          throw Exception('Failed to accept invite: ${response.statusCode}');
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Decline a pending invite with timeout and retry
  Future<void> declineInvite(String inviteId) async {
    try {
      final token = await _getAuthToken();
      final response = await _client.post(
        Uri.parse('$baseUrl/api/invites/$inviteId/decline'),
        headers: _buildHeaders(token),
        retryOn401: false,
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        if (response.statusCode == 401) {
          throw Exception('Authentication failed - please login again');
        } else if (response.statusCode == 404) {
          throw Exception('Invitation not found');
        } else {
          throw Exception('Failed to decline invite: ${response.statusCode}');
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Cancel a sent invite with timeout and retry
  Future<void> cancelInvite(String inviteId) async {
    try {
      final response = await _client.delete(
        Uri.parse('$baseUrl/api/invites/$inviteId'),
        headers: {'Content-Type': 'application/json'},
        retryOn401: false,
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Failed to cancel invite: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  void dispose() {
    _client.close();
  }

  /// Get auth token from secure storage
  Future<String?> _getAuthToken() async {
    if (_authToken != null) return _authToken;
    return null;
  }

  /// Build request headers with optional auth token
  Map<String, String> _buildHeaders(String? token) => {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };
}
