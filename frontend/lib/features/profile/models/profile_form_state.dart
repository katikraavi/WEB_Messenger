import 'dart:io';
import 'user_profile.dart';

/// Form state for editing user profile
/// 
/// Tracks the current form values, dirty/pristine state, and loading/error state.
/// Used by the profile edit screen to manage form state and validation.

class ProfileFormState {
  /// User ID being edited
  final String userId;

  /// Current username value in the form
  final String username;

  /// Current bio/about me value in the form
  final String bio;

  /// Current privacy setting (private vs public)
  final bool isPrivateProfile;

  /// Currently selected image file to upload (pending upload)
  /// Null if no image selected or already uploaded
  final File? pendingImage;

  /// Whether any fields have been modified from original values
  final bool isDirty;

  /// Whether an API request is in progress (save, upload, delete)
  final bool isLoading;

  /// Validation error if form is invalid
  /// Null if form is valid
  final ValidationError? error;

  /// Creates a [ProfileFormState] instance
  const ProfileFormState({
    required this.userId,
    required this.username,
    required this.bio,
    this.isPrivateProfile = false,
    this.pendingImage,
    this.isDirty = false,
    this.isLoading = false,
    this.error,
  });

  /// Creates an initial form state from existing profile values
  factory ProfileFormState.initial({
    required String userId,
    required String username,
    required String bio,
    required bool isPrivateProfile,
  }) {
    return ProfileFormState(
      userId: userId,
      username: username,
      bio: bio,
      isPrivateProfile: isPrivateProfile,
      pendingImage: null,
      isDirty: false,
      isLoading: false,
      error: null,
    );
  }

  /// Creates a copy of this [ProfileFormState] with specified fields replaced
  ProfileFormState copyWith({
    String? userId,
    String? username,
    String? bio,
    bool? isPrivateProfile,
    File? pendingImage,
    bool? isDirty,
    bool? isLoading,
    ValidationError? error,
    bool clearError = false,
  }) {
    return ProfileFormState(
      userId: userId ?? this.userId,
      username: username ?? this.username,
      bio: bio ?? this.bio,
      isPrivateProfile: isPrivateProfile ?? this.isPrivateProfile,
      pendingImage: pendingImage ?? this.pendingImage,
      isDirty: isDirty ?? this.isDirty,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  /// Convert form state to UserProfile for API submission
  /// 
  /// T056: Returns updated UserProfile with current form values
  UserProfile toUserProfile() {
    return UserProfile(
      userId: userId,
      username: username,
      profilePictureUrl: null, // Ignore during edit (handled separately)
      aboutMe: bio,
      isPrivateProfile: isPrivateProfile,
      isDefaultProfilePicture: true, // Not changed in edit form
    );
  }

  /// Returns true if form data is valid
  bool get isValid => error == null;

  /// Returns true if Save button should be enabled
  bool get canSave => isDirty && !isLoading && isValid;

  @override
  String toString() => '''ProfileFormState(
    userId: $userId,
    username: $username,
    bio: $bio,
    isPrivateProfile: $isPrivateProfile,
    isDirty: $isDirty,
    isLoading: $isLoading,
    error: $error,
    pendingImage: ${pendingImage != null ? 'File' : 'null'}
  )''';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfileFormState &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          username == other.username &&
          bio == other.bio &&
          isPrivateProfile == other.isPrivateProfile &&
          pendingImage == other.pendingImage &&
          isDirty == other.isDirty &&
          isLoading == other.isLoading &&
          error == other.error;

  @override
  int get hashCode =>
      userId.hashCode ^
      username.hashCode ^
      bio.hashCode ^
      isPrivateProfile.hashCode ^
      pendingImage.hashCode ^
      isDirty.hashCode ^
      isLoading.hashCode ^
      error.hashCode;
}

/// Enumeration of validation errors
enum ValidationError {
  /// Username invalid (length, characters, etc.)
  invalidUsername,

  /// Bio/about me invalid (length, etc.)
  invalidBio,

  /// Image format not supported (must be JPEG or PNG)
  imageFormatInvalid,

  /// Image file too large (must be ≤5MB)
  imageTooLarge,

  /// Image dimensions invalid (must be 100x100 to 5000x5000)
  imageDimensionsInvalid,

  /// Network error occurred
  networkError,

  /// Server error occurred
  serverError;

  /// Returns user-friendly error message for this validation error
  String get message {
    switch (this) {
      case ValidationError.invalidUsername:
        return 'Username must be 3-32 characters using letters, numbers, underscore, or hyphen';
      case ValidationError.invalidBio:
        return 'Bio must be 0-500 characters';
      case ValidationError.imageFormatInvalid:
        return 'Only JPEG and PNG formats are supported';
      case ValidationError.imageTooLarge:
        return 'File must be smaller than 5MB';
      case ValidationError.imageDimensionsInvalid:
        return 'Image dimensions must be between 100x100 and 5000x5000 pixels';
      case ValidationError.networkError:
        return 'Network error. Please check your connection and try again';
      case ValidationError.serverError:
        return 'Server error. Please try again later';
    }
  }
}
