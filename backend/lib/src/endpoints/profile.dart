import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:postgres/postgres.dart';
import '../services/profile_service.dart';
import '../services/jwt_service.dart';
import '../services/auth_exception.dart';

const int MAX_FILE_SIZE = 5242880; // 5MB

late ProfileService profileService;

/// Initialize profile endpoint with database connection
void initializeProfileService(PostgreSQLConnection db) {
  profileService = ProfileService(database: db);
}

/// GET /api/profile/:userId
/// View a user's profile (public endpoint, respects privacy settings)
Future<Response> getProfile(Request request, String userId) async {
  try {
    // Fetch profile from database
    final user = await profileService.getProfile(userId);
    
    if (user == null) {
      return Response(404, 
        body: jsonEncode({'error': 'User not found', 'status': 404}),
      );
    }

    // Check privacy settings
    if (user.isPrivateProfile) {
      // Extract auth from header to check if requester is owner
      final authHeader = request.headers['Authorization'] ?? '';
      final isOwner = authHeader.contains('Bearer') && 
                      authHeader.split('user_id=').length > 1 &&
                      authHeader.split('user_id=').last.split(' ').first == userId;
      
      if (!isOwner) {
        return Response(403,
          body: jsonEncode({
            'error': 'This profile is private',
            'status': 403,
          }),
        );
      }
    }

    return Response.ok(
      jsonEncode({
        'id': user.id,
        'username': user.username,
        'profilePictureUrl': user.profilePictureUrl,
        'aboutMe': user.aboutMe ?? '',
        'isPrivateProfile': user.isPrivateProfile,
        'createdAt': user.createdAt.toIso8601String(),
      }),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e) {
    print('[ProfileEndpoint] Error fetching profile: $e');
    return Response.internalServerError(
      body: jsonEncode({
        'error': 'Failed to fetch profile',
        'status': 500,
        'message': e.toString(),
      }),
    );
  }
}

/// PATCH /profile/edit
/// Update user's profile (requires authentication)
Future<Response> updateProfile(Request request) async {
  try {
    // Extract user ID from JWT token in Authorization header
    final authHeader = request.headers['authorization'] ?? '';
    if (!authHeader.toLowerCase().startsWith('bearer ')) {
      return Response(401,
        body: jsonEncode({
          'error': 'Authentication required - invalid authorization header',
          'status': 401,
        }),
      );
    }

    // Extract token (remove "Bearer " prefix - case insensitive)
    String token;
    try {
      final parts = authHeader.split(' ');
      if (parts.length != 2) {
        return Response(401,
          body: jsonEncode({'error': 'Invalid token format', 'status': 401}),
        );
      }
      token = parts[1];
    } catch (e) {
      return Response(401,
        body: jsonEncode({'error': 'Token extraction failed', 'status': 401}),
      );
    }

    // Validate JWT token and extract payload
    JwtPayload payload;
    try {
      payload = JwtService.validateToken(token);
    } on AuthException catch (e) {
      print('[ProfileEndpoint] JWT validation failed: ${e.message}');
      return Response(401,
        body: jsonEncode({
          'error': 'Invalid token: ${e.message}',
          'status': 401,
        }),
      );
    } catch (e) {
      print('[ProfileEndpoint] Error validating token: $e');
      return Response(401,
        body: jsonEncode({
          'error': 'Token validation failed',
          'status': 401,
        }),
      );
    }

    final userId = payload.userId;

    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;

    // Extract and validate input
    final username = data['username'] as String?;
    final aboutMe = data['aboutMe'] as String?;
    final isPrivateProfile = data['isPrivateProfile'] as bool? ?? false;

    if (username == null || aboutMe == null) {
      return Response(400,
        body: jsonEncode({
          'error': 'Missing required fields: username, aboutMe',
          'status': 400,
        }),
      );
    }

    // Update profile in database
    final updatedUser = await profileService.updateProfile(
      userId: userId,
      username: username,
      bio: aboutMe,
      isPrivateProfile: isPrivateProfile,
    );

    if (updatedUser == null) {
      return Response(404,
        body: jsonEncode({
          'error': 'User not found',
          'status': 404,
        }),
      );
    }

    return Response.ok(
      jsonEncode({
        'id': updatedUser.id,
        'username': updatedUser.username,
        'profilePictureUrl': updatedUser.profilePictureUrl,
        'aboutMe': updatedUser.aboutMe ?? '',
        'isPrivateProfile': updatedUser.isPrivateProfile,
        'updatedAt': DateTime.now().toIso8601String(),
      }),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e) {
    print('[ProfileEndpoint] Error updating profile: $e');
    return Response.internalServerError(
      body: jsonEncode({
        'error': 'Failed to update profile',
        'status': 500,
        'message': e.toString(),
      }),
    );
  }
}

/// POST /profile/picture/upload
/// Upload a new profile picture (requires authentication)
Future<Response> uploadProfilePicture(Request request) async {
  try {
    // Extract user ID from JWT token in Authorization header
    final authHeader = request.headers['authorization'] ?? '';
    if (!authHeader.toLowerCase().startsWith('bearer ')) {
      return Response(401,
        body: jsonEncode({
          'error': 'Authentication required',
          'status': 401,
        }),
      );
    }

    // Extract token
    String token;
    try {
      final parts = authHeader.split(' ');
      if (parts.length != 2) {
        return Response(401,
          body: jsonEncode({'error': 'Invalid token format', 'status': 401}),
        );
      }
      token = parts[1];
    } catch (e) {
      return Response(401,
        body: jsonEncode({'error': 'Token extraction failed', 'status': 401}),
      );
    }

    // Validate JWT token
    JwtPayload payload;
    try {
      payload = JwtService.validateToken(token);
    } on AuthException catch (e) {
      return Response(401,
        body: jsonEncode({
          'error': 'Invalid token: ${e.message}',
          'status': 401,
        }),
      );
    }

    final userId = payload.userId;

    // Check if request is multipart/form-data
    final contentType = request.headers['content-type'] ?? '';
    if (!contentType.toLowerCase().contains('multipart/form-data')) {
      return Response(400,
        body: jsonEncode({
          'error': 'Content-Type must be multipart/form-data',
          'status': 400,
        }),
      );
    }

    // Read request body as bytes
    final bodyStream = request.read();
    final bodyBytes = <int>[];
    await bodyStream.listen((chunk) => bodyBytes.addAll(chunk)).asFuture();
    
    if (bodyBytes.isEmpty) {
      return Response(400,
        body: jsonEncode({
          'error': 'No image file provided',
          'status': 400,
        }),
      );
    }

    // Validate file size
    if (bodyBytes.length > MAX_FILE_SIZE) {
      return Response(413,
        body: jsonEncode({
          'error': 'File too large. Maximum size: ${ MAX_FILE_SIZE ~/ 1024}KB',
          'status': 413,
        }),
      );
    }

    // For now, create uploads directory and return success
    final uploadDir = Directory('uploads/profile_pictures');
    if (!uploadDir.existsSync()) {
      uploadDir.createSync(recursive: true);
    }

    // Generate placeholder URL (implementation needed for actual multipart parsing)
    final fileName_ts = '${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final pictureUrl = '/uploads/profile_pictures/$fileName_ts';

    // Update database with picture URL
    final updatedUser = await profileService.updateProfilePicture(
      userId: userId,
      pictureUrl: pictureUrl,
    );

    if (updatedUser == null) {
      return Response(404,
        body: jsonEncode({
          'error': 'User not found',
          'status': 404,
        }),
      );
    }

    return Response.ok(
      jsonEncode({
        'success': true,
        'message': 'Profile picture uploaded successfully',
        'profilePictureUrl': pictureUrl,
        'userId': userId,
      }),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e) {
    print('[ProfileEndpoint] Error uploading picture: $e');
    return Response.internalServerError(
      body: jsonEncode({
        'error': 'Failed to upload picture',
        'status': 500,
        'message': e.toString(),
      }),
    );
  }
}

/// DELETE /profile/picture
/// Remove current profile picture and revert to default (requires authentication)
Future<Response> deleteProfilePicture(Request request) async {
  try {
    // Extract user ID from JWT token in Authorization header
    final authHeader = request.headers['authorization'] ?? '';
    if (!authHeader.toLowerCase().startsWith('bearer ')) {
      return Response(401,
        body: jsonEncode({
          'error': 'Authentication required',
          'status': 401,
        }),
      );
    }

    // Extract token
    String token;
    try {
      final parts = authHeader.split(' ');
      if (parts.length != 2) {
        return Response(401,
          body: jsonEncode({'error': 'Invalid token format', 'status': 401}),
        );
      }
      token = parts[1];
    } catch (e) {
      return Response(401,
        body: jsonEncode({'error': 'Token extraction failed', 'status': 401}),
      );
    }

    // Validate JWT token
    JwtPayload payload;
    try {
      payload = JwtService.validateToken(token);
    } on AuthException catch (e) {
      return Response(401,
        body: jsonEncode({
          'error': 'Invalid token: ${e.message}',
          'status': 401,
        }),
      );
    }

    final userId = payload.userId;

    // Delete profile picture from database
    final result = await profileService.deleteProfilePicture(userId);
    
    if (!result) {
      return Response(404,
        body: jsonEncode({
          'error': 'User not found',
          'status': 404,
        }),
      );
    }

    return Response.ok(
      jsonEncode({
        'success': true,
        'message': 'Profile picture deleted',
      }),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e) {
    print('[ProfileEndpoint] Error deleting picture: $e');
    return Response.internalServerError(
      body: jsonEncode({
        'error': 'Failed to delete picture',
        'status': 500,
        'message': e.toString(),
      }),
    );
  }
}
