import 'dart:convert';
import 'package:shelf/shelf.dart';
import '../services/profile_service.dart';

final profileService = ProfileService();

/// Mock in-memory database for profiles (TODO: replace with real DB)
final Map<String, Map<String, dynamic>> _mockProfiles = {};

const int MAX_FILE_SIZE = 5242880; // 5MB

/// GET /profile/view/{userId}
/// View a user's profile (public endpoint, respects privacy settings)
Future<Response> getProfile(Request request, String userId) async {
  try {
    // Check if profile exists in mock database
    if (!_mockProfiles.containsKey(userId)) {
      return Response(404, body: jsonEncode({'error': 'Profile not found'}));
    }

    final profile = _mockProfiles[userId]!;
    final isPrivate = profile['is_private_profile'] as bool? ?? false;

    // Get requester ID from auth header if available
    final authHeader = request.headers['Authorization'] ?? '';
    final isOwner = authHeader.contains('user_id=$userId');

    // Check privacy
    if (isPrivate && !isOwner) {
      return Response(403, body: jsonEncode({'error': 'This profile is private'}));
    }

    return Response.ok(
      jsonEncode(profile),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': 'Unable to retrieve profile'}),
    );
  }
}

/// PATCH /profile/edit
/// Update user's profile (requires authentication)
Future<Response> editProfile(Request request) async {
  try {
    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;

    // Extract auth from header
    final authHeader = request.headers['Authorization'] ?? '';
    if (!authHeader.contains('user_id=')) {
      return Response(401, body: jsonEncode({'error': 'Unauthorized'}));
    }

    final userId = authHeader.split('user_id=').last.split(' ').first;

    // Validate update data
    final errors = profileService.validateProfileUpdate(
      username: data['username'] as String?,
      aboutMe: data['aboutMe'] as String?,
    );

    if (errors != null) {
      return Response(400, body: jsonEncode({'errors': errors}));
    }

    // Get existing profile or create default
    if (!_mockProfiles.containsKey(userId)) {
      _mockProfiles[userId] = {
        'userId': userId,
        'username': 'user_$userId',
        'email': 'user@example.com',
        'profilePictureUrl': null,
        'aboutMe': '',
        'isDefaultProfilePicture': true,
        'isPrivateProfile': false,
        'profileUpdatedAt': DateTime.now().toIso8601String(),
        'createdAt': DateTime.now().toIso8601String(),
      };
    }

    // Update profile fields
    if (data.containsKey('username')) {
      _mockProfiles[userId]!['username'] = profileService.sanitizeText(data['username'] as String, 32);
    }
    if (data.containsKey('aboutMe')) {
      _mockProfiles[userId]!['aboutMe'] = profileService.sanitizeText(data['aboutMe'] as String, 500);
    }
    if (data.containsKey('isPrivateProfile')) {
      _mockProfiles[userId]!['isPrivateProfile'] = data['isPrivateProfile'] as bool;
    }
    _mockProfiles[userId]!['profileUpdatedAt'] = DateTime.now().toIso8601String();

    return Response.ok(
      jsonEncode(_mockProfiles[userId]),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': 'Unable to update profile'}),
    );
  }
}

/// POST /profile/picture/upload
/// Upload a new profile picture (requires authentication)
Future<Response> uploadProfilePicture(Request request) async {
  try {
    final authHeader = request.headers['Authorization'] ?? '';
    if (!authHeader.contains('user_id=')) {
      return Response(401, body: jsonEncode({'error': 'Unauthorized'}));
    }

    final userId = authHeader.split('user_id=').last.split(' ').first;

    // For now, return success with placeholder URL
    // In production, this would parse multipart form data and store the file
    final mockImageUrl = '/uploads/profiles/$userId-${DateTime.now().millisecondsSinceEpoch}.jpg';

    // Update profile with new image
    if (!_mockProfiles.containsKey(userId)) {
      _mockProfiles[userId] = {
        'userId': userId,
        'username': 'user_$userId',
        'email': 'user@example.com',
        'isDefaultProfilePicture': false,
        'isPrivateProfile': false,
        'createdAt': DateTime.now().toIso8601String(),
      };
    }

    _mockProfiles[userId]!['profilePictureUrl'] = mockImageUrl;
    _mockProfiles[userId]!['isDefaultProfilePicture'] = false;
    _mockProfiles[userId]!['profileUpdatedAt'] = DateTime.now().toIso8601String();

    return Response.ok(
      jsonEncode({
        'success': true,
        'imageUrl': mockImageUrl,
        'profile': _mockProfiles[userId],
      }),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': 'Unable to upload image'}),
    );
  }
}

/// DELETE /profile/picture
/// Remove current profile picture and revert to default (requires authentication)
Future<Response> deleteProfilePicture(Request request) async {
  try {
    final authHeader = request.headers['Authorization'] ?? '';
    if (!authHeader.contains('user_id=')) {
      return Response(401, body: jsonEncode({'error': 'Unauthorized'}));
    }

    final userId = authHeader.split('user_id=').last.split(' ').first;

    if (!_mockProfiles.containsKey(userId)) {
      return Response(404, body: jsonEncode({'error': 'Profile not found'}));
    }

    // Revert to default picture
    _mockProfiles[userId]!['profilePictureUrl'] = null;
    _mockProfiles[userId]!['isDefaultProfilePicture'] = true;
    _mockProfiles[userId]!['profileUpdatedAt'] = DateTime.now().toIso8601String();

    return Response.ok(
      jsonEncode({
        'success': true,
        'message': 'Profile picture removed',
        'profile': _mockProfiles[userId],
      }),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({'error': 'Unable to delete image'}),
    );
  }
}

