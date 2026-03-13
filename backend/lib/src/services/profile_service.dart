import '../models/user_profile.dart';
import '../models/profile_image.dart';
import '../models/user_model.dart';
import 'dart:io';

/// User Profile Service
/// Business logic for user profile management, image validation, storage
/// 
/// Handles:
/// - Profile data retrieval and updates
/// - Image upload with validation
/// - Image deletion with soft-delete
/// - All validation rules for username, bio, images

class ProfileService {
  final String uploadsDir;
  
  // TODO: Inject database connection
  // This would be passed in via constructor for dependency injection
  // late final Database _db;

  ProfileService({this.uploadsDir = '/uploads/profiles'});

  /// Fetches user profile from database [T023]
  /// 
  /// Arguments:
  ///   - userId: User ID to fetch profile for
  /// 
  /// Returns: User object with all profile fields
  /// 
  /// Throws: Exception if user not found
  /// 
  /// HTTP: 200 = success, 404 = user not found, 500 = server error
  Future<User?> getProfile(String userId) async {
    try {
      // TODO: Implement database query
      // SELECT id, email, username, password_hash, email_verified,
      //        profile_picture_url, about_me, is_private_profile,
      //        created_at, profile_updated_at
      // FROM users WHERE id = userId
      
      // Placeholder implementation
      return null;
    } catch (e) {
      print('[ProfileService] Error fetching profile: $e');
      rethrow;
    }
  }

  /// Updates user profile information (username, bio, privacy) [T024]
  /// 
  /// Validates all fields before persisting to database.
  /// Returns updated User object.
  /// 
  /// Arguments:
  ///   - userId: User ID to update  
  ///   - username: New username (3-32 chars, alphanumeric + underscore + hyphen)
  ///   - bio: New bio/about me (0-500 chars)
  ///   - isPrivateProfile: Privacy setting
  /// 
  /// Returns: Updated User object
  /// 
  /// Validation:
  ///   - Username: 3-32 chars, alphanumeric + underscore + hyphen
  ///   - Bio: 0-500 chars (empty allowed)
  ///   - Privacy: boolean (always valid)
  /// 
  /// HTTP: 200 = success, 400 = validation error, 401 = unauthorized, 500 = server error
  Future<User?> updateProfile({
    required String userId,
    required String username,
    required String bio,
    required bool isPrivateProfile,
  }) async {
    try {
      // 1. Validate fields
      final validationErrors = validateProfileUpdate(
        username: username,
        aboutMe: bio,
      );
      
      if (validationErrors != null && validationErrors.isNotEmpty) {
        throw Exception('Profile validation failed: $validationErrors');
      }

      // 2. Sanitize/trim fields
      final cleanUsername = sanitizeText(username, 32);
      final cleanBio = sanitizeText(bio, 500);

      // TODO: Implement database update
      // UPDATE users SET 
      //   username = ?, 
      //   about_me = ?, 
      //   is_private_profile = ?,
      //   profile_updated_at = NOW()
      // WHERE id = ?

      // 3. Return updated user
      // return await getProfile(userId);
      
      return null; // Placeholder
    } catch (e) {
      print('[ProfileService] Error updating profile: $e');
      rethrow;
    }
  }

  /// Uploads a profile picture image [T025]
  /// 
  /// Validates image format, size, and dimensions.
  /// Compresses to 500x500px (server-side).
  /// Stores file and updates User.profilePictureUrl.
  /// 
  /// Arguments:
  ///   - userId: User ID uploading image
  ///   - imageFile: Binary image file data
  ///   - filename: Original filename (for extension extraction)
  ///   - fileSize: Optional file size (before compression)
  /// 
  /// Returns: Updated User object with new profilePictureUrl
  /// 
  /// Validation:
  ///   - Format: JPEG or PNG only
  ///   - Size: ≤5MB (5,242,880 bytes)
  ///   - Dimensions: 100x100 to 5000x5000 pixels (checked server-side)
  ///   - Magic bytes verification
  /// 
  /// Processing:
  ///   - Verify image format with magic bytes
  ///   - Decode image and check dimensions
  ///   - Compress to 500x500px square
  ///   - Generate secure filename (UUID-based)
  ///   - Store on filesystem
  ///   - Create ProfileImage database record
  ///   - Soft-delete previous image if exists
  ///   - Update User.profilePictureUrl
  /// 
  /// HTTP: 200 = success, 400 = validation error, 401 = unauthorized,
  ///       413 = file too large, 500 = server error
  Future<User?> uploadImage({
    required String userId,
    required List<int> imageFile,
    required String filename,
  }) async {
    try {
      // 1. Validate file size
      final sizeError = validateImage(imageFile, filename);
      if (sizeError != null) {
        throw Exception(sizeError);
      }

      // 2. Store image file
      // TODO: Images need dimension validation via image package decoding
      // For now, just store the file as-is
      final imageUrl = await storeImage(imageFile, userId);
      
      if (imageUrl == null) {
        throw Exception('Failed to store image');
      }

      // 3. Create ProfileImage record in database
      // TODO: INSERT INTO profile_image (image_id, user_id, image_url, file_size, format, uploaded_at)
      //       VALUES (gen_random_uuid(), userId, imageUrl, fileSize, formatFromExtension, NOW())

      // 4. Soft-delete previous image if exists
      // TODO: UPDATE profile_image SET deleted_at = NOW() 
      //       WHERE user_id = userId AND deleted_at IS NULL AND image_url != imageUrl

      // 5. Update User.profilePictureUrl
      // TODO: UPDATE users SET profile_picture_url = imageUrl, profile_updated_at = NOW() WHERE id = userId

      // 6. Return updated user
      // return await getProfile(userId);
      
      return null; // Placeholder
    } catch (e) {
      print('[ProfileService] Error uploading image: $e');
      rethrow;
    }
  }

  /// Deletes profile picture and reverts to default avatar [T026]
  /// 
  /// Soft-deletes ProfileImage record and clears User.profilePictureUrl.
  /// 
  /// Arguments:
  ///   - userId: User ID deleting image
  /// 
  /// Returns: Updated User object (profilePictureUrl = null)
  /// 
  /// Process:
  ///   - Check if user has custom image
  ///   - Soft-delete ProfileImage record (set deleted_at = NOW())
  ///   - Clear User.profilePictureUrl (set to null)
  ///   - Update User.profile_updated_at = NOW()
  /// 
  /// HTTP: 200 = success, 401 = unauthorized, 404 = no image to delete, 500 = server error
  Future<User?> deleteImage(String userId) async {
    try {
      // 1. Fetch current user
      final user = await getProfile(userId);
      
      if (user == null) {
        throw Exception('User not found');
      }

      // 2. Check if custom image exists
      if (user.profilePictureUrl == null) {
        throw Exception('User has no custom profile picture to delete (404)');
      }

      // TODO: Soft-delete ProfileImage record
      // UPDATE profile_image SET deleted_at = NOW() 
      // WHERE user_id = userId AND deleted_at IS NULL

      // TODO: Clear User.profilePictureUrl
      // UPDATE users SET profile_picture_url = NULL, profile_updated_at = NOW() WHERE id = userId

      // 3. Return updated user
      // return await getProfile(userId);
      
      return null; // Placeholder
    } catch (e) {
      print('[ProfileService] Error deleting image: $e');
      rethrow;
    }
  }

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

