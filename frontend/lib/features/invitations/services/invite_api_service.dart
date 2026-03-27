import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/chat_invite_model.dart';
import '../../../utils/secure_storage_wrapper.dart';
import 'invite_error_handler.dart';

/// API service for invite-related HTTP operations
class InviteApiService {
  final String _baseUrl;
  String? _authToken;
  String? _userId;
  final http.Client _httpClient;
  final SecureStorageWrapper _secureStorage = SecureStorageWrapper();

  InviteApiService({
    required String baseUrl,
    String? authToken,
    String? userId,
    http.Client? httpClient,
  })  : _baseUrl = baseUrl,
        _authToken = authToken,
        _userId = userId,
        _httpClient = httpClient ?? http.Client();

  /// Get auth token (always read fresh from storage to handle auth switches)
  Future<String?> _getAuthToken() async {
    try {
      final token = await _secureStorage.read(key: 'auth_token');
      if (token != null) {
      } else {
      }
      return token;
    } catch (e) {
      return null;
    }
  }

  /// Get user ID (always read fresh from storage to handle auth switches)
  Future<String?> _getUserId() async {
    try {
      final userId = await _secureStorage.read(key: 'user_id');
      if (userId != null) {
      } else {
      }
      return userId;
    } catch (e) {
      return null;
    }
  }

  /// Send a new invitation to a user
  /// POST /api/invites (or POST /api/users/<userId>/invites/send)
  /// 
  /// Returns: ChatInviteModel
  /// Throws: HttpException on error
  Future<ChatInviteModel> sendInvite(String recipientId) async {
    try {
      final token = await _getAuthToken();
      
      
      // Try POST /api/invites first (generic endpoint) with timeout
      final response = await _makeRequest(
        () => _httpClient.post(
          Uri.parse('$_baseUrl/api/invites'),
          headers: _buildHeaders(token),
          body: jsonEncode({'recipientId': recipientId}),
        ),
      );


      if (response.statusCode == 201) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return _parseInvite(json);
      } else if (response.statusCode == 409) {
        throw HttpException('Pending invitation already exists (409)', response.statusCode);
      } else if (response.statusCode == 400) {
        throw HttpException('Validation error: ${response.body}', response.statusCode);
      } else if (response.statusCode == 401) {
        throw TokenExpiredException('Session expired');
      } else {
        throw HttpException('Failed to send invite: ${response.statusCode}', response.statusCode);
      }
    } on NetworkTimeoutException {
      rethrow;
    } on TokenExpiredException {
      rethrow;
    } on NetworkException {
      rethrow;
    } catch (e) {
      InviteErrorHandler.logError('sendInvite', e);
      rethrow;
    }
  }

  /// Fetch pending invitations for the current user
  /// GET /api/users/<userId>/invites/pending
  /// 
  /// Returns: List<ChatInviteModel>
  /// Throws: HttpException on error
  Future<List<ChatInviteModel>> fetchPendingInvites() async {
    try {
      final token = await _getAuthToken();
      final userId = await _getUserId();
      
      if (userId == null) {
        // Return empty list during logout/auth transitions
        return [];
      }
      
      // Backend route: GET /api/users/<userId>/invites/pending
      final url = Uri.parse('$_baseUrl/api/users/$userId/invites/pending');
      final headers = _buildHeaders(token);
      
      
      final response = await _httpClient.get(url, headers: headers);

      
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as List<dynamic>;
        return json.map((item) => _parseInvite(item as Map<String, dynamic>)).toList();
      } else if (response.statusCode == 401) {
        throw HttpException('Unauthorized', response.statusCode);
      } else if (response.statusCode == 404) {
        throw HttpException('Endpoint not found: /api/users/$userId/invites/pending', response.statusCode);
      } else {
        throw HttpException('Failed to fetch pending invites: ${response.statusCode}', response.statusCode);
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Fetch sent invitations for the current user
  /// GET /api/users/<userId>/invites/sent
  /// 
  /// Returns: List<ChatInviteModel>
  /// Throws: HttpException on error
  Future<List<ChatInviteModel>> fetchSentInvites() async {
    try {
      final token = await _getAuthToken();
      final userId = await _getUserId();
      
      if (userId == null) {
        // Return empty list during logout/auth transitions
        return [];
      }
      
      // Try the user-specific endpoint first
      final url = Uri.parse('$_baseUrl/api/users/$userId/invites/sent');
      final response = await _httpClient.get(
        url,
        headers: _buildHeaders(token),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as List<dynamic>;
        return json.map((item) => _parseInvite(item as Map<String, dynamic>)).toList();
      } else if (response.statusCode == 401) {
        throw HttpException('Unauthorized', response.statusCode);
      } else if (response.statusCode == 404) {
        // Return empty list as fallback
        return [];
      } else {
        throw HttpException('Failed to fetch sent invites: ${response.statusCode}', response.statusCode);
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Accept an invitation
  /// POST /api/invites/{id}/accept
  /// 
  /// Returns: ChatInviteModel
  /// Throws: HttpException on error
  Future<ChatInviteModel> acceptInvite(String inviteId) async {
    try {
      final token = await _getAuthToken();
      
      
      final response = await _httpClient.post(
        Uri.parse('$_baseUrl/api/invites/$inviteId/accept'),
        headers: _buildHeaders(token),
      );


      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return _parseInvite(json);
      } else if (response.statusCode == 401) {
        throw HttpException('Unauthorized', response.statusCode);
      } else if (response.statusCode == 404) {
        throw HttpException('Invitation not found', response.statusCode);
      } else {
        throw HttpException('Failed to accept invite: ${response.statusCode}', response.statusCode);
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Decline an invitation
  /// POST /api/invites/{id}/decline
  /// 
  /// Returns: ChatInviteModel
  /// Throws: HttpException on error
  Future<ChatInviteModel> declineInvite(String inviteId) async {
    try {
      final token = await _getAuthToken();
      
      
      final response = await _httpClient.post(
        Uri.parse('$_baseUrl/api/invites/$inviteId/decline'),
        headers: _buildHeaders(token),
      );


      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return _parseInvite(json);
      } else if (response.statusCode == 401) {
        throw HttpException('Unauthorized', response.statusCode);
      } else if (response.statusCode == 404) {
        throw HttpException('Invitation not found', response.statusCode);
      } else {
        throw HttpException('Failed to decline invite: ${response.statusCode}', response.statusCode);
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Cancel an invitation (sender only)
  /// POST /api/invites/{id}/cancel
  /// 
  /// Returns: ChatInviteModel
  /// Throws: HttpException on error
  Future<ChatInviteModel> cancelInvite(String inviteId) async {
    try {
      final token = await _getAuthToken();
      
      
      final response = await _httpClient.post(
        Uri.parse('$_baseUrl/api/invites/$inviteId/cancel'),
        headers: _buildHeaders(token),
      );


      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return _parseInvite(json);
      } else if (response.statusCode == 401) {
        throw HttpException('Unauthorized', response.statusCode);
      } else if (response.statusCode == 403) {
        throw HttpException('Only the sender can cancel this invitation', response.statusCode);
      } else if (response.statusCode == 404) {
        throw HttpException('Invitation not found', response.statusCode);
      } else {
        throw HttpException('Failed to cancel invite: ${response.statusCode}', response.statusCode);
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Get count of pending invites (for badge)
  /// GET /api/users/<userId>/invites/pending/count
  /// 
  /// Returns: int
  /// Throws: HttpException on error
  Future<int> getPendingInviteCount() async {
    try {
      final token = await _getAuthToken();
      final userId = await _getUserId();
      
      if (userId == null) {
        // Return 0 during logout/auth transitions
        return 0;
      }
      
      final url = Uri.parse('$_baseUrl/api/users/$userId/invites/pending/count');
      final response = await _httpClient.get(
        url,
        headers: _buildHeaders(token),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final count = json['count'] as int? ?? 0;
        return count;
      } else if (response.statusCode == 401) {
        throw HttpException('Unauthorized', response.statusCode);
      } else if (response.statusCode == 404) {
        // Fallback to fetching all pending invites and returning length
        final invites = await fetchPendingInvites();
        return invites.length;
      } else {
        throw HttpException('Failed to get invite count: ${response.statusCode}', response.statusCode);
      }
    } catch (e) {
      rethrow;
    }
  }

  // Private helpers

  Map<String, String> _buildHeaders(String? token) => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  /// Make an HTTP request with timeout handling
  Future<http.Response> _makeRequest(
    Future<http.Response> Function() requestFn, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    try {
      return await requestFn().timeout(
        timeout,
        onTimeout: () {
          throw NetworkTimeoutException(
            'Request timed out after ${timeout.inSeconds} seconds',
            timeout: timeout,
          );
        },
      );
    } on NetworkTimeoutException {
      rethrow;
    } catch (e) {
      if (e.toString().contains('SocketException') || 
          e.toString().contains('HandshakeException')) {
        throw NetworkException('Connection error: ${e.toString()}', originalError: e);
      }
      rethrow;
    }
  }

  ChatInviteModel _parseInvite(Map<String, dynamic> json) {
    return ChatInviteModel(
      id: json['id'] as String,
      senderId: json['senderId'] as String? ?? json['sender_id'] as String,
      senderName: json['senderName'] as String? ?? json['sender_name'] as String? ?? 'Unknown',
      senderAvatarUrl: json['senderAvatarUrl'] as String? ?? json['sender_avatar_url'] as String?,
      recipientId: json['recipientId'] as String? ?? json['recipient_id'] as String,
      recipientName: json['recipientName'] as String? ?? json['recipient_name'] as String?,
      recipientAvatarUrl: json['recipientAvatarUrl'] as String? ?? json['recipient_avatar_url'] as String?,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String? ?? json['created_at'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String? ?? json['updated_at'] as String),
      deletedAt: json['deletedAt'] != null ? DateTime.parse(json['deletedAt'] as String) : null,
    );
  }
}

/// HTTP Exception for API errors
class HttpException implements Exception {
  final String message;
  final int? statusCode;

  HttpException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}
