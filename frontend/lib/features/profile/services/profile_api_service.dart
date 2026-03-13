import 'dart:io';
import 'package:frontend/features/profile/models/user_profile.dart';

/// API service for profile-related HTTP requests
/// 
/// Handles communication with the backend for profile operations:
/// - Fetching profile data
/// - Updating profile information
/// - Uploading profile pictures
/// - Deleting profile pictures

class ProfileApiService {
  /// Base API URL for profile endpoints
  static const String baseUrl = '/api/profile';

  /// Fetches user profile data from backend [T044]
  /// 
  /// Arguments:
  ///   - userId: User ID to fetch profile for
  /// 
  /// Returns: [UserProfile] object
  /// 
  /// Throws: May throw HttpException or FormatException on error
  /// 
  /// HTTP: `GET /api/profile/:userId`
  /// Status: 200 = success, 401 = unauthorized, 404 = not found, 500 = server error
  Future<UserProfile> fetchProfile(String userId) async {
    try {
      // TODO: Implement HTTP GET request to fetch profile
      // For now, return mock data for development
      
      // Simulate network delay
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Mock profile data for testing
      return UserProfile(
        userId: userId,
        username: 'john_doe',
        profilePictureUrl: null, // Will load default avatar
        aboutMe: 'Software engineer & coffee enthusiast',
        isPrivateProfile: false,
        isDefaultProfilePicture: true,
        updatedAt: DateTime.now(),
      );
      
      /* Real implementation would look like:
      final response = await http.get(
        Uri.parse('$baseUrl/$userId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return UserProfile.fromJson(jsonDecode(response.body));
      } else if (response.statusCode == 404) {
        throw HttpException('User profile not found (404)');
      } else if (response.statusCode == 401) {
        throw HttpException('Unauthorized (401)');
      } else {
        throw HttpException('Failed to fetch profile: ${response.statusCode}');
      }
      */
    } catch (e) {
      print('[ProfileApiService] Error fetching profile: $e');
      rethrow;
    }
  }

  /// Updates user profile information (username, bio, privacy setting)
  /// 
  /// Arguments:
  ///   - username: New username (3-32 characters)
  ///   - bio: New bio/about me text (0-500 characters)
  ///   - isPrivateProfile: Privacy setting (true = private, false = public)
  /// 
  /// Returns: Updated [UserProfile] object
  /// 
  /// Throws: May throw HttpException or FormatException on error
  /// 
  /// HTTP: `PUT /api/profile`
  /// Status: 200 = success, 400 = validation error, 401 = unauthorized, 500 = server error
  Future<UserProfile> updateProfile({
    required String username,
    required String bio,
    required bool isPrivateProfile,
  }) async {
    // TODO: Implement HTTP PUT request to update profile
    // return await http.put(
    //   Uri.parse(baseUrl),
    //   headers: {'Content-Type': 'application/json'},
    //   body: jsonEncode({
    //     'username': username,
    //     'aboutMe': bio,
    //     'isPrivateProfile': isPrivateProfile,
    //   }),
    // ).then((response) {
    //   if (response.statusCode == 200) {
    //     return UserProfile.fromJson(jsonDecode(response.body));
    //   } else if (response.statusCode == 400) {
    //     throw 'Validation error: ${response.body}';
    //   } else {
    //     throw 'Failed to update profile';
    //   }
    // });
    
    throw UnimplementedError('updateProfile not yet implemented');
  }

  /// Uploads a profile picture image
  /// 
  /// Arguments:
  ///   - imageFile: Image file to upload (must be JPEG or PNG, ≤5MB)
  /// 
  /// Returns: Updated [UserProfile] object with new profilePictureUrl
  /// 
  /// Throws: May throw HttpException, FormatException, or FileException on error
  /// 
  /// HTTP: `POST /api/profile/picture` (multipart/form-data)
  /// Status: 200 = success, 400 = validation error, 401 = unauthorized, 413 = file too large, 500 = server error
  Future<UserProfile> uploadImage(File imageFile) async {
    // TODO: Implement HTTP POST multipart request to upload image
    // var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/picture'))
    //   ..files.add(await http.MultipartFile.fromPath('image', imageFile.path));
    // 
    // var response = await request.send();
    // if (response.statusCode == 200) {
    //   var responseData = await response.stream.bytesToString();
    //   return UserProfile.fromJson(jsonDecode(responseData));
    // } else {
    //   throw 'Failed to upload image';
    // }
    
    throw UnimplementedError('uploadImage not yet implemented');
  }

  /// Deletes the profile picture (reverts to default avatar)
  /// 
  /// Returns: Updated [UserProfile] object (profilePictureUrl = null)
  /// 
  /// Throws: May throw HttpException or FormatException on error
  /// 
  /// HTTP: `DELETE /api/profile/picture`
  /// Status: 200 = success, 401 = unauthorized, 404 = no picture to delete, 500 = server error
  Future<UserProfile> deleteImage() async {
    // TODO: Implement HTTP DELETE request to remove profile picture
    // return await http.delete(Uri.parse('$baseUrl/picture')).then((response) {
    //   if (response.statusCode == 200) {
    //     return UserProfile.fromJson(jsonDecode(response.body));
    //   } else if (response.statusCode == 404) {
    //     throw 'No picture to delete';
    //   } else {
    //     throw 'Failed to delete picture';
    //   }
    // });
    
    throw UnimplementedError('deleteImage not yet implemented');
  }
}
