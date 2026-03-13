import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/profile_form_state.dart';
import '../models/user_profile.dart';
import '../utils/validators.dart';
import '../utils/image_validator.dart';

/// StateNotifier for managing profile edit form state
/// 
/// Handles form field updates, validation, dirty flag tracking,
/// and form reset operations. Persists original profile for comparison.
class ProfileFormStateNotifier extends StateNotifier<ProfileFormState> {
  final UserProfile originalProfile;

  ProfileFormStateNotifier(this.originalProfile)
      : super(
          ProfileFormState(
            userId: originalProfile.userId,
            username: originalProfile.username,
            bio: originalProfile.aboutMe,
            isPrivateProfile: originalProfile.isPrivateProfile,
            isDirty: false,
            isLoading: false,
            error: null,
          ),
        );

  /// Update username field and detect dirty state
  /// 
  /// T051: Trim input, detect if different from original,
  /// set isDirty=true if changed, clear any previous error
  void updateUsername(String value) {
    final trimmedUsername = value.trim();
    final isDirty = trimmedUsername != originalProfile.username;

    state = state.copyWith(
      username: trimmedUsername,
      isDirty: isDirty || (state.bio != originalProfile.aboutMe),
      error: null,
    );
  }

  /// Update bio field and detect dirty state
  /// 
  /// T052: Trim input to max 500 chars, detect if different from original,
  /// set isDirty=true if changed, clear any previous error
  void updateBio(String value) {
    final trimmedBio = value.trim();
    // Enforce max 500 character limit
    final constrainedBio =
        trimmedBio.length > 500 ? trimmedBio.substring(0, 500) : trimmedBio;
    final isDirty = constrainedBio != originalProfile.aboutMe;

    state = state.copyWith(
      bio: constrainedBio,
      isDirty: isDirty || (state.username != originalProfile.username),
      error: null,
    );
  }

  /// Update privacy setting
  /// 
  /// T053: Toggle privacy, detect dirty state
  void updatePrivacy(bool isPrivate) {
    final isDirty = isPrivate != originalProfile.isPrivateProfile;

    state = state.copyWith(
      isPrivateProfile: isPrivate,
      isDirty: isDirty ||
          (state.username != originalProfile.username) ||
          (state.bio != originalProfile.aboutMe),
      error: null,
    );
  }

  /// Reset form to original values
  /// 
  /// T054: Revert all fields to original, set isDirty=false
  void reset() {
    state = state.copyWith(
      username: originalProfile.username,
      bio: originalProfile.aboutMe,
      isPrivateProfile: originalProfile.isPrivateProfile,
      isDirty: false,
      error: null,
      isLoading: false,
    );
  }

  /// Validate form fields
  /// 
  /// T055: Check username format (3-32 chars, alphanumeric+underscore)
  /// Check bio length (max 500 chars)
  /// Return true if valid, set error if invalid
  bool validate() {
    // Validate username
    final usernameError = Validators.validateUsername(state.username);
    if (usernameError != null) {
      state = state.copyWith(error: usernameError);
      return false;
    }

    // Validate bio
    final bioError = Validators.validateBio(state.bio);
    if (bioError != null) {
      state = state.copyWith(error: bioError);
      return false;
    }

    // Clear any previous error
    state = state.copyWith(
      error: null,
      clearError: true,
    );
    return true;
  }

  /// Mark form as loading (during API call)
  /// 
  /// Used to prevent multiple submissions and show loading UI
  void setLoading(bool isLoading) {
    state = state.copyWith(isLoading: isLoading);
  }

  /// Set validation error
  /// 
  /// Preserves form state while displaying error
  void setValidationError(ValidationError? error) {
    state = state.copyWith(error: error);
  }

  /// Get current form data as UserProfile for API submission
  /// 
  /// T056: Return updated UserProfile with current form values
  UserProfile getProfileData() {
    return state.toUserProfile();
  }

  /// Check if form has any unsaved changes
  /// 
  /// Returns true if any field differs from original
  bool hasChanges() {
    return state.isDirty;
  }

  /// Enable/disable dirty flag manually
  /// 
  /// Useful for external state management
  void setDirty(bool isDirty) {
    state = state.copyWith(isDirty: isDirty);
  }

  /// Set image file for upload [T076]
  /// 
  /// Validates image before setting in state:
  /// - Format check: JPEG or PNG only
  /// - Size check: ≤5MB
  /// - Dimensions check: 100x100 to 5000x5000 px
  /// 
  /// If validation fails, sets error and doesn't update pendingImage
  /// If validation passes, updates pendingImage and clears error
  Future<bool> setImage(File imageFile) async {
    try {
      final filePath = imageFile.path;
      final fileSize = await imageFile.length();

      // Validate image before storing
      final validationError = await ImageValidator.validateImage(
        filePath: filePath,
        fileSizeBytes: fileSize,
      );
      
      if (validationError != null) {
        // Validation failed - set error but don't update image
        state = state.copyWith(error: validationError);
        return false;
      }

      // Validation passed - update pending image and mark dirty
      state = state.copyWith(
        pendingImage: imageFile,
        isDirty: true,
        error: null,
      );
      return true;
    } catch (e) {
      print('[ProfileFormStateNotifier] Error setting image: $e');
      state = state.copyWith(error: ValidationError.imageFormatInvalid);
      return false;
    }
  }

  /// Remove pending image [T076 - complementary]
  /// 
  /// Clears the pendingImage field, useful when user cancels upload
  /// or clicks remove after selecting an image
  void removeImage() {
    state = state.copyWith(pendingImage: null);
  }
}
