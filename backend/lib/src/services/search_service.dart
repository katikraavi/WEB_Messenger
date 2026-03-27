import 'package:postgres/postgres.dart';
import 'dart:convert';

import '../models/user_search_result.dart';
import '../models/search_query.dart';
import '../models/message_search_result.dart';
import 'service_config.dart';

// Alias for cleaner code
typedef Connection = PostgreSQLConnection;

/// Exception for search validation errors
class SearchValidationException implements Exception {
  final String message;
  SearchValidationException(this.message);

  @override
  String toString() => 'SearchValidationException: $message';
}

/// Service for searching users
class SearchService {
  final Connection _connection;

  SearchService(this._connection);

  /// Search users by username (case-insensitive, partial match allowed)
  Future<List<UserSearchResult>> searchByUsername(String query,
      [int maxResults = 10]) async {
    // Validate query
    final validationError = SearchQuery.validateQuery(query, SearchType.username);
    if (validationError != null) {
      throw SearchValidationException(validationError);
    }

    // Ensure limit is reasonable
    final limit = _constrain(maxResults);

    try {
      final results = await _connection.mappedResultsQuery(
        '''
        SELECT id, username, email, profile_picture_url
        FROM \"users\"
        WHERE LOWER(username) ILIKE LOWER(@query || '%')
          AND email_verified = true
        ORDER BY 
          CASE WHEN LOWER(username) = LOWER(@query) THEN 0 ELSE 1 END,
          username ASC
        LIMIT @limit
        ''',
        substitutionValues: {
          'query': query.trim(),
          'limit': limit,
        },
      );

      return results
          .map((row) => UserSearchResult.fromRow(_flattenMappedRow(row)))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Search users by email (case-insensitive, exact match prioritized)
  Future<List<UserSearchResult>> searchByEmail(String query,
      [int maxResults = 10]) async {
    // Validate query
    final validationError = SearchQuery.validateQuery(query, SearchType.email);
    if (validationError != null) {
      throw SearchValidationException(validationError);
    }

    // Ensure limit is reasonable
    final limit = _constrain(maxResults);

    try {
      final results = await _connection.mappedResultsQuery(
        '''
        SELECT id, username, email, profile_picture_url
        FROM \"users\"
        WHERE (LOWER(email) = LOWER(@query) 
               OR LOWER(email) ILIKE LOWER(@query || '%'))
          AND email_verified = true
        ORDER BY 
          CASE WHEN LOWER(email) = LOWER(@query) THEN 0 ELSE 1 END,
          email ASC
        LIMIT @limit
        ''',
        substitutionValues: {
          'query': query.trim(),
          'limit': limit,
        },
      );

      return results
          .map((row) => UserSearchResult.fromRow(_flattenMappedRow(row)))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Search decrypted message content within a single chat.
  Future<List<MessageSearchResult>> searchMessageContent(
    String chatId,
    String query,
  ) async {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return const [];
    }

    final results = await _connection.mappedResultsQuery(
      '''
      SELECT id, encrypted_content, sender_id, created_at
      FROM messages
      WHERE chat_id = @chatId
        AND is_deleted = FALSE
      ORDER BY created_at DESC
      LIMIT 200
      ''',
      substitutionValues: {
        'chatId': chatId,
      },
    );

    final matches = <MessageSearchResult>[];

    for (final row in results) {
      final map = _flattenMappedRow(row);
      final messageId = map['id'] as String;
      final encryptedContent = map['encrypted_content'] as String;
      final senderId = map['sender_id'] as String;
      final createdAt = map['created_at'] as DateTime;

      final plaintext = await _decodeMessageContent(
        encryptedContent: encryptedContent,
        senderId: senderId,
      );

      final lowerPlaintext = plaintext.toLowerCase();
      final matchIndex = lowerPlaintext.indexOf(normalizedQuery);
      if (matchIndex == -1) {
        continue;
      }

      matches.add(
        MessageSearchResult(
          messageId: messageId,
          snippet: _buildSnippet(plaintext, matchIndex, normalizedQuery.length),
          sentAt: createdAt,
        ),
      );
    }

    return matches;
  }

  /// Constrain limit to reasonable bounds
  static int _constrain(int maxResults) {
    if (maxResults <= 0) return 10;
    if (maxResults > SearchQuery.maxResults) return SearchQuery.maxResults;
    return maxResults;
  }

  Future<String> _decodeMessageContent({
    required String encryptedContent,
    required String senderId,
  }) async {
    try {
      if (ServiceConfig.encryptionService.isEncrypted(encryptedContent)) {
        return await ServiceConfig.encryptionService.decrypt(
          encryptedContent,
          senderId,
        );
      }
    } catch (_) {
      // Fall through to legacy Base64 decoding.
    }

    try {
      return utf8.decode(base64Decode(encryptedContent));
    } catch (_) {
      return encryptedContent;
    }
  }

  String _buildSnippet(String plaintext, int matchIndex, int matchLength) {
    const contextRadius = 24;
    final start = (matchIndex - contextRadius).clamp(0, plaintext.length);
    final end = (matchIndex + matchLength + contextRadius).clamp(0, plaintext.length);
    return plaintext.substring(start, end).trim();
  }

  Map<String, dynamic> _flattenMappedRow(Map<String, Map<String, dynamic>> row) {
    final flattened = <String, dynamic>{};
    for (final tableData in row.values) {
      flattened.addAll(tableData);
    }
    return flattened;
  }

  // ---------------------------------------------------------------------------
  // Pure / static helpers used by unit tests and endpoint input validation.
  // ---------------------------------------------------------------------------

  /// Trims and lowercases a search query.
  static String sanitizeQuery(String query) => query.trim().toLowerCase();

  /// Returns true if [query] meets length requirements (2–200 chars after trim).
  static bool isQueryValid(String query) {
    final trimmed = query.trim();
    return trimmed.length >= 2 && trimmed.length <= 200;
  }

  /// Extracts a snippet of up to [maxLength] characters centred around the
  /// first occurrence of [query] in [content].
  static String extractSnippet({
    required String content,
    required String query,
    int maxLength = 200,
  }) {
    if (content.length <= maxLength) return content;
    final idx = content.toLowerCase().indexOf(query.toLowerCase());
    if (idx < 0) return content.substring(0, maxLength);
    final start = (idx - maxLength ~/ 2).clamp(0, content.length);
    final end = (start + maxLength).clamp(0, content.length);
    return content.substring(start, end);
  }
}
