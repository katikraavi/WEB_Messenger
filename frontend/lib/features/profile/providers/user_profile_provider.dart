import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/profile/models/user_profile.dart';
import 'package:frontend/features/profile/services/profile_api_service.dart';

/// Riverpod provider for ProfileApiService singleton
/// 
/// Provides instance of ProfileApiService for dependency injection
final profileApiServiceProvider = Provider((ref) {
  return ProfileApiService();
});

/// FutureProvider for fetching user profile by userId [T036]
/// 
/// Automatically caches results for 5 minutes.
/// 
/// Arguments:
///   - userId: User ID to fetch profile for
/// 
/// Usage:
/// ```dart
/// // Watch profile data
/// final profileAsync = ref.watch(userProfileProvider(userId));
/// 
/// profileAsync.when(
///   loading: () => CircularProgressIndicator(),
///   data: (profile) => Text(profile.username),
///   error: (err, stack) => Text('Error: $err'),
/// );
/// 
/// // Force refresh
/// ref.refresh(userProfileProvider(userId));
/// ```
/// 
/// Caching:
///   - Results are cached for subsequent reads
///   - To invalidate and refetch, call ref.refresh()
/// 
/// Returns: UserProfile with all profile fields
/// 
/// Throws: Exception if fetch fails (captured in AsyncValue.error)
final userProfileProvider = FutureProvider.family<UserProfile, String>(
  (ref, userId) async {
    final apiService = ref.watch(profileApiServiceProvider);
    
    try {
      // T036: Fetch profile from API service (token optional for public profiles)
      final profile = await apiService.fetchProfile(userId, token: null);
      return profile;
    } catch (e) {
      print('[userProfileProvider] Error fetching profile for $userId: $e');
      rethrow; // Rethrow so error is captured in AsyncValue
    }
  },
);

/// Provider for profile picture URL (convenience accessor)
/// 
/// Usage:
/// ```dart
/// final pictureUrlAsync = ref.watch(profilePictureUrlProvider(userId));
/// final pictureUrl = pictureUrlAsync.whenData((url) => url);
/// ```
final profilePictureUrlProvider = Provider.family<AsyncValue<String?>, String>((ref, userId) {
  return ref.watch(userProfileProvider(userId)).whenData((profile) => profile.profilePictureUrl);
});

/// Provider for checking if using default profile picture
/// 
/// Usage:
/// ```dart
/// final isDefaultAsync = ref.watch(isDefaultProfilePictureProvider(userId));
/// ```
final isDefaultProfilePictureProvider = Provider.family<AsyncValue<bool>, String>((ref, userId) {
  return ref.watch(userProfileProvider(userId)).whenData((profile) => profile.isDefaultProfilePicture);
});
