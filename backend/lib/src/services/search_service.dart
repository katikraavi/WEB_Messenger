import 'package:postgres/postgres.dart';
import '../models/user_search_result.dart';
import '../models/search_query.dart';

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
  Future<List<UserSearchResult>> searchByUsername(
    String query,
    int maxResults = 10,
  ) async {
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
          .map((row) => UserSearchResult.fromRow(row.toColumnMap()))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Search users by email (case-insensitive, exact match prioritized)
  Future<List<UserSearchResult>> searchByEmail(
    String query,
    int maxResults = 10,
  ) async {
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
          .map((row) => UserSearchResult.fromRow(row.toColumnMap()))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Constrain limit to reasonable bounds
  static int _constrain(int maxResults) {
    if (maxResults <= 0) return 10;
    if (maxResults > SearchQuery.maxResults) return SearchQuery.maxResults;
    return maxResults;
  }
}
