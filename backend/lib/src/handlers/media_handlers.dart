import 'dart:convert';
import 'dart:typed_data';
import 'package:shelf/shelf.dart';
import 'package:postgres/postgres.dart';
import '../services/media_storage_service.dart';
import 'package:uuid/uuid.dart';

typedef Connection = PostgreSQLConnection;

/// Message Handlers for Media Operations (T070-T072)
class MediaHandlers {
  static const String _tableName = 'messages';
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

  static String? _getHeaderValue(Request request, String headerName) {
    final target = headerName.toLowerCase();
    for (final entry in request.headers.entries) {
      if (entry.key.toLowerCase() == target) {
        return entry.value;
      }
    }
    return null;
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
      final authHeader = _getHeaderValue(request, 'authorization');
      final token = authHeader?.replaceFirst('Bearer ', '');
      if (token == null || token.isEmpty) {
        return Response(401, body: jsonEncode({'error': 'Missing token'}));
      }

      // Extract user ID
      final userId = _extractUserIdFromToken(token);
      if (userId == null) {
        return Response(401, body: jsonEncode({'error': 'Invalid token'}));
      }

      // Parse request (expects multipart/form-data)
      final contentType = _getHeaderValue(request, 'content-type') ?? '';
      if (!contentType.contains('multipart/form-data')) {
        return Response(400,
            body: jsonEncode({'error': 'Expected multipart/form-data'}));
      }

      // Read raw bytes for multipart parsing
      final bodyBytes = await request.read().fold<BytesBuilder>(
        BytesBuilder(copy: false),
        (builder, chunk) {
          builder.add(chunk);
          return builder;
        },
      );
      final bodyBytesList = bodyBytes.takeBytes();

      // Parse multipart form data
      final boundaryMatch = RegExp(r'boundary=([^;]+)').firstMatch(contentType);
      if (boundaryMatch == null) {
        return Response(400, body: jsonEncode({'error': 'Invalid multipart format'}));
      }

      final boundary = boundaryMatch.group(1)!.trim();
      
      // Extract file bytes and metadata from multipart
      final result = _extractMultipartFile(bodyBytesList, boundary);
      if (result == null) {
        print('[MediaHandlers] ❌ Failed to extract file from multipart - no valid parts found');
        return Response(400, body: jsonEncode({'error': 'No file found in multipart data'}));
      }
      print('[MediaHandlers] ✓ Extracted file: ${result['fileName']} (${(result['fileBytes'] as List<int>).length} bytes)');

      final fileBytesList = result['fileBytes'] as List<int>;
      var fileName = result['fileName'] as String?;
      var mimeType = result['mimeType'] as String? ?? 'application/octet-stream';

      // Try headers as fallback
      fileName ??= _getHeaderValue(request, 'x-file-name') ?? 'upload_${DateTime.now().millisecondsSinceEpoch}';
      if (mimeType == 'application/octet-stream') {
        final headerMimeType = _getHeaderValue(request, 'x-file-type');
        if (headerMimeType != null) mimeType = headerMimeType;
      }

      if (fileBytesList.isEmpty) {
        return Response(400, body: jsonEncode({'error': 'No file data'}));
      }

      // Convert to Uint8List for upload service
      final fileBytes = Uint8List.fromList(fileBytesList);

      // Upload via service
      final mediaFile = await _mediaService.uploadFile(
        fileBytes: fileBytes,
        fileName: fileName,
        mimeType: mimeType,
        uploaderId: userId,
      );

      return Response(201,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(mediaFile.toJson()));
    } catch (e) {
      if (e.toString().contains('exceeds maximum')) {
        return Response(413, body: jsonEncode({'error': e.toString()}));
      }

      return Response(500,
          body: jsonEncode(
              {'error': 'Failed to upload media: ${e.toString()}'}));
    }
  }

  /// Extract file and metadata from multipart form data
  static Map<String, dynamic>? _extractMultipartFile(List<int> bodyBytes, String boundary) {
    try {
      final boundaryBytes = utf8.encode('--$boundary');
      
      // Find boundaries
      int startIdx = 0;
      final boundaries = <int>[];
      while ((startIdx = _searchBytes(bodyBytes, boundaryBytes, startIdx)) != -1) {
        boundaries.add(startIdx);
        startIdx += boundaryBytes.length;
      }

      if (boundaries.length < 2) {
        return null;
      }

      List<int>? fileBytes;
      String? fileName;
      String? mimeType;

      // Process all parts, looking for the file and metadata
      for (int i = 0; i < boundaries.length - 1; i++) {
        int partStart = boundaries[i] + boundaryBytes.length;
        
        // Skip CRLF or LF after boundary
        if (partStart < bodyBytes.length && bodyBytes[partStart] == 13) { // \r
          partStart++; // skip \r
        }
        if (partStart < bodyBytes.length && bodyBytes[partStart] == 10) { // \n
          partStart++; // skip \n
        }
        
        int partEnd = boundaries[i + 1];
        
        // Find header end (CRLF CRLF or LF LF)
        final headerEndCRLF = utf8.encode('\r\n\r\n');
        final headerEndLF = utf8.encode('\n\n');
        
        int headerEnd = _searchBytes(bodyBytes, headerEndCRLF, partStart);
        if (headerEnd == -1) {
          headerEnd = _searchBytes(bodyBytes, headerEndLF, partStart);
          if (headerEnd == -1) {
            continue;
          }
          headerEnd += 2;
        } else {
          headerEnd += 4;
        }

        if (headerEnd >= partEnd) {
          continue;
        }

        // Extract part content
        int contentEnd = partEnd;
        if (contentEnd > 0 && bodyBytes[contentEnd - 1] == 10) contentEnd--; // \n
        if (contentEnd > 0 && bodyBytes[contentEnd - 1] == 13) contentEnd--; // \r

        final headers = String.fromCharCodes(bodyBytes.sublist(partStart, headerEnd - 2));
        final bodyContent = bodyBytes.sublist(headerEnd, contentEnd);
        
        // Parse Content-Disposition header to get field name (case-insensitive)
        final dispositionMatch = RegExp(r'content-disposition:.*?name="([^"]*)"', caseSensitive: false).firstMatch(headers);
        final fieldName = dispositionMatch?.group(1);

        // Check if this is the file part (has filename)
        if (fieldName == 'file' && headers.contains('filename=')) {
          // Extract filename
          final filenameMatch = RegExp(r'filename="?([^"\r\n]*)"?').firstMatch(headers);
          fileName = filenameMatch?.group(1);
          
          // Try to get Content-Type from file part (case-insensitive)
          final contentTypeMatch = RegExp(r'content-type:\s*([^\r\n]+)', caseSensitive: false).firstMatch(headers);
          mimeType = contentTypeMatch?.group(1)?.trim();
          
          fileBytes = bodyContent;
        } 
        else if (fieldName == 'mime_type') {
          // Extract mime type from form field (fallback if not in file part)
          final uploadedMimeType = String.fromCharCodes(bodyContent).trim();
          if (mimeType == null || mimeType == 'application/octet-stream') {
            mimeType = uploadedMimeType;
          }
        } 
        else if (fieldName == 'file_name') {
          // Extract file name from form field - PREFER THIS over filename param
          final formFileName = String.fromCharCodes(bodyContent).trim();
          fileName = formFileName; // Always use form field if provided
        }
      }
      
      if (fileBytes != null && fileBytes.isNotEmpty) {
        return {
          'fileBytes': fileBytes,
          'fileName': fileName,
          'mimeType': mimeType,
        };
      }
    } catch (e) {
      print('[MediaHandlers] Error parsing multipart: $e');
    }
    
    return null;
  }

  /// Search for a sequence of bytes in a byte list
  static int _searchBytes(List<int> haystack, List<int> needle, int startPos) {
    if (needle.isEmpty || startPos >= haystack.length) return -1;
    
    for (int i = startPos; i <= haystack.length - needle.length; i++) {
      bool found = true;
      for (int j = 0; j < needle.length; j++) {
        if (haystack[i + j] != needle[j]) {
          found = false;
          break;
        }
      }
      if (found) return i;
    }
    return -1;
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
      final authHeader = _getHeaderValue(request, 'authorization');
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
      final authHeader = _getHeaderValue(request, 'authorization');
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
          'mediaUrl': '/uploads/media/${media.fileName}',
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
            'media_url': '/uploads/media/${media.fileName}',
          }));
    } catch (e) {
      print('[MediaHandlers] ❌ Attach media error: $e');
      return Response(500,
          body: jsonEncode(
              {'error': 'Failed to attach media: ${e.toString()}'}));
    }
  }
}
