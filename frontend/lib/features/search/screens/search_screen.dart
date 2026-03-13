import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../utils/copyable_error_widget.dart';
import '../providers/search_results_provider.dart';
import '../providers/search_form_provider.dart';
import '../services/search_service.dart';
import '../widgets/search_bar_widget.dart';
import '../widgets/search_result_list_widget.dart';
import '../../profile/screens/profile_view_screen.dart';

/// Screen for searching users by username or email
/// 
/// Features:
/// - Search bar with 500ms debounce
/// - Username / Email toggle
/// - Results list with user profiles
/// - Empty state handling
/// - Error state handling
class SearchScreen extends ConsumerStatefulWidget {
  final String? initialQuery;

  const SearchScreen({
    Key? key,
    this.initialQuery,
  }) : super(key: key);

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery ?? '');
    
    // If initial query provided, perform search
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _performSearch();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Perform search with current form state
  void _performSearch() {
    final formNotifier = ref.read(searchFormProvider.notifier);
    formNotifier.performSearch();
  }

  /// Handle query change (called after debounce)
  void _handleQueryChanged(String query) {
    final formNotifier = ref.read(searchFormProvider.notifier);
    formNotifier.setQuery(query);
  }

  /// Handle search trigger (enter key or search button)
  void _handleSearch() {
    _performSearch();
  }

  /// Handle clear
  void _handleClear() {
    _searchController.clear();
    ref.read(searchFormProvider.notifier).clear();
  }

  /// Handle result tap - navigate to profile
  /// T123: Handle result tap - navigate to ProfileViewScreen
  void _handleResultTap(UserSearchResult result) {
    // Navigate to ProfileViewScreen with selected user
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileViewScreen(
          userId: result.userId,
          isOwnProfile: false, // Viewing other user's profile
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(searchFormProvider);
    
    // Get search results based on current form state
    final searchAsyncValue = ref.watch(
      combinedSearchProvider(formState.query),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Users'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search bar
          SearchBarWidget(
            controller: _searchController,
            onQueryChanged: _handleQueryChanged,
            onSearch: _handleSearch,
            onClear: _handleClear,
            debounceMs: 500,
          ),

          // Error message if validation failed
          if (formState.error != null && formState.error!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: CopyableErrorBanner(error: formState.error!),
            ),

          // Results area
          Expanded(
            child: searchAsyncValue.when(
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (error, stackTrace) => Padding(
                padding: const EdgeInsets.all(32.0),
                child: CopyableErrorWidget(
                  error: error.toString(),
                  title: 'Search Error',
                  onRetry: () => ref.refresh(
                    combinedSearchProvider(formState.query),
                  ),
                ),
              ),
              data: (results) => SearchResultListWidget(
                results: results,
                isLoading: false,
                error: null,
                onTap: _handleResultTap,
                onRetry: () => ref.refresh(
                  combinedSearchProvider(formState.query),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
