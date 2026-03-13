import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../utils/secure_storage_wrapper.dart';
import '../services/search_service.dart';

// Enum for search type
enum SearchType {
  username,
  email,
}

// Provider to get auth token from secure storage with Linux fallback
// Uses SecureStorageWrapper which falls back to in-memory storage on Linux keyring errors
final authTokenProvider = FutureProvider<String>((ref) async {
  try {
    final storage = SecureStorageWrapper();
    final token = await storage.read(key: 'auth_token');
    
    if (token != null) {
      print('[AuthToken] Successfully retrieved token');
      return token;
    }
    
    print('[AuthToken] No token stored');
    return '';
  } catch (e) {
    print('[AuthToken] Error reading token: $e');
    return '';
  }
});

// State for search results with metadata
class SearchResultsState {
  final List<UserSearchResult> results;
  final String? error;
  final bool isLoading;
  final String lastQuery;
  final SearchType searchType;

  SearchResultsState({
    required this.results,
    this.error,
    required this.isLoading,
    required this.lastQuery,
    required this.searchType,
  });

  SearchResultsState copyWith({
    List<UserSearchResult>? results,
    String? error,
    bool? isLoading,
    String? lastQuery,
    SearchType? searchType,
  }) {
    return SearchResultsState(
      results: results ?? this.results,
      error: error,
      isLoading: isLoading ?? this.isLoading,
      lastQuery: lastQuery ?? this.lastQuery,
      searchType: searchType ?? this.searchType,
    );
  }
}

// Provider for SearchService instance
final searchServiceProvider = Provider((ref) {
  // Get base URL from config (or use default)
  final baseUrl = 'http://localhost:8081';
  
  // Get auth token from secure storage
  String getToken() {
    // Read token from secure storage synchronously is not ideal,
    // but for search we need to try to get it as quickly as possible
    // The async version is handled by authTokenProvider above
    // For now, use an empty string and let SearchException handle it
    // Better approach: Use async version in the actual search calls
    return '';  // Will be replaced by async version below
  };
  
  return SearchService(
    baseUrl: baseUrl,
    getAuthToken: getToken,
  );
});

// Provider for SearchService with token
final searchServiceWithTokenProvider = FutureProvider((ref) async {
  const baseUrl = 'http://localhost:8081';
  
  // Get token asynchronously
  final tokenAsync = await ref.watch(authTokenProvider.future);
  
  return SearchService(
    baseUrl: baseUrl,
    getAuthToken: () => tokenAsync,
  );
});

/// Future provider for search results by username
/// Parameters: query (search string)
/// Returns: List<UserSearchResult> or throws SearchException
final searchByUsernameProvider =
    FutureProvider.family<List<UserSearchResult>, String>((ref, query) async {
  if (query.trim().isEmpty) {
    return [];
  }

  final searchService = await ref.watch(searchServiceWithTokenProvider.future);
  return await searchService.searchByUsername(query);
});

/// Future provider for search results by email
/// Parameters: query (search string)
/// Returns: List<UserSearchResult> or throws SearchException
final searchByEmailProvider =
    FutureProvider.family<List<UserSearchResult>, String>((ref, query) async {
  if (query.trim().isEmpty) {
    return [];
  }

  final searchService = await ref.watch(searchServiceWithTokenProvider.future);
  return await searchService.searchByEmail(query);
});

/// Combined search provider
/// Searches both username and email simultaneously and merges results
/// Parameters: query (search string)
/// Returns: Combined list of results from both username and email searches
final combinedSearchProvider = FutureProvider.family<List<UserSearchResult>, String>(
    (ref, query) async {
  if (query.trim().isEmpty) {
    return [];
  }

  final searchService = await ref.watch(searchServiceWithTokenProvider.future);
  final trimmedQuery = query.trim();
  
  // Detect if query looks like an email (contains @ or domain-like pattern)
  final looksLikeEmail = trimmedQuery.contains('@') || 
                         (trimmedQuery.contains('.') && !trimmedQuery.startsWith('.'));

  try {
    if (looksLikeEmail) {
      // Query looks like email - prioritize email search
      try {
        return await searchService.searchByEmail(query);
      } catch (e) {
        print('[CombinedSearch] Email search failed, trying username search: $e');
        try {
          return await searchService.searchByUsername(query);
        } catch (_) {
          rethrow; // Both failed, rethrow the email error
        }
      }
    } else {
      // Query looks like username - try both in parallel
      try {
        final results = await Future.wait([
          searchService.searchByUsername(query),
          searchService.searchByEmail(query),
        ]);

        // Merge results and remove duplicates
        final combinedResults = <String, UserSearchResult>{};
        
        // Add username results
        for (var result in results[0]) {
          combinedResults[result.userId] = result;
        }
        
        // Add email results (overwrite if username result exists for same user)
        for (var result in results[1]) {
          combinedResults[result.userId] = result;
        }

        // Return as list, sorted by username
        final merged = combinedResults.values.toList();
        merged.sort((a, b) => a.username.compareTo(b.username));
        return merged;
      } catch (e) {
        // If parallel search completely fails, try username first
        print('[CombinedSearch] Parallel search failed: $e, trying individual searches');
        try {
          return await searchService.searchByUsername(query);
        } catch (_) {
          try {
            return await searchService.searchByEmail(query);
          } catch (_) {
            rethrow; // Both failed, rethrow the original error
          }
        }
      }
    }
  } catch (e) {
    print('[CombinedSearch] All search attempts failed: $e');
    rethrow;
  }
});

/// Combined search provider that handles both Username and Email searches
/// Parameters: query (search string), searchType (username or email)
/// Returns: List<UserSearchResult> or throws SearchException
/// Usage: 
///   watch(searchProvider(('alice', SearchType.username)))
///   watch(searchProvider(('alice@example.com', SearchType.email)))
final searchProvider = FutureProvider.family<List<UserSearchResult>, (String, SearchType)>(
    (ref, params) async {
  final (query, searchType) = params;

  if (query.trim().isEmpty) {
    return [];
  }

  final searchService = await ref.watch(searchServiceWithTokenProvider.future);

  switch (searchType) {
    case SearchType.username:
      return await searchService.searchByUsername(query);
    case SearchType.email:
      return await searchService.searchByEmail(query);
  }
});
