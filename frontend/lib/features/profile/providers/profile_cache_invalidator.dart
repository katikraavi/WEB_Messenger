import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Global profile cache invalidator
/// 
/// Increment this counter to invalidate ALL profile-related caches.
/// This is a centralized way to ensure profile picture updates 
/// propagate everywhere (avatars, lists, message bubbles, etc).
/// 
/// Usage - Invalidate all profile caches:
/// ```dart
/// ref.read(profileCacheInvalidatorProvider.notifier).state++;
/// ```
/// 
/// Or use the helper function:
/// ```dart
/// invalidateAllProfileCaches(ref);
/// ```
final profileCacheInvalidatorProvider = StateProvider<int>((ref) {
  return 0;
});

/// Family provider for invalidating specific user's profile cache
/// 
/// Use this when you want to invalidate just one user's profile
/// (e.g., after updating their picture).
/// 
/// Usage:
/// ```dart
/// ref.read(profileUserCacheInvalidatorProvider(userId).notifier).state++;
/// ```
final profileUserCacheInvalidatorProvider =
    StateProvider.family<int, String>((ref, userId) {
  // Also watch global invalidator to cascade invalidation
  ref.watch(profileCacheInvalidatorProvider);
  return 0;
});

/// Helper function to invalidate ALL profile caches globally
/// 
/// Call this when:
/// - User updates their own profile picture/info
/// - User logs out (clear all cached profiles)
/// - After major sync operations
/// 
/// This will trigger re-evaluation of:
/// - All userProfileProvider instances
/// - All userProfileWithTokenProvider instances
/// - All avatar display widgets
/// - All chat list avatars
/// - All message bubble sender avatars
/// - CachedNetworkImage caches
void invalidateAllProfileCaches(WidgetRef ref) {
  ref.read(profileCacheInvalidatorProvider.notifier).state++;
}

/// Helper function to invalidate a specific user's profile cache
/// 
/// Call this when:
/// - A specific user's profile is updated
/// - You want to force refresh just one user's data
/// 
/// This will trigger re-evaluation of:
/// - userProfileProvider(userId)
/// - userProfileWithTokenProvider((userId, token))
/// - Avatar widgets for this user
void invalidateUserProfileCache(WidgetRef ref, String userId) {
  ref.read(profileUserCacheInvalidatorProvider(userId).notifier).state++;
}
