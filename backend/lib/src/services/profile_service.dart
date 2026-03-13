import '../models/user_profile.dart';
import '../models/profile_image.dart';
import 'dart:io';

/// User Profile Service
/// Business logic for user profile management, image validation, storage
class ProfileService {
  final String uploadsDir;

  ProfileService({this.uploadsDir = '/uploads/profiles'});

  /// Validate image file
  /// Returns error message if invalid, null if valid
  String? validateImage(List<int> fileBytes, String fileName) {
    // Check file size (max 5MB)
    if (fileBytes.length > 5242880) {
      return 'File must be smaller than 5MB';
    }

    // Check file format from extension
    final extension = fileName.split('.').last.toLowerCase();
    if (extension != 'jpg' && extension != 'jpeg' && extension != 'png') {
      return 'Only JPEG and PNG formats are supported';
    }

    // Basic magic number validation
    if (extension == 'jpg' || extension == 'jpeg') {
      // JPEG magic number: FF D8 FF
      if (fileBytes.length < 3 || fileBytes[0] != 0xFF || fileBytes[1] != 0xD8 || fileBytes[2] != 0xFF) {
        return 'Invalid JPEG file';
      }
    } else if (extension == 'png') {
      // PNG magic number: 89 50 4E 47
      if (fileBytes.length < 4 || 
          fileBytes[0] != 0x89 || 
          fileBytes[1] != 0x50 || 
          fileBytes[2] != 0x4E || 
          fileBytes[3] != 0x47) {
        return 'Invalid PNG file';
      }
    }

    return null; // Valid
  }

  /// Generate a unique file path for uploaded image
  String generateFilePath(String userId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'profiles/$userId-$timestamp.jpg';
  }

  /// Get image URL from file path
  String getImageUrl(String filePath) {
    return '/uploads/$filePath';
  }

  /// Store image file
  /// Returns the stored file URL if successful
  Future<String?> storeImage(List<int> fileBytes, String userId) async {
    try {
      final filePath = generateFilePath(userId);
      final fullPath = '$uploadsDir/$filePath';

      // Ensure directory exists
      final dir = Directory('$uploadsDir/profiles');
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }

      // Write file
      final file = File(fullPath);
      await file.writeAsBytes(fileBytes);

      return getImageUrl(filePath);
    } catch (e) {
      print('[ProfileService] Error storing image: $e');
      return null;
    }
  }

  /// Delete image file
  Future<bool> deleteImage(String filePath) async {
    try {
      final fullPath = '$uploadsDir/$filePath';
      final file = File(fullPath);
      if (file.existsSync()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      print('[ProfileService] Error deleting image: $e');
      return false;
    }
  }

  /// Truncate and trim profile text fields
  String sanitizeText(String text, int maxLength) {
    final trimmed = text.trim();
    if (trimmed.length > maxLength) {
      return trimmed.substring(0, maxLength);
    }
    return trimmed;
  }

  /// Validate profile update data
  Map<String, String>? validateProfileUpdate({
    String? username,
    String? aboutMe,
  }) {
    final errors = <String, String>{};

    if (username != null && username.isNotEmpty) {
      if (username.length < 3 || username.length > 32) {
        errors['username'] = 'Username must be between 3 and 32 characters';
      }
      if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) {
        errors['username'] = 'Username can only contain letters, numbers, and underscores';
      }
    }

    if (aboutMe != null && aboutMe.length > 500) {
      errors['aboutMe'] = 'About me must not exceed 500 characters';
    }

    return errors.isEmpty ? null : errors;
  }
}

