import 'package:flutter/material.dart';
import '../../../utils/copyable_error_widget.dart';
import '../services/search_service.dart';

/// Callback when a result is tapped
typedef OnResultTap = Function(UserSearchResult result);

/// Widget to display search results list
class SearchResultListWidget extends StatelessWidget {
  final List<UserSearchResult> results;
  final bool isLoading;
  final String? error;
  final OnResultTap onTap;
  final VoidCallback onRetry;

  const SearchResultListWidget({
    Key? key,
    required this.results,
    required this.isLoading,
    this.error,
    required this.onTap,
    required this.onRetry,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Show loading state
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Show error state
    if (error != null && error!.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: CopyableErrorWidget(
            error: error!,
            title: 'Search Error',
            onRetry: onRetry,
          ),
        ),
      );
    }

    // Show empty state if no results
    if (results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person_search, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'No results found',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Try searching with different keywords',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    // Show results list
    return ListView.builder(
      itemCount: results.length,
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      itemBuilder: (context, index) {
        final result = results[index];
        return _SearchResultTile(
          result: result,
          onTap: () => onTap(result),
        );
      },
    );
  }
}

/// Individual search result tile
class _SearchResultTile extends StatelessWidget {
  final UserSearchResult result;
  final VoidCallback onTap;

  const _SearchResultTile({
    required this.result,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            children: [
              // Profile picture
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey[300],
                  image: result.profilePictureUrl != null
                      ? DecorationImage(
                          image: NetworkImage(result.profilePictureUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: result.profilePictureUrl == null
                    ? Center(
                        child: Icon(
                          Icons.person,
                          color: Colors.grey[600],
                          size: 28,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              // User info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.username,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      result.email,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Private profile badge
              if (result.isPrivateProfile)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Icon(
                    Icons.lock,
                    size: 18,
                    color: Colors.grey[500],
                  ),
                ),
              // Chevron
              Icon(
                Icons.chevron_right,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
