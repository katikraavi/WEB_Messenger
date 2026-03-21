import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:frontend/features/profile/models/user_profile.dart';
import 'package:frontend/core/services/api_client.dart';

/// API service for profile-related HTTP requests
/// 
/// Handles communication with the backend for profile operations:
/// - Fetching profile data
/// - Updating profile information
/// - Uploading profile pictures
/// - Deleting profile pictures
/// 
/// Features for Phase 11 (Polish):
/// - T134: Network timeout handling (30 second default)
/// - T147: Logging for debugging
/// - T135: Rapid-fire upload protection (1 second dedupe)

class ProfileApiService {
  /// Base API URL for profile endpoints
  static const String baseUrl = '/api/profile';
  
  /// Network timeout duration for all API calls [T134]
  static const Duration networkTimeout = Duration(seconds: 30);
  
  /// Minimum time between uploads to prevent rapid-fire requests [T135]
  static const Duration uploadDebounceTime = Duration(seconds: 1);
  
  /// Track last upload time for rapid-fire protection [T135]
  DateTime? _lastUploadTime;
  
  /// Enable debug logging [T147]
  static const bool debugLogging = true;

  /// Helper method to ensure profile picture URLs are absolute
  /// 
  /// Converts relative URLs like `/uploads/profile_pictures/...` to absolute URLs
  /// like `http://localhost:8081/uploads/profile_pictures/...`
  /// 
  /// This is needed because Image.network() requires full URLs with http scheme
  UserProfile _ensureAbsoluteImageUrl(UserProfile profile) {
    if (profile.profilePictureUrl == null || profile.profilePictureUrl!.isEmpty) {
      return profile;
    }
    
    final imageUrl = profile.profilePictureUrl!;
    
    // If URL already has http scheme, return as-is
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return profile;
    }
    
    // If URL is relative, prepend the base URL
    if (imageUrl.startsWith('/')) {
      final baseUrl = ApiClient.getBaseUrl();
      final cleanBaseUrl = baseUrl.replaceAll(RegExp(r'/api$'), '');
      final absoluteUrl = cleanBaseUrl + imageUrl;
      if (debugLogging) {
        debugPrint('[ProfileApiService] Image URL converted: $imageUrl → $absoluteUrl');
      }
      return profile.copyWith(profilePictureUrl: absoluteUrl);
    }
    
    return profile;
  }

  /// Fetches user profile data from backend [T044]
  /// 
  /// Arguments:
  ///   - userId: User ID to fetch profile for
  ///   - token: Optional auth token for making the request
  /// 
  /// Returns: [UserProfile] object
  /// 
  /// Throws: May throw HttpException or FormatException on error
  /// 
  /// HTTP: `GET /api/profile/:userId`
  /// Status: 200 = success, 401 = unauthorized, 404 = not found, 500 = server error
  Future<UserProfile> fetchProfile(String userId, {String? token}) async {
    try {
      final baseUrl = ApiClient.getBaseUrl();
      final url = '$baseUrl/profile/view/$userId';
      
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
      
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(
        networkTimeout,
        onTimeout: () => throw HttpException('Request timeout after ${networkTimeout.inSeconds}s'),
      );

      if (response.statusCode == 200) {
        try {
          final jsonBody = jsonDecode(response.body) as Map<String, dynamic>;
          final profile = UserProfile.fromJson(jsonBody);
          if (debugLogging) {
            debugPrint('[ProfileApiService] Profile fetched - image URL: ${profile.profilePictureUrl}');
          }
          return _ensureAbsoluteImageUrl(profile);
        } catch (e) {
          throw FormatException('Failed to parse profile response: $e');
        }
      } else if (response.statusCode == 404) {
        throw HttpException('User profile not found (404)');
      } else if (response.statusCode == 401) {
        throw HttpException('Unauthorized (401)');
      } else {
        throw HttpException('Failed to fetch profile: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('[ProfileApiService] Error fetching profile: $e');
      rethrow;
    }
  }

  /// Updates user profile information (username, bio, privacy setting) [T063]
  /// 
  /// Arguments:
  ///   - username: New username (3-32 characters)
  ///   - bio: New bio/about me text (0-500 characters)
  ///   - isPrivateProfile: Privacy setting (true = private, false = public)
  ///   - token: Optional auth token for making the request
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
    String? token,
  }) async {
    try {
      final baseUrl = ApiClient.getBaseUrl();
      final url = '$baseUrl/profile/edit';
      
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final body = jsonEncode({
        'username': username,
        'aboutMe': bio,
        'isPrivateProfile': isPrivateProfile,
      });

      if (debugLogging) {
        debugPrint('[ProfileApiService] PATCH $url');
        debugPrint('[ProfileApiService] Request body: $body');
      }
      
      final response = await http.patch(
        Uri.parse(url),
        headers: headers,
        body: body,
      ).timeout(
        networkTimeout,
        onTimeout: () => throw HttpException('Request timeout after ${networkTimeout.inSeconds}s'),
      );

      if (debugLogging) {
        debugPrint('[ProfileApiService] Response status: ${response.statusCode}');
        debugPrint('[ProfileApiService] Response body: ${response.body}');
      }

      if (response.statusCode == 200) {
        try {
          final jsonBody = jsonDecode(response.body) as Map<String, dynamic>;
          return _ensureAbsoluteImageUrl(UserProfile.fromJson(jsonBody));
        } catch (e) {
          throw FormatException('Failed to parse profile response: $e');
        }
      } else if (response.statusCode == 400) {
        final errorBody = jsonDecode(response.body) as Map<String, dynamic>;
        final errorMsg = errorBody['message'] ?? errorBody['error'] ?? 'Validation error';
        throw HttpException('Validation error: $errorMsg');
      } else if (response.statusCode == 401) {
        throw HttpException('Unauthorized (401)');
      } else {
        throw HttpException('Failed to update profile: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('[ProfileApiService] Error updating profile: $e');
      rethrow;
    }
  }

  /// Uploads a profile picture image
  /// 
  /// Arguments:
  ///   - imageFile: Image file to upload (must be JPEG or PNG, ≤5MB)
  ///   - token: Optional auth token for making the request
  /// 
  /// Returns: Updated [UserProfile] object with new profilePictureUrl
  /// 
  /// Throws: May throw HttpException, FormatException, or FileException on error
  /// 
  /// HTTP: `POST /api/profile/picture` (multipart/form-data)
  /// Status: 200 = success, 400 = validation error, 401 = unauthorized, 413 = file too large, 500 = server error
  Future<UserProfile> uploadImage(File imageFile, {String? token}) async {
    try {
      final baseUrl = ApiClient.getBaseUrl();
      final url = '$baseUrl/profile/picture/upload';
      
      // Create multipart request
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(url),
      );

      // Add authorization header if token provided
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      // Add the image file to the request
      final stream = http.ByteStream(imageFile.openRead());
      final length = await imageFile.length();
      
      final multipartFile = http.MultipartFile(
        'image',
        stream,
        length,
        filename: imageFile.path.split('/').last,
      );
      
      request.files.add(multipartFile);

      // Send the request
      final response = await request.send().timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw HttpException('Upload timeout after 60 seconds');
        },
      );

      // Read response body
      final responseBody = await response.stream.bytesToString();

      // Handle response based on status code
      if (response.statusCode == 200) {
        try {
          final jsonBody = jsonDecode(responseBody);
          
          // Check if this is an upload response (has profilePictureUrl and userId)
          if (jsonBody.containsKey('profilePictureUrl') && 
              !jsonBody.containsKey('username')) {
            // This is an upload response, not a full profile
            // Create a minimal UserProfile with the uploaded picture URL
            final uploadResponse = jsonBody as Map<String, dynamic>;
            
            // Return a UserProfile with minimal required fields
            // The actual user data will be updated through other means
            // Ensure the image URL is absolute (convert /uploads/... to http://...)
            return _ensureAbsoluteImageUrl(UserProfile(
              userId: uploadResponse['userId'] as String? ?? 'unknown',
              username: '', // Will be ignored by caller
              profilePictureUrl: uploadResponse['profilePictureUrl'] as String?,
              aboutMe: '',
              isDefaultProfilePicture: false,
            ));
          }
          
          // Otherwise, try to parse as a full profile response
          final profileData = jsonBody['profile'] ?? jsonBody['data'] ?? jsonBody;
          return _ensureAbsoluteImageUrl(UserProfile.fromJson(profileData as Map<String, dynamic>));
        } catch (e) {
          debugPrint('[ProfileApiService] Error parsing profile response: $e');
          debugPrint('[ProfileApiService] Response body: $responseBody');
          throw FormatException(
            'Failed to parse profile response: $e',
            responseBody,
          );
        }
      } else if (response.statusCode == 400) {
        // Validation error (format, size, dimensions)
        throw HttpException(
          'Validation error: ${response.statusCode}. ${responseBody.isNotEmpty ? responseBody : 'Invalid image format or size'}',
        );
      } else if (response.statusCode == 401) {
        throw HttpException('Unauthorized (401) - Please log in again');
      } else if (response.statusCode == 413) {
        throw HttpException('File too large (413) - Image must be smaller than 5MB');
      } else if (response.statusCode == 500) {
        throw HttpException(
          'Server error (500) - Unable to process image. Please try again.',
        );
      } else {
        throw HttpException(
          'Failed to upload image: HTTP ${response.statusCode}. Response: $responseBody',
        );
      }
    } catch (e) {
      debugPrint('[ProfileApiService] Error uploading image: $e');
      rethrow;
    }
  }

  /// Deletes the profile picture (reverts to default avatar)
  /// 
  /// Arguments:
  ///   - token: Optional auth token for making the request
  /// 
  /// Returns: Updated [UserProfile] object (profilePictureUrl = null)
  /// 
  /// Throws: May throw HttpException or FormatException on error
  /// 
  /// HTTP: `DELETE /api/profile/picture`
  /// Status: 200 = success, 401 = unauthorized, 404 = no picture to delete, 500 = server error
  Future<UserProfile> deleteImage({String? token}) async {
    try {
      final baseUrl = ApiClient.getBaseUrl();
      final url = '$baseUrl/profile/picture';
      
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
      
      final response = await http.delete(
        Uri.parse(url),
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      // Read response body
      final responseBody = response.body;

      // Handle response based on status code
      if (response.statusCode == 200) {
        try {
          final jsonBody = jsonDecode(responseBody);
          return _ensureAbsoluteImageUrl(UserProfile.fromJson(jsonBody));
        } catch (e) {
          throw FormatException(
            'Failed to parse profile response: $e',
            responseBody,
          );
        }
      } else if (response.statusCode == 401) {
        throw HttpException('Unauthorized (401) - Please log in again');
      } else if (response.statusCode == 404) {
        throw HttpException('No picture to delete (404)');
      } else if (response.statusCode == 500) {
        throw HttpException(
          'Server error (500) - Unable to delete image. Please try again.',
        );
      } else {
        throw HttpException(
          'Failed to delete image: HTTP ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('[ProfileApiService] Error deleting image: $e');
      rethrow;
    }
  }
}
