/// Query object for user search with validation
class SearchQuery {
  static const int minLength = 1;
  static const int maxLength = 100;
  static const int maxResults = 50;

  final String query;
  final SearchType type;
  final int limit;

  SearchQuery({
    required this.query,
    required this.type,
    this.limit = 10,
  });

  /// Validate query string (returns error message or null if valid)
  static String? validateQuery(String query, SearchType type) {
    final trimmed = query.trim();

    // Length check
    if (trimmed.length < minLength) {
      return 'Search query must be at least $minLength characters';
    }
    if (trimmed.length > maxLength) {
      return 'Search query cannot exceed $maxLength characters';
    }

    switch (type) {
      case SearchType.username:
        // username: alphanumeric, underscore, hyphen only
        // Allow @ and . for email-like queries that get routed here from combined search
        if (!RegExp(r'^[a-zA-Z0-9_\-@.]+$').hasMatch(trimmed)) {
          return 'Invalid search query';
        }
        break;

      case SearchType.email:
        // email: more lenient - as long as it has @ or a dot, allow it
        // This handles partial email searches like "alice@" or "alice.smith"
        if (!trimmed.contains('@') && !trimmed.contains('.')) {
          return 'Search query must contain @ or . for email search';
        }
        break;
    }

    return null;
  }
}

/// Type of search to perform
enum SearchType {
  username,
  email,
}
