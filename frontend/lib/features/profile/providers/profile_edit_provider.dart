import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/profile_api_service.dart';

/// State for profile editing form
class ProfileEditFormState {
  final String username;
  final String aboutMe;
  final bool isPrivateProfile;
  final bool isDirty;
  final bool isLoading;
  final String? error;

  const ProfileEditFormState({
    required this.username,
    required this.aboutMe,
    this.isPrivateProfile = false,
    this.isDirty = false,
    this.isLoading = false,
    this.error,
  });

  ProfileEditFormState copyWith({
    String? username,
    String? aboutMe,
    bool? isPrivateProfile,
    bool? isDirty,
    bool? isLoading,
    String? error,
  }) =>
      ProfileEditFormState(
        username: username ?? this.username,
        aboutMe: aboutMe ?? this.aboutMe,
        isPrivateProfile: isPrivateProfile ?? this.isPrivateProfile,
        isDirty: isDirty ?? this.isDirty,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

/// Notifier for profile edit form
class ProfileEditFormNotifier extends StateNotifier<ProfileEditFormState> {
  ProfileEditFormNotifier(String initialUsername, String initialAboutMe, bool initialPrivate)
      : super(ProfileEditFormState(
          username: initialUsername,
          aboutMe: initialAboutMe,
          isPrivateProfile: initialPrivate,
        ));

  void updateUsername(String value) {
    state = state.copyWith(username: value, isDirty: true);
  }

  void updateAboutMe(String value) {
    state = state.copyWith(aboutMe: value, isDirty: true);
  }

  void togglePrivacy() {
    state = state.copyWith(
      isPrivateProfile: !state.isPrivateProfile,
      isDirty: true,
    );
  }

  Future<void> saveProfile() async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      // Call ProfileApiService.updateProfile() with real API request
      final apiService = ProfileApiService();
      await apiService.updateProfile(
        username: state.username,
        bio: state.aboutMe,
        isPrivateProfile: state.isPrivateProfile,
        token: null, // Token can be passed when auth is implemented
      );
      
      state = state.copyWith(
        isDirty: false,
        isLoading: false,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void reset(String username, String aboutMe, bool isPrivate) {
    state = ProfileEditFormState(
      username: username,
      aboutMe: aboutMe,
      isPrivateProfile: isPrivate,
    );
  }
}

/// Riverpod provider factory for profile edit form
final profileEditFormProvider = StateNotifierProvider.family<
    ProfileEditFormNotifier,
    ProfileEditFormState,
    (String username, String aboutMe, bool isPrivate)>(
  (ref, params) => ProfileEditFormNotifier(
    params.$1,
    params.$2,
    params.$3,
  ),
);
