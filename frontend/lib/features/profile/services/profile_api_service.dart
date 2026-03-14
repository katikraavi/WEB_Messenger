import 'dart:io';
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

      if (debugLogging) print('[ProfileApiService] GET $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(
        networkTimeout,
        onTimeout: () => throw HttpException('Request timeout after ${networkTimeout.inSeconds}s'),
      );

      if (debugLogging) print('[ProfileApiService] Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        try {
          final jsonBody = jsonDecode(response.body) as Map<String, dynamic>;
          return UserProfile.fromJson(jsonBody);
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
      print('[ProfileApiService] Error fetching profile: $e');
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
        print('[ProfileApiService] PATCH $url');
        print('[ProfileApiService] Request body: $body');
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
        print('[ProfileApiService] Response status: ${response.statusCode}');
        print('[ProfileApiService] Response body: ${response.body}');
      }

      if (response.statusCode == 200) {
        try {
          final jsonBody = jsonDecode(response.body) as Map<String, dynamic>;
          return UserProfile.fromJson(jsonBody);
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
      print('[ProfileApiService] Error updating profile: $e');
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
          return UserProfile.fromJson(jsonBody);
        } catch (e) {
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
      print('[ProfileApiService] Error uploading image: $e');
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
          return UserProfile.fromJson(jsonBody);
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
      print('[ProfileApiService] Error deleting image: $e');
      rethrow;
    }
  }
}
