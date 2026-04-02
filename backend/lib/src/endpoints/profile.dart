import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:shelf/shelf.dart';
import 'package:postgres/postgres.dart';
import '../services/profile_service.dart';
import '../services/jwt_service.dart';
import '../services/auth_exception.dart';
import '../services/websocket_service.dart';

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
    print('[ProfileEndpoint] ========== UPLOAD REQUEST START ==========');
    print('[ProfileEndpoint] Method: ${request.method}');
    print('[ProfileEndpoint] Path: ${request.url.path}');
    print('[ProfileEndpoint] Content-Type: ${request.headers['content-type']}');
    
    // Extract user ID from JWT token in Authorization header
    final authHeader = request.headers['authorization'] ?? '';
    print('[ProfileEndpoint] Authorization header present: ${authHeader.isNotEmpty}');
    print('[ProfileEndpoint] Auth header (first 50 chars): ${authHeader.substring(0, min(50, authHeader.length))}');
    
    if (!authHeader.toLowerCase().startsWith('bearer ')) {
      print('[ProfileEndpoint] ❌ Invalid authorization header format');
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
      print('[ProfileEndpoint] Token parts count: ${parts.length}');
      if (parts.length != 2) {
        print('[ProfileEndpoint] ❌ Invalid token parts');
        return Response(401,
          body: jsonEncode({'error': 'Invalid token format', 'status': 401}),
        );
      }
      token = parts[1];
      print('[ProfileEndpoint] Token extracted (length: ${token.length})');
    } catch (e) {
      print('[ProfileEndpoint] ❌ Token extraction error: $e');
      return Response(401,
        body: jsonEncode({'error': 'Token extraction failed', 'status': 401}),
      );
    }

    // Validate JWT token
    JwtPayload payload;
    try {
      print('[ProfileEndpoint] Validating token...');
      payload = JwtService.validateToken(token);
      print('[ProfileEndpoint] ✅ Token validated. User ID: ${payload.userId}');
    } on AuthException catch (e) {
      print('[ProfileEndpoint] ❌ Token validation error: ${e.message}');
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

    // Create uploads directory
    final uploadDir = Directory('uploads/profile_pictures');
    if (!uploadDir.existsSync()) {
      uploadDir.createSync(recursive: true);
    }

    // Extract image bytes from multipart form data
    List<int> imageBytes;
    
    print('[ProfileEndpoint] Received multipart data: ${bodyBytes.length} bytes');
    print('[ProfileEndpoint] Content-Type header: $contentType');
    
    try {
      // Parse multipart data to extract the image file
      imageBytes = _extractImageBytesFromMultipart(bodyBytes, contentType);
      
      print('[ProfileEndpoint] Extracted image bytes: ${imageBytes.length} bytes');
      
      if (imageBytes.isEmpty) {
        print('[ProfileEndpoint] ❌ No image data found in multipart request');
        return Response(400,
          body: jsonEncode({
            'error': 'No image data found in multipart request',
            'status': 400,
          }),
        );
      }
    } catch (e) {
      print('[ProfileEndpoint] ❌ Error parsing multipart data: $e');
      return Response(400,
        body: jsonEncode({
          'error': 'Failed to parse image from request: $e',
          'status': 400,
        }),
      );
    }

    // Generate filename with timestamp
    final fileName_ts = '${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final filePath = 'uploads/profile_pictures/$fileName_ts';
    final pictureUrl = '/uploads/profile_pictures/$fileName_ts';

    try {
      print('[ProfileEndpoint] Creating upload directory...');
      // Ensure the directory exists
      final uploadDir = Directory('uploads/profile_pictures');
      if (!uploadDir.existsSync()) {
        uploadDir.createSync(recursive: true);
        print('[ProfileEndpoint] Created directories: ${uploadDir.path}');
      }
      
      // Write image bytes to file
      final file = File(filePath);
      await file.writeAsBytes(imageBytes);

      print('[⚡] Image saved: $filePath');
    } catch (e) {
      print('[ProfileEndpoint] Error saving image file: $e');
      return Response.internalServerError(
        body: jsonEncode({
          'error': 'Failed to save image file',
          'status': 500,
          'message': e.toString(),
        }),
      );
    }

    // 🗑️ DELETE OLD PICTURE FILE IF IT EXISTS
    try {
      final currentUser = await profileService.getProfile(userId);
      if (currentUser != null && currentUser.profilePictureUrl != null && currentUser.profilePictureUrl!.isNotEmpty) {
        final oldUrl = currentUser.profilePictureUrl!;
        // Extract file path from URL (e.g., "/uploads/profile_pictures/user_123.jpg" -> "uploads/profile_pictures/user_123.jpg")
        final oldFilePath = oldUrl.startsWith('/') ? oldUrl.substring(1) : oldUrl;
        final oldFullPath = oldFilePath;
        
        try {
          final oldFile = File(oldFullPath);
          if (oldFile.existsSync()) {
            await oldFile.delete();
            print('[ProfileEndpoint] 🗑️ Deleted old picture file: $oldFullPath');
          }
        } catch (e) {
          print('[ProfileEndpoint] ⚠️ Failed to delete old picture file: $e');
          // Continue anyway - don't fail the upload if cleanup fails
        }
      }
    } catch (e) {
      print('[ProfileEndpoint] ⚠️ Error during old picture cleanup: $e');
      // Continue anyway - don't fail the upload
    }

    // Add cache-busting timestamp to force fresh image load
    final cacheTs = DateTime.now().millisecondsSinceEpoch;
    final pictureUrlWithCache = '$pictureUrl?v=$cacheTs';

    // Update database with picture URL (including cache buster)
    final updatedUser = await profileService.updateProfilePicture(
      userId: userId,
      pictureUrl: pictureUrlWithCache,
    );

    if (updatedUser == null) {
      return Response(404,
        body: jsonEncode({
          'error': 'User not found',
          'status': 404,
        }),
      );
    }

    // 🔄 Broadcast profile_updated event to all connected users via WebSocket
    try {
      final webSocketService = WebSocketService.getInstance();
      webSocketService.broadcastToAllUsers({
        'type': 'profile_updated',
        'userId': userId,
        'profilePictureUrl': pictureUrlWithCache,
        'timestamp': DateTime.now().toIso8601String(),
      });
      print('[ProfileEndpoint] 📡 Broadcast profile_updated for user: $userId with cache-bust: $cacheTs');
    } catch (e) {
      print('[ProfileEndpoint] ⚠️ Failed to broadcast profile update: $e');
      // Don't fail the response, user still gets their picture updated
    }

    return Response.ok(
      jsonEncode({
        'success': true,
        'message': 'Profile picture uploaded successfully',
        'profilePictureUrl': pictureUrlWithCache,
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

/// POST /profile/picture/url
/// Update profile picture URL directly (client uploads file to external storage)
Future<Response> updateProfilePictureUrl(Request request) async {
  try {
    final authHeader = request.headers['authorization'] ?? '';
    if (!authHeader.toLowerCase().startsWith('bearer ')) {
      return Response(401,
        body: jsonEncode({
          'error': 'Authentication required',
          'status': 401,
        }),
      );
    }

    final parts = authHeader.split(' ');
    if (parts.length != 2) {
      return Response(401,
        body: jsonEncode({'error': 'Invalid token format', 'status': 401}),
      );
    }

    final token = parts[1];
    final payload = JwtService.validateToken(token);
    final userId = payload.userId;

    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;
    final rawUrl = data['profilePictureUrl'] as String?;

    if (rawUrl == null || rawUrl.trim().isEmpty) {
      return Response(400,
        body: jsonEncode({
          'error': 'Missing profilePictureUrl',
          'status': 400,
        }),
      );
    }

    final parsed = Uri.tryParse(rawUrl.trim());
    if (parsed == null || !parsed.hasScheme || (parsed.scheme != 'http' && parsed.scheme != 'https')) {
      return Response(400,
        body: jsonEncode({
          'error': 'profilePictureUrl must be a valid http/https URL',
          'status': 400,
        }),
      );
    }

    final cacheTs = DateTime.now().millisecondsSinceEpoch;
    final withCacheBust = rawUrl.contains('?')
        ? '${rawUrl.trim()}&v=$cacheTs'
        : '${rawUrl.trim()}?v=$cacheTs';

    final updatedUser = await profileService.updateProfilePicture(
      userId: userId,
      pictureUrl: withCacheBust,
    );

    if (updatedUser == null) {
      return Response(404,
        body: jsonEncode({
          'error': 'User not found',
          'status': 404,
        }),
      );
    }

    try {
      final webSocketService = WebSocketService.getInstance();
      webSocketService.broadcastToAllUsers({
        'type': 'profile_updated',
        'userId': userId,
        'profilePictureUrl': withCacheBust,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (_) {}

    return Response.ok(
      jsonEncode({
        'success': true,
        'message': 'Profile picture URL updated successfully',
        'profilePictureUrl': withCacheBust,
        'userId': userId,
      }),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (e) {
    return Response.internalServerError(
      body: jsonEncode({
        'error': 'Failed to update profile picture URL',
        'status': 500,
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

    try {
      final webSocketService = WebSocketService.getInstance();
      webSocketService.broadcastToAllUsers({
        'type': 'profile_updated',
        'userId': userId,
        'profilePictureUrl': null,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (_) {}

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

/// Helper function to extract image bytes from multipart/form-data
/// 
/// Parses the multipart-encoded request body and extracts the image file bytes
/// This is a simple parser that looks for JPEG/PNG signatures
List<int> _extractImageBytesFromMultipart(List<int> bodyBytes, String contentType) {
  // Try to find the boundary
  final boundaryMatch = RegExp(r'boundary=([^;]+)').firstMatch(contentType);
  if (boundaryMatch == null) {
    print('[Multipart] ❌ No boundary found in Content-Type header');
    throw FormatException('No boundary found in multipart content-type');
  }
  
  final boundary = boundaryMatch.group(1)!.trim();
  print('[Multipart] Boundary extracted: "$boundary" (length: ${boundary.length})');
  
  final boundaryBytes = utf8.encode('--$boundary');
  
  print('[Multipart] Looking for boundary markers: "${String.fromCharCodes(boundaryBytes)}"');
  
  // Find all boundary positions
  int startIdx = 0;
  final boundaries = <int>[];
  
  while ((startIdx = _searchBytes(bodyBytes, boundaryBytes, startIdx)) != -1) {
    boundaries.add(startIdx);
    print('[Multipart] Found boundary at position: $startIdx');
    startIdx += boundaryBytes.length;
  }
  
  print('[Multipart] Total boundaries found: ${boundaries.length}');
  
  if (boundaries.isEmpty) {
    // No boundaries found, return original bytes (might be raw image data)
    print('[Multipart] ⚠️  No boundaries found, checking first bytes of body...');
    if (bodyBytes.length >= 4) {
      print('[Multipart] Body first bytes: ${bodyBytes.sublist(0, 4).map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')}');
    }
    return bodyBytes;
  }
  
  // Extract data between boundaries
  for (int i = 0; i < boundaries.length - 1; i++) {
    int partStart = boundaries[i] + boundaryBytes.length;
    int partEnd = boundaries[i + 1];
    
    print('[Multipart] Processing part $i: from position $partStart to $partEnd');
    
    // Skip to after the headers (headers end with \r\n\r\n)
    final headerEndBytes = utf8.encode('\r\n\r\n');
    int headerEnd = _searchBytes(bodyBytes, headerEndBytes, partStart);
    
    if (headerEnd == -1) {
      headerEnd = _searchBytes(bodyBytes, utf8.encode('\n\n'), partStart);
      if (headerEnd != -1) {
        print('[Multipart] Found header end with \\n\\n at position: $headerEnd');
        headerEnd += 2; // Skip \n\n
      } else {
        print('[Multipart] ⚠️  Part $i: Could not find header end, skipping');
        continue;
      }
    } else {
      print('[Multipart] Found header end with \\r\\n\\r\\n at position: $headerEnd');
      headerEnd += 4; // Skip \r\n\r\n
    }
    
    if (headerEnd >= partEnd) {
      print('[Multipart] ⚠️  Part $i: Header end ($headerEnd) >= part end ($partEnd), skipping');
      continue;
    }
    
    // Extract the part content (skip trailing \r\n or \n)
    int contentEnd = partEnd;
    if (contentEnd > 1 && bodyBytes[contentEnd - 1] == 10) { // \n
      contentEnd--;
      if (contentEnd > 0 && bodyBytes[contentEnd - 1] == 13) { // \r
        contentEnd--;
      }
    }
    
    if (contentEnd > headerEnd) {
      final part = bodyBytes.sublist(headerEnd, contentEnd);
      print('[Multipart] Part $i extracted: ${part.length} bytes');
      
      if (part.length >= 4) {
        print('[Multipart] Part $i magic bytes: ${part.sublist(0, 4).map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')}');
      }
      
      // Check if this looks like image data (JPEG: FF D8, PNG: 89 50 4E 47)
      if (part.length >= 4) {
        if ((part[0] == 0xFF && part[1] == 0xD8) || // JPEG
            (part[0] == 0x89 && part[1] == 0x50 && part[2] == 0x4E && part[3] == 0x47)) { // PNG
          print('[Multipart] ✅ Found valid image data (JPEG or PNG)');
          return part;
        } else {
          print('[Multipart] ⚠️  Part $i: Found data but not JPEG/PNG signature');
        }
      }
      
      // If we found any part with data, return it
      if (part.isNotEmpty) {
        print('[Multipart] ⚠️  Returning part $i anyway (${part.length} bytes) despite no image signature');
        return part;
      }
    } else {
      print('[Multipart] ⚠️  Part $i: contentEnd ($contentEnd) <= headerEnd ($headerEnd), skipping');
    }
  }
  
  // If we couldn't parse multipart, return empty list
  print('[Multipart] ❌ No valid image parts found, returning empty');
  return [];
}

/// Helper function to search for a byte sequence within another
/// Returns the index of the first match, or -1 if not found
int _searchBytes(List<int> haystack, List<int> needle, [int startIdx = 0]) {
  if (needle.isEmpty) return -1;
  if (startIdx >= haystack.length) return -1;
  
  for (int i = startIdx; i <= haystack.length - needle.length; i++) {
    bool match = true;
    for (int j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) {
        match = false;
        break;
      }
    }
    if (match) return i;
  }
  
  return -1;
}
