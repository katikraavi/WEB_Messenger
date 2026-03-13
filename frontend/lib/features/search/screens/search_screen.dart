import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/search_results_provider.dart';
import '../providers/search_form_provider.dart';
import '../services/search_service.dart';
import '../widgets/search_bar_widget.dart';
import '../widgets/search_result_list_widget.dart';

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

  /// Handle search type change
  void _handleSearchTypeChanged(String type) {
    final newType = type == 'username' ? SearchType.username : SearchType.email;
    ref.read(searchFormProvider.notifier).setSearchType(newType);
  }

  /// Handle result tap - navigate to profile
  void _handleResultTap(UserSearchResult result) {
    // TODO: Navigate to profile screen
    // Example: context.go('/profile/${result.userId}');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Navigate to ${result.username}\'s profile')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(searchFormProvider);
    
    // Get search results based on current form state
    final searchAsyncValue = ref.watch(
      searchProvider((formState.query, formState.searchType)),
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
          
          // Search type toggle
          SearchTypeToggle(
            selectedType: formState.searchType == SearchType.username
                ? 'username'
                : 'email',
            onChanged: _handleSearchTypeChanged,
          ),

          // Error message if validation failed
          if (formState.error != null && formState.error!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  border: Border.all(color: Colors.red[200]!),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.red[600]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        formState.error!,
                        style: TextStyle(color: Colors.red[600]),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Results area
          Expanded(
            child: searchAsyncValue.when(
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (error, stackTrace) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Search Error',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error.toString(),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref.refresh(
                          searchProvider(
                            (formState.query, formState.searchType),
                          ),
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (results) => SearchResultListWidget(
                results: results,
                isLoading: false,
                error: null,
                onTap: _handleResultTap,
                onRetry: () => ref.refresh(
                  searchProvider(
                    (formState.query, formState.searchType),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
