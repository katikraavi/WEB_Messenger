import 'package:http/http.dart' as http;
import 'dart:convert';

/// Result from user search
class UserSearchResult {
  final String userId;
  final String username;
  final String email;
  final String? profilePictureUrl;
  final bool isPrivateProfile;

  UserSearchResult({
    required this.userId,
    required this.username,
    required this.email,
    this.profilePictureUrl,
    required this.isPrivateProfile,
  });

  /// Deserialize from JSON response
  factory UserSearchResult.fromJson(Map<String, dynamic> json) {
    return UserSearchResult(
      userId: json['userId'] as String,
      username: json['username'] as String,
      email: json['email'] as String,
      profilePictureUrl: json['profilePictureUrl'] as String?,
      isPrivateProfile: json['isPrivateProfile'] as bool? ?? false,
    );
  }

  /// Serialize to JSON
  Map<String, dynamic> toJson() => {
        'userId': userId,
        'username': username,
        'email': email,
        'profilePictureUrl': profilePictureUrl,
        'isPrivateProfile': isPrivateProfile,
      };

  @override
  String toString() =>
      'UserSearchResult(userId: $userId, username: $username, email: $email)';
}

/// Exception for search errors
class SearchException implements Exception {
  final String message;
  final int? statusCode;

  SearchException(this.message, {this.statusCode});

  @override
  String toString() => 'SearchException: $message${statusCode != null ? ' (HTTP $statusCode)' : ''}';
}

/// HTTP wrapper for search endpoints
class SearchService {
  final String baseUrl;
  final String Function() getAuthToken;

  SearchService({
    required this.baseUrl,
    required this.getAuthToken,
  });

  Future<List<UserSearchResult>> searchByUsername(String query) async {
    if (query.trim().isEmpty) {
      throw SearchException('Query cannot be empty');
    }

    final token = getAuthToken();
    if (token.isEmpty) {
      throw SearchException(
        'Authentication failed: Could not retrieve login token. '
        'Please quit the app and try logging in again. '
        'If on Linux, ensure your system keyring is unlocked.',
      );
    }

    try {
      final uri = Uri.parse('$baseUrl/search/username').replace(
        queryParameters: {'q': query, 'limit': '20'},
      );

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 401) {
        throw SearchException('Unauthorized - please login again', statusCode: 401);
      }

      if (response.statusCode == 400) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        throw SearchException(body['error'] as String? ?? 'Invalid search query', statusCode: 400);
      }

      if (response.statusCode != 200) {
        throw SearchException(
          'Search failed: ${response.reasonPhrase}',
          statusCode: response.statusCode,
        );
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final data = (body['data'] as List<dynamic>? ?? [])
          .map((item) => UserSearchResult.fromJson(item as Map<String, dynamic>))
          .toList();

      return data;
    } on SearchException {
      rethrow;
    } catch (e) {
      throw SearchException('Search failed: $e');
    }
  }

  Future<List<UserSearchResult>> searchByEmail(String query) async {
    if (query.trim().isEmpty) {
      throw SearchException('Query cannot be empty');
    }

    final token = getAuthToken();
    if (token.isEmpty) {
      throw SearchException(
        'Authentication failed: Could not retrieve login token. '
        'Please quit the app and try logging in again. '
        'If on Linux, ensure your system keyring is unlocked.',
      );
    }

    try {
      final uri = Uri.parse('$baseUrl/search/email').replace(
        queryParameters: {'q': query, 'limit': '20'},
      );

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 401) {
        throw SearchException('Unauthorized - please login again', statusCode: 401);
      }

      if (response.statusCode == 400) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        throw SearchException(body['error'] as String? ?? 'Invalid search query', statusCode: 400);
      }

      if (response.statusCode != 200) {
        throw SearchException(
          'Search failed: ${response.reasonPhrase}',
          statusCode: response.statusCode,
        );
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final data = (body['data'] as List<dynamic>? ?? [])
          .map((item) => UserSearchResult.fromJson(item as Map<String, dynamic>))
          .toList();

      return data;
    } on SearchException {
      rethrow;
    } catch (e) {
      throw SearchException('Search failed: $e');
    }
  }
}
