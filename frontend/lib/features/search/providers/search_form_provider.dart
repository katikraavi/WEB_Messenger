import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'search_results_provider.dart';

/// State for search form
class SearchFormState {
  final String query;
  final SearchType searchType;
  final bool isSearching;
  final String? error;

  SearchFormState({
    required this.query,
    required this.searchType,
    required this.isSearching,
    this.error,
  });

  SearchFormState copyWith({
    String? query,
    SearchType? searchType,
    bool? isSearching,
    String? error,
  }) {
    return SearchFormState(
      query: query ?? this.query,
      searchType: searchType ?? this.searchType,
      isSearching: isSearching ?? this.isSearching,
      error: error,
    );
  }
}

/// StateNotifier for managing search form state
class SearchFormNotifier extends StateNotifier<SearchFormState> {
  SearchFormNotifier()
      : super(
          SearchFormState(
            query: '',
            searchType: SearchType.username,
            isSearching: false,
          ),
        );

  /// Update the search query
  void setQuery(String query) {
    state = state.copyWith(query: query, error: null);
  }

  /// Update the search type
  void setSearchType(SearchType searchType) {
    state = state.copyWith(searchType: searchType, error: null);
  }

  /// Clear the search form
  void clear() {
    state = SearchFormState(
      query: '',
      searchType: SearchType.username,
      isSearching: false,
    );
  }

  /// Mark search as in progress
  void setIsSearching(bool isSearching) {
    state = state.copyWith(isSearching: isSearching);
  }

  /// Set error message
  void setError(String? error) {
    state = state.copyWith(error: error);
  }

  /// Perform search (validates and triggers search)
  /// Note: Returns true if search started, false if validation failed
  bool performSearch() {
    final query = state.query.trim();

    // Validation
    if (query.isEmpty) {
      state = state.copyWith(error: 'Please enter a search query');
      return false;
    }

    if (query.length < 2) {
      state = state.copyWith(error: 'Search must be at least 2 characters');
      return false;
    }

    if (query.length > 100) {
      state = state.copyWith(error: 'Search query too long (max 100 characters)');
      return false;
    }

    // Validate based on search type
    switch (state.searchType) {
      case SearchType.username:
        // Username: alphanumeric, underscore, hyphen only
        if (!RegExp(r'^[a-zA-Z0-9_\-]+$').hasMatch(query)) {
          state = state.copyWith(
            error: 'Username can only contain letters, numbers, underscores, and hyphens',
          );
          return false;
        }
        break;

      case SearchType.email:
        // Email: must contain @ and .
        if (!query.contains('@') || !query.contains('.')) {
          state = state.copyWith(error: 'Invalid email format');
          return false;
        }
        break;
    }

    state = state.copyWith(error: null, isSearching: true);
    return true;
  }
}

/// Provider for search form state using StateNotifier
final searchFormProvider = StateNotifierProvider<SearchFormNotifier, SearchFormState>(
  (ref) => SearchFormNotifier(),
);

/// Convenience provider for current search query
final searchQueryProvider = Provider<String>((ref) {
  return ref.watch(searchFormProvider).query;
});

/// Convenience provider for current search type
final searchTypeProvider = Provider<SearchType>((ref) {
  return ref.watch(searchFormProvider).searchType;
});
