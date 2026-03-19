import 'dart:convert';
import 'dart:typed_data';
import 'package:shelf/shelf.dart';
import 'package:postgres/postgres.dart';
import '../services/media_storage_service.dart';
import 'package:uuid/uuid.dart';

typedef Connection = PostgreSQLConnection;

/// Message Handlers for Media Operations (T070-T072)
class MediaHandlers {
  static const String _tableName = 'message';
  static late MediaStorageService _mediaService;

  /// Initialize media service (call once on server startup)
  static void initialize(Connection connection) {
    _mediaService = MediaStorageService(connection: connection);
  }

  /// Extract user ID from JWT token
  static String? _extractUserIdFromToken(String token) {
    try {
      // MVP: Simple token parsing (production uses jwt package)
      final parts = token.split('.');
      if (parts.length != 3) return null;

      // Decode payload
      final payload = base64Url.decode(
        parts[1].padRight(parts[1].length + (4 - parts[1].length % 4) % 4, '='),
      );

      final decoded = jsonDecode(utf8.decode(payload)) as Map<String, dynamic>;
      return decoded['user_id'] as String?;
    } catch (e) {
      print('[MediaHandlers] Error extracting user ID: $e');
      return null;
    }
  }

  /// Upload media file (T070)
  /// 
  /// Endpoint: POST /api/media/upload
  /// Body: Multipart form with 'file' field
  /// 
  /// Responses:
  /// - 201: Media uploaded successfully, returns MediaFile
  /// - 400: Invalid file, missing fields
  /// - 401: Unauthorized
  /// - 413: File too large
  /// - 500: Server error
  static Future<Response> uploadMedia(
    Request request,
    Connection connection,
  ) async {
    try {
      // Get JWT token
      final authHeader = request.headers['Authorization'];
      final token = authHeader?.replaceFirst('Bearer ', '');
      if (token == null || token.isEmpty) {
        return Response(401, body: jsonEncode({'error': 'Missing token'}));
      }

      // Extract user ID
      final userId = _extractUserIdFromToken(token);
      if (userId == null) {
        return Response(401, body: jsonEncode({'error': 'Invalid token'}));
      }

      // Parse request (accepts both multipart/form-data and application/octet-stream)
      final contentType = request.headers['Content-Type'] ?? '';
      if (!contentType.contains('multipart/form-data') && 
          !contentType.contains('application/octet-stream')) {
        return Response(400,
            body: jsonEncode({'error': 'Expected multipart/form-data or application/octet-stream'}));
      }

      // For now, read raw bytes and extract metadata from headers
      // In production, use http_parser package for proper multipart handling
      final bodyBytes = await request.read().toList();
      final fileBytes = bodyBytes.isNotEmpty 
        ? Uint8List.fromList(bodyBytes[0] as List<int>)
        : Uint8List(0);

      // Get MIME type from Content-Type header
      final fileMimeType = request.headers['X-File-Type'] ?? 'application/octet-stream';
      final fileName = request.headers['X-File-Name'] ?? 'upload_${DateTime.now().millisecondsSinceEpoch}';

      if (fileBytes.isEmpty) {
        return Response(400, body: jsonEncode({'error': 'No file data'}));
      }

      // Upload via service
      final mediaFile = await _mediaService.uploadFile(
        fileBytes: fileBytes,
        fileName: fileName,
        mimeType: fileMimeType,
        uploaderId: userId,
      );

      print('[MediaHandlers] ✓ Media uploaded: ${mediaFile.id} by $userId');

      return Response(201,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(mediaFile.toJson()));
    } catch (e) {
      print('[MediaHandlers] ❌ Upload error: $e');

      if (e.toString().contains('exceeds maximum')) {
        return Response(413, body: jsonEncode({'error': e.toString()}));
      }

      return Response(500,
          body: jsonEncode(
              {'error': 'Failed to upload media: ${e.toString()}'}));
    }
  }

  /// Download media file (T071)
  /// 
  /// Endpoint: GET /api/media/{mediaId}/download
  /// 
  /// Responses:
  /// - 200: File bytes with appropriate Content-Type
  /// - 401: Unauthorized
  /// - 404: Media not found
  /// - 500: Server error
  static Future<Response> downloadMedia(
    Request request,
    String mediaId,
  ) async {
    try {
      // Get JWT token
      final authHeader = request.headers['Authorization'];
      final token = authHeader?.replaceFirst('Bearer ', '');
      if (token == null || token.isEmpty) {
        return Response(401, body: jsonEncode({'error': 'Missing token'}));
      }

      // Extract user ID (for audit logging)
      final userId = _extractUserIdFromToken(token);
      if (userId == null) {
        return Response(401, body: jsonEncode({'error': 'Invalid token'}));
      }

      // Get media metadata
      final media = await _mediaService.getMediaById(mediaId);
      if (media == null) {
        return Response(404, body: jsonEncode({'error': 'Media not found'}));
      }

      // Download file bytes
      final fileBytes = await _mediaService.downloadFile(mediaId);

      print('[MediaHandlers] ✓ Media downloaded: $mediaId by $userId');

      return Response(200,
          headers: {
            'Content-Type': media.mimeType ?? 'application/octet-stream',
            'Content-Disposition':
                'attachment; filename="${media.originalName ?? media.fileName}"',
          },
          body: fileBytes);
    } catch (e) {
      print('[MediaHandlers] ❌ Download error: $e');
      return Response(500,
          body: jsonEncode(
              {'error': 'Failed to download media: ${e.toString()}'}));
    }
  }

  /// Attach media to message (T072)
  /// 
  /// Updates a message to include a media file
  /// 
  /// Endpoint: PUT /api/messages/{messageId}/attach-media
  /// Body: { media_id: string }
  /// 
  /// Responses:
  /// - 200: Media attached, returns updated message
  /// - 400: Invalid media or message
  /// - 401: Unauthorized
  /// - 403: Not message sender
  /// - 404: Message or media not found
  /// - 500: Server error
  static Future<Response> attachMediaToMessage(
    Request request,
    String messageId,
    Connection connection,
  ) async {
    try {
      // Get JWT token
      final authHeader = request.headers['Authorization'];
      final token = authHeader?.replaceFirst('Bearer ', '');
      if (token == null || token.isEmpty) {
        return Response(401, body: jsonEncode({'error': 'Missing token'}));
      }

      // Extract user ID
      final userId = _extractUserIdFromToken(token);
      if (userId == null) {
        return Response(401, body: jsonEncode({'error': 'Invalid token'}));
      }

      // Parse request body
      final bodyString = await request.readAsString();
      final bodyJson = jsonDecode(bodyString) as Map<String, dynamic>;
      final mediaId = bodyJson['media_id'] as String?;

      if (mediaId == null || mediaId.isEmpty) {
        return Response(400,
            body: jsonEncode({'error': 'Missing media_id'}));
      }

      // Verify message exists and user is sender
      final msgResult = await connection.query(
        'SELECT sender_id FROM $_tableName WHERE id = @messageId',
        substitutionValues: {'messageId': messageId},
      );

      if (msgResult.isEmpty) {
        return Response(404,
            body: jsonEncode({'error': 'Message not found'}));
      }

      final senderId = msgResult.first[0] as String;
      if (senderId != userId) {
        return Response(403,
            body: jsonEncode({'error': 'Not the message sender'}));
      }

      // Verify media exists
      final media = await _mediaService.getMediaById(mediaId);
      if (media == null) {
        return Response(404,
            body: jsonEncode({'error': 'Media not found'}));
      }

      // Update message with media info
      await connection.execute(
        '''
        UPDATE $_tableName
        SET media_url = @mediaUrl, media_type = @mediaType
        WHERE id = @messageId
        ''',
        substitutionValues: {
          'messageId': messageId,
          'mediaUrl': '/api/media/$mediaId/download',
          'mediaType': media.mimeType,
        },
      );

      print(
          '[MediaHandlers] ✓ Media attached to message: $messageId by $userId');

      return Response(200,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'message_id': messageId,
            'media_id': mediaId,
            'media_type': media.mimeType,
            'media_url': '/api/media/$mediaId/download',
          }));
    } catch (e) {
      print('[MediaHandlers] ❌ Attach media error: $e');
      return Response(500,
          body: jsonEncode(
              {'error': 'Failed to attach media: ${e.toString()}'}));
    }
  }
}
