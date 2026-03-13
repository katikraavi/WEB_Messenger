import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/user.dart';

/// State for profile view
class UserProfileState {
  final User? profile;
  final String? error;
  final bool isLoading;
  final DateTime? lastUpdated;

  const UserProfileState({
    this.profile,
    this.error,
    this.isLoading = false,
    this.lastUpdated,
  });

  UserProfileState copyWith({
    User? profile,
    String? error,
    bool? isLoading,
    DateTime? lastUpdated,
  }) =>
      UserProfileState(
        profile: profile ?? this.profile,
        error: error,
        isLoading: isLoading ?? this.isLoading,
        lastUpdated: lastUpdated ?? this.lastUpdated,
      );
}

/// Notifier for user profile state
class UserProfileNotifier extends StateNotifier<UserProfileState> {
  UserProfileNotifier() : super(const UserProfileState());

  /// Fetch user profile
  Future<void> fetchProfile(String userId) async {
    state = state.copyWith(isLoading: true);
    try {
      // TODO: Call ProfileService to fetch from backend
      // For now, return mock profile
      await Future.delayed(const Duration(milliseconds: 300));
      
      final mockProfile = User(
        userId: userId,
        email: 'user@example.com',
        username: 'User_$userId',
        emailVerified: true,
        createdAt: DateTime.now(),
        profilePictureUrl: null,
        aboutMe: 'Welcome to my profile',
        isDefaultProfilePicture: true,
        isPrivateProfile: false,
      );

      state = state.copyWith(
        profile: mockProfile,
        isLoading: false,
        error: null,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Update profile information
  Future<void> updateProfile({
    String? username,
    String? aboutMe,
    bool? isPrivateProfile,
  }) async {
    if (state.profile == null) return;
    
    state = state.copyWith(isLoading: true);
    try {
      // TODO: Call ProfileService to update backend
      await Future.delayed(const Duration(milliseconds: 500));

      state = state.copyWith(
        profile: state.profile!.copyWith(
          username: username ?? state.profile?.username,
          aboutMe: aboutMe ?? state.profile?.aboutMe,
          isPrivateProfile: isPrivateProfile ?? state.profile?.isPrivateProfile,
        ),
        isLoading: false,
        error: null,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }
}

/// Riverpod provider for user profile
final userProfileProvider = StateNotifierProvider<UserProfileNotifier, UserProfileState>(
  (ref) => UserProfileNotifier(),
);
