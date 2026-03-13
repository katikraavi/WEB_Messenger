import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'search_results_provider.dart';

/// State for search form
class SearchFormState {
  final String query;
  final bool isSearching;
  final String? error;

  SearchFormState({
    required this.query,
    required this.isSearching,
    this.error,
  });

  SearchFormState copyWith({
    String? query,
    bool? isSearching,
    String? error,
  }) {
    return SearchFormState(
      query: query ?? this.query,
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
            isSearching: false,
          ),
        );

  /// Update the search query
  void setQuery(String query) {
    state = state.copyWith(query: query, error: null);
  }

  /// Clear the search form
  void clear() {
    state = SearchFormState(
      query: '',
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
  /// For combined search, accepts both username and email formats
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

    // Accept any query - will search both username and email
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
