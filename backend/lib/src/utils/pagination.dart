/// Pagination provider for handling large invitation lists
/// 
/// T061: Performance optimization with pagination
/// 
/// Implements cursor-based pagination for efficient large dataset handling
/// Reduces memory usage and improves app responsiveness
class PaginationState {
  final List<dynamic> items;
  final int pageSize;
  final String? nextCursor;
  final bool hasMore;
  final bool isLoading;
  final String? error;

  const PaginationState({
    this.items = const [],
    this.pageSize = 20,
    this.nextCursor,
    this.hasMore = false,
    this.isLoading = false,
    this.error,
  });

  /// Create initial pagination state
  PaginationState.initial({int pageSize = 20})
    : items = [],
      pageSize = pageSize,
      nextCursor = null,
      hasMore = true,
      isLoading = false,
      error = null;

  /// Copy with updated fields
  PaginationState copyWith({
    List<dynamic>? items,
    int? pageSize,
    String? nextCursor,
    bool? hasMore,
    bool? isLoading,
    String? error,
  }) {
    return PaginationState(
      items: items ?? this.items,
      pageSize: pageSize ?? this.pageSize,
      nextCursor: nextCursor,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  /// Reset to initial state
  PaginationState reset() {
    return PaginationState.initial(pageSize: pageSize);
  }

  /// Add more items to list
  PaginationState appendItems(
    List<dynamic> newItems, {
    required String? nextCursor,
    required bool hasMore,
  }) {
    return copyWith(
      items: [...items, ...newItems],
      nextCursor: nextCursor,
      hasMore: hasMore,
      isLoading: false,
    );
  }
}

/// Pagination utilities for database queries
class PaginationUtils {
  /// Generate LIMIT and OFFSET for SQL query
  /// 
  /// Parameters:
  /// - page: Page number (1-indexed)
  /// - pageSize: Items per page
  /// 
  /// Returns: Map with limit and offset
  static Map<String, int> getQueryParams({
    required int page,
    required int pageSize,
  }) {
    final offset = (page - 1) * pageSize;
    return {
      'limit': pageSize,
      'offset': offset,
    };
  }

  /// Calculate if more pages available
  /// 
  /// Parameters:
  /// - totalItems: Total items count
  /// - currentPage: Current page number
  /// - pageSize: Items per page
  /// 
  /// Returns: true if more pages available
  static bool hasMorePages({
    required int totalItems,
    required int currentPage,
    required int pageSize,
  }) {
    return (currentPage * pageSize) < totalItems;
  }

  /// Calculate total pages
  static int getTotalPages(int totalItems, int pageSize) {
    return (totalItems + pageSize - 1) ~/ pageSize;
  }

  /// Validate pagination parameters
  /// 
  /// Returns: true if valid
  static bool isValid({
    required int page,
    required int pageSize,
  }) {
    return page > 0 && pageSize > 0 && pageSize <= 100;
  }
}

/// Query optimization recommendations
/// 
/// T062: Database query optimization
/// 
/// Current indexes in chat_invites table:
/// - (recipient_id, status) - For getPendingInvites query
/// - (sender_id, status) - For getSentInvites query
/// 
/// Recommended queries:
abstract class InvitationQueries {
  /// Get pending invitations with pagination
  /// 
  /// Query structure (optimized):
  /// ```sql
  /// SELECT i.id, i.sender_id, i.recipient_id, i.status,
  ///        i.created_at, i.updated_at,
  ///        u.username, u.avatar_url
  /// FROM chat_invites i
  /// JOIN "user" u ON i.sender_id = u.id
  /// WHERE i.recipient_id = @recipient_id 
  ///   AND i.status = 'pending'
  ///   AND i.deleted_at IS NULL
  /// ORDER BY i.created_at DESC
  /// LIMIT @limit OFFSET @offset
  /// ```
  /// 
  /// Index efficiency: HIGH
  /// - Uses (recipient_id, status) index
  /// - Avoids full table scan
  /// - Ordered by index-friendly column
  static const String getPendingInvites = '''
    SELECT i.id, i.sender_id, i.recipient_id, i.status,
           i.created_at, i.updated_at, i.deleted_at,
           u.id as sender_id, u.username, u.avatar_url
    FROM chat_invites i
    JOIN "user" u ON i.sender_id = u.id
    WHERE i.recipient_id = @recipient_id 
      AND i.status = 'pending'
      AND i.deleted_at IS NULL
    ORDER BY i.created_at DESC
    LIMIT @limit OFFSET @offset
  ''';

  /// Get sent invitations with pagination
  /// 
  /// Similar optimization as getPendingInvites
  /// Uses (sender_id, status) index
  static const String getSentInvites = '''
    SELECT i.id, i.sender_id, i.recipient_id, i.status,
           i.created_at, i.updated_at, i.deleted_at,
           u.id as recipient_id, u.username, u.avatar_url
    FROM chat_invites i
    JOIN "user" u ON i.recipient_id = u.id
    WHERE i.sender_id = @sender_id 
      AND i.deleted_at IS NULL
    ORDER BY i.created_at DESC
    LIMIT @limit OFFSET @offset
  ''';

  /// Get pending invite count (no pagination needed)
  /// 
  /// Query structure (optimized):
  /// ```sql
  /// SELECT COUNT(*) as count
  /// FROM chat_invites
  /// WHERE recipient_id = @recipient_id 
  ///   AND status = 'pending'
  ///   AND deleted_at IS NULL
  /// ```
  /// 
  /// Index efficiency: HIGH
  /// - Single row result
  /// - Uses existing index for WHERE clause
  /// - Minimal data transfer
  static const String getPendingInviteCount = '''
    SELECT COUNT(*) as count
    FROM chat_invites
    WHERE recipient_id = @recipient_id 
      AND status = 'pending'
      AND deleted_at IS NULL
  ''';

  /// Get all invites for a user (debugging/admin)
  /// 
  /// Not recommended for production UI
  /// Use pagination queries instead
  static const String getAllUserInvites = '''
    SELECT i.id, i.sender_id, i.recipient_id, i.status,
           i.created_at, i.updated_at, i.deleted_at
    FROM chat_invites i
    WHERE (i.sender_id = @user_id OR i.recipient_id = @user_id)
      AND i.deleted_at IS NULL
    ORDER BY i.created_at DESC
  ''';
}

/// Performance recommendations:
/// 
/// 1. Database Level:
///    - Ensure indexes on (recipient_id, status) and (sender_id, status)
///    - Monitor slow query log for queries > 100ms
///    - Analyze query plans with EXPLAIN
/// 
/// 2. Application Level:
///    - Use pagination for UI lists (max 20 items per page)
///    - Implement lazy loading for additional pages
///    - Cache pending invite count (separate query)
///    - Show loading indicator while fetching
///    - Implement search/filter only on cached data
/// 
/// 3. Memory Level:
///    - Don't load all invites into memory
///    - Parse JSON incrementally for large responses
///    - Clear old cached data on logout
///    - Implement cleanup for offline queue
/// 
/// 4. Network Level:
///    - Compress responses with gzip
///    - Use HTTP/2 for multiplexing
///    - Implement request deduplication
///    - Add ETag support for caching
/// 
/// Expected Performance:
///    - Get pending invites: < 100ms for 1000 invites (with pagination)
///    - Get pending count: < 10ms
///    - Add to pagination cache: < 50ms
///    - Parse response: < 100ms (for 20 items)
///    - Total user perceived time: 1-2 seconds (including network latency)
