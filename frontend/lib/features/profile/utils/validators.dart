import 'package:frontend/features/profile/models/profile_form_state.dart';
import 'package:frontend/core/constants/profile_constants.dart';

/// Validation utilities for profile fields
/// 
/// Provides functions for validating username, bio, and other profile fields.
/// Returns [ValidationError] if validation fails, null if valid.

class Validators {
  /// Validates username format and length
  /// 
  /// Rules:
  /// - Must be 3-32 characters
  /// - Alphanumeric characters, underscore, and hyphen only
  /// - Must start and end with alphanumeric character
  /// 
  /// Returns [ValidationError.invalidUsername] if validation fails, null if valid
  static ValidationError? validateUsername(String username) {
    final trimmed = username.trim();

    // Check length
    if (trimmed.length < ProfileConstants.minUsernameLength ||
        trimmed.length > ProfileConstants.maxUsernameLength) {
      return ValidationError.invalidUsername;
    }

    // Check pattern (alphanumeric, underscore, hyphen, no leading/trailing symbols)
    final regExp = RegExp(ProfileConstants.usernamePattern);
    if (!regExp.hasMatch(trimmed)) {
      return ValidationError.invalidUsername;
    }

    return null;
  }

  /// Validates bio/about me text length
  /// 
  /// Rules:
  /// - Maximum 500 characters (after trimming)
  /// - Empty is allowed (optional field)
  /// 
  /// Returns [ValidationError.invalidBio] if validation fails, null if valid
  static ValidationError? validateBio(String bio) {
    final trimmed = bio.trim();

    // Check max length
    if (trimmed.length > ProfileConstants.maxBioLength) {
      return ValidationError.invalidBio;
    }

    return null; // Empty bio is valid
  }

  /// Validates privacy setting (always valid - just for consistency)
  /// Privacy is a boolean toggle, always valid
  static ValidationError? validatePrivacy(bool isPrivateProfile) {
    // Privacy setting is always valid
    return null;
  }

  /// Trims username to configured max length
  static String trimUsername(String username) {
    return username.trim().substring(
      0,
      (username.trim().length < ProfileConstants.maxUsernameLength)
          ? username.trim().length
          : ProfileConstants.maxUsernameLength,
    );
  }

  /// Trims bio to configured max length
  static String trimBio(String bio) {
    return bio.trim().substring(
      0,
      (bio.trim().length < ProfileConstants.maxBioLength)
          ? bio.trim().length
          : ProfileConstants.maxBioLength,
    );
  }
}
