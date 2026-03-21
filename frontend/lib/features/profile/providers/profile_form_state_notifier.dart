import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/profile_form_state.dart';
import '../models/user_profile.dart';
import '../utils/validators.dart';
import '../utils/image_validator.dart';
import '../utils/profile_logger.dart';

/// StateNotifier for managing profile edit form state
/// 
/// Handles form field updates, validation, dirty flag tracking,
/// and form reset operations. Persists original profile for comparison.
/// 
/// Phase 11 Edge Cases [T136, T146-T152]:
/// - T136: Last write wins for concurrent edits (state updates are atomic)
/// - T146: Null safety checks on all nullable fields
/// - T150: Form changes during network delay (state maintained)
/// - T151: App backgrounding (state restored via provider)

class ProfileFormStateNotifier extends StateNotifier<ProfileFormState> {
  final UserProfile originalProfile;

  ProfileFormStateNotifier(this.originalProfile)
      : super(
          ProfileFormState(
            userId: originalProfile.userId,
            username: originalProfile.username,
            bio: originalProfile.aboutMe ?? '', // T146: Null safety
            isPrivateProfile: originalProfile.isPrivateProfile,
            isDirty: false,
            isLoading: false,
            error: null,
          ),
        );

  /// Sanitize username by removing invalid characters in real-time
  /// 
  /// Removes any character that isn't alphanumeric, underscore, or hyphen
  /// Keeps only a-z, A-Z, 0-9, _, - from the input
  /// This prevents user from entering invalid characters that cause backend validation errors
  String _sanitizeUsername(String value) {
    // Keep only alphanumeric, underscore, and hyphen
    return value.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
  }

  /// Update username field and detect dirty state
  /// 
  /// T051: Trim input, detect if different from original,
  /// set isDirty=true if changed, clear any previous error
  /// T146: Null safety check for empty username
  /// Real-time validation: Strip invalid characters (spaces, special chars) as user types
  void updateUsername(String value) {
    // T146: Validate input is not null (Dart non-nullable strings can't be null, but defensive programming)
    // Strip invalid characters in real-time (spaces, special chars, etc.)
    final sanitized = _sanitizeUsername(value);
    final trimmedUsername = sanitized.trim();
    
    // T149: Edge case - empty username after trim (same as no change if original is empty)
    final isDirty = trimmedUsername != originalProfile.username;

    state = state.copyWith(
      username: trimmedUsername,
      isDirty: isDirty || (state.bio != (originalProfile.aboutMe ?? '')),
      error: null,
    );
    
    final displayUsername = trimmedUsername.length > 3 ? '${trimmedUsername.substring(0, 3)}...' : trimmedUsername;
    ProfileLogger.logStateChange('updateUsername', 'username="$displayUsername"isDirty=$isDirty');
  }

  /// Update bio field and detect dirty state
  /// 
  /// T052: Trim input to max 500 chars, detect if different from original,
  /// set isDirty=true if changed, clear any previous error
  /// T149: Edge case - empty bio (placeholder should display)
  void updateBio(String value) {
    final trimmedBio = value.trim();
    // Enforce max 500 character limit
    final constrainedBio =
        trimmedBio.length > 500 ? trimmedBio.substring(0, 500) : trimmedBio;
    
    // T149: Empty bio is valid (placeholder will display)
    final originalBio = originalProfile.aboutMe ?? '';
    final isDirty = constrainedBio != originalBio;

    state = state.copyWith(
      bio: constrainedBio,
      isDirty: isDirty || (state.username != originalProfile.username),
      error: null,
    );
    
    ProfileLogger.logStateChange('updateBio', 'bio_length=${constrainedBio.length}, isDirty=$isDirty');
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
          (state.bio != (originalProfile.aboutMe ?? '')),
      error: null,
    );
    
    ProfileLogger.logStateChange('updatePrivacy', 'isPrivate=$isPrivate, isDirty=$isDirty');
  }

  /// Reset form to original values
  /// 
  /// T054: Revert all fields to original, set isDirty=false
  /// T151: Used when app returns from background or user cancels
  void reset() {
    state = state.copyWith(
      username: originalProfile.username,
      bio: originalProfile.aboutMe ?? '', // T146: Null safety
      isPrivateProfile: originalProfile.isPrivateProfile,
      isDirty: false,
      error: null,
      isLoading: false,
    );
    
    ProfileLogger.logStateChange('reset', 'Form reverted to original');
  }

  /// Validate form fields
  /// 
  /// T055: Check username format (3-32 chars, alphanumeric+underscore)
  /// Check bio length (max 500 chars)
  /// Return true if valid, set error if invalid
  /// T146: Handle null/empty cases gracefully
  bool validate() {
    // Validate username - empty is invalid per spec (min 3 chars)
    if (state.username.trim().isEmpty) {
      state = state.copyWith(error: ValidationError.invalidUsername);
      ProfileLogger.logValidation('username', false, 'empty');
      return false;
    }
    
    final usernameError = Validators.validateUsername(state.username);
    if (usernameError != null) {
      state = state.copyWith(error: usernameError);
      ProfileLogger.logValidation('username', false, usernameError.toString());
      return false;
    }

    // T149: Validate bio - empty is valid (placeholder shows)
    final bioError = Validators.validateBio(state.bio);
    if (bioError != null) {
      state = state.copyWith(error: bioError);
      ProfileLogger.logValidation('bio', false, bioError.toString());
      return false;
    }

    // Clear any previous error
    state = state.copyWith(
      error: null,
      clearError: true,
    );
    
    ProfileLogger.logValidation('form', true, null);
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
      debugPrint('[ProfileFormStateNotifier] Error setting image: $e');
      state = state.copyWith(error: ValidationError.imageFormatInvalid);
      return false;
    }
  }

  /// Mark image as changed to enable Save button
  /// 
  /// Called after successful image upload to ensure form is marked dirty
  /// so user can click Save to persist the profile changes
  void markImageChanged() {
    state = state.copyWith(isDirty: true);
    ProfileLogger.logStateChange('markImageChanged', 'isDirty=true (image was changed)');
  }

  /// Remove pending image [T076 - complementary]
  /// 
  /// Clears the pendingImage field, useful when user cancels upload
  /// or clicks remove after selecting an image
  void removeImage() {
    state = state.copyWith(pendingImage: null);
  }
}
