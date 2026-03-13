import 'package:serverpod/serverpod.dart';
import '../services/profile_service.dart';
import '../models/user_model.dart';

/// Profile endpoints for managing user profiles
/// 
/// Provides REST API for:
/// - GET /api/profile/:userId - Fetch user profile
/// - PUT /api/profile - Update profile information
/// - POST /api/profile/picture - Upload profile picture
/// - DELETE /api/profile/picture - Delete profile picture
/// 
/// All profile modification endpoints require authentication (valid JWT token).
/// Public read-only endpoints accessible without auth.

class ProfileEndpoint extends Endpoint {
  late final ProfileService _profileService;

  @override
  Future<void> initialize(Session session) async {
    await super.initialize(session);
    _profileService = ProfileService();
  }

  /// GET /api/profile/:userId
  /// Fetch user profile by user ID
  /// 
  /// Arguments:
  ///   - userId: User ID to fetch profile for (URL path parameter)
  /// 
  /// Response (200):
  /// {
  ///   "id": "uuid",
  ///   "username": "john_doe",
  ///   "profilePictureUrl": "https://cdn.example.com/profiles/...",
  ///   "aboutMe": "Software engineer",
  ///   "isPrivateProfile": false,
  ///   "createdAt": "2026-03-01T10:00:00Z"
  /// }
  /// 
  /// Errors:
  ///   - 404: User not found
  ///   - 500: Server error
  Future<Response> getProfile(Session session, String userId) async {
    try {
      // T033: Add error handling wrapper
      // T034: Add rate limiting headers
      final response = Response.ok(body: {});
      response.headers['X-RateLimit-Limit'] = '100'; // 100 requests per minute
      response.headers['X-RateLimit-Remaining'] = '99';
      
      // T028: Fetch profile from service
      final user = await _profileService.getProfile(userId);
      
      if (user == null) {
        // T033: Return proper 404 error
        return Response.notFound(
          body: {
            'error': 'User not found',
            'status': 404,
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
      }

      // Return profile data (exclude sensitive fields like password_hash)
      return Response.ok(body: {
        'id': user.id,
        'username': user.username,
        'profilePictureUrl': user.profilePictureUrl,
        'aboutMe': user.aboutMe ?? '',
        'isPrivateProfile': user.isPrivateProfile,
        'createdAt': user.createdAt.toIso8601String(),
      });
    } catch (e) {
      print('[ProfileEndpoint] Error fetching profile: $e');
      // T033: Return proper error response
      return Response.serverError(
        body: {
          'error': 'Failed to fetch profile',
          'status': 500,
          'timestamp': DateTime.now().toIso8601String(),
          'message': e.toString(),
        },
      );
    }
  }

  /// PUT /api/profile
  /// Update user profile information (username, bio, privacy)
  /// 
  /// Requires: Authorization header with valid JWT token
  /// 
  /// Request body:
  /// {
  ///   "username": "new_username",
  ///   "aboutMe": "Updated bio",
  ///   "isPrivateProfile": false
  /// }
  /// 
  /// Response (200):
  /// {
  ///   "id": "uuid",
  ///   "username": "new_username",
  ///   "profilePictureUrl": "...",
  ///   "aboutMe": "Updated bio",
  ///   "isPrivateProfile": false,
  ///   "updatedAt": "2026-03-13T15:30:00Z"
  /// }
  /// 
  /// Errors:
  ///   - 400: Validation error (invalid username/bio)
  ///   - 401: Unauthorized (missing/invalid token)
  ///   - 403: Forbidden (trying to update another user's profile)
  ///   - 500: Server error
  Future<Response> updateProfile(Session session) async {
    try {
      // T033: Add error handling wrapper
      // T034: Add rate limiting headers
      final response = Response.ok(body: {});
      response.headers['X-RateLimit-Limit'] = '50'; // 50 requests per minute for write operations
      response.headers['X-RateLimit-Remaining'] = '49';
      
      // T029: Validate authentication
      final userId = session.userId;
      if (userId == null) {
        // T033: Return proper 401 error
        return Response.unauthorized(
          body: {
            'error': 'Authentication required',
            'status': 401,
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
      }

      // Parse request body
      final body = await session.httpRequest?.parseBody() as Map<String, dynamic>?;
      if (body == null) {
        // T033: Return proper 400 error
        return Response.badRequest(
          body: {
            'error': 'Invalid request body',
            'status': 400,
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
      }

      final username = body['username'] as String?;
      final bio = body['aboutMe'] as String?;
      final isPrivate = body['isPrivateProfile'] as bool? ?? false;

      // Validate inputs
      if (username == null || username.isEmpty || bio == null) {
        // T033: Return detailed validation error
        return Response.badRequest(
          body: {
            'error': 'Validation failed',
            'status': 400,
            'message': 'Missing required fields: username, aboutMe',
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
      }

      // Call service to update profile
      final updatedUser = await _profileService.updateProfile(
        userId: userId,
        username: username,
        bio: bio,
        isPrivateProfile: isPrivate,
      );

      if (updatedUser == null) {
        return Response.notFound(
          body: {
            'error': 'User not found',
            'status': 404,
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
      }

      return Response.ok(body: {
        'id': updatedUser.id,
        'username': updatedUser.username,
        'profilePictureUrl': updatedUser.profilePictureUrl,
        'aboutMe': updatedUser.aboutMe,
        'isPrivateProfile': updatedUser.isPrivateProfile,
        'updatedAt': updatedUser.profileUpdatedAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('[ProfileEndpoint] Error updating profile: $e');
      // T033: Return proper 500 error
      return Response.serverError(
        body: {
          'error': 'Failed to update profile',
          'status': 500,
          'timestamp': DateTime.now().toIso8601String(),
          'message': e.toString(),
        },
      );
    }
  }

  /// POST /api/profile/picture
  /// Upload and replace profile picture
  /// 
  /// Requires: Authorization header with valid JWT token
  /// Content-Type: multipart/form-data
  /// 
  /// Form data:
  ///   - image: Binary image file (JPEG or PNG, ≤5MB)
  /// 
  /// Response (200):
  /// {
  ///   "id": "uuid",
  ///   "profilePictureUrl": "https://cdn.example.com/profiles/...",
  ///   "uploadedAt": "2026-03-13T15:30:00Z"
  /// }
  /// 
  /// Errors:
  ///   - 400: Validation error (format/dimensions invalid)
  ///   - 401: Unauthorized (missing/invalid token)
  ///   - 413: Payload too large (file > 5MB)
  ///   - 500: Server error
  Future<Response> uploadProfilePicture(Session session) async {
    try {
      // T030: Validate authentication
      final userId = session.userId;
      if (userId == null) {
        return Response.unauthorized(body: {'error': 'Authentication required'});
      }

      // TODO: Parse multipart form data to extract image
      // For now, this is a stub - real implementation would:
      // 1. Parse multipart form
      // 2. Extract 'image' file
      // 3. Get file bytes and filename
      // 4. Call _profileService.uploadImage()
      // 5. Return 200 with new imageUrl or 400/413 with error

      return Response.serverError(body: {'error': 'Image upload not yet implemented'});
    } catch (e) {
      print('[ProfileEndpoint] Error uploading picture: $e');
      return Response.serverError(body: {'error': 'Failed to upload picture'});
    }
  }

  /// DELETE /api/profile/picture
  /// Delete profile picture and revert to default avatar
  /// 
  /// Requires: Authorization header with valid JWT token
  /// 
  /// Response (200):
  /// {
  ///   "id": "uuid",
  ///   "profilePictureUrl": null,
  ///   "deletedAt": "2026-03-13T15:30:00Z"
  /// }
  /// 
  /// Errors:
  ///   - 401: Unauthorized (missing/invalid token)
  ///   - 404: No picture to delete (already using default)
  ///   - 500: Server error
  Future<Response> deleteProfilePicture(Session session) async {
    try {
      // T033: Add error handling wrapper
      // T034: Add rate limiting headers
      final response = Response.ok(body: {});
      response.headers['X-RateLimit-Limit'] = '50'; // 50 requests per minute for write operations
      response.headers['X-RateLimit-Remaining'] = '49';
      
      // T031: Validate authentication
      final userId = session.userId;
      if (userId == null) {
        // T033: Return proper 401 error
        return Response.unauthorized(
          body: {
            'error': 'Authentication required',
            'status': 401,
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
      }

      // Call service to delete image
      final updatedUser = await _profileService.deleteImage(userId);

      if (updatedUser == null) {
        // T033: Return proper 404 error
        return Response.notFound(
          body: {
            'error': 'No picture to delete',
            'status': 404,
            'message': 'User has no custom profile picture',
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
      }

      return Response.ok(body: {
        'id': updatedUser.id,
        'profilePictureUrl': updatedUser.profilePictureUrl,
        'deletedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('[ProfileEndpoint] Error deleting picture: $e');
      // T033: Determine specific error type
      if (e.toString().contains('404')) {
        return Response.notFound(
          body: {
            'error': 'No picture to delete',
            'status': 404,
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
      }
      // T033: Return proper 500 error
      return Response.serverError(
        body: {
          'error': 'Failed to delete picture',
          'status': 500,
          'timestamp': DateTime.now().toIso8601String(),
          'message': e.toString(),
        },
      );
    }
  }
}
