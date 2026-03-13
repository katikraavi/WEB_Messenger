import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/search_service.dart';

// Enum for search type
enum SearchType {
  username,
  email,
}

// Provider to get auth token from secure storage
final authTokenProvider = FutureProvider<String>((ref) async {
  const secureStorage = FlutterSecureStorage();
  final token = await secureStorage.read(key: 'auth_token');
  return token ?? '';
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
