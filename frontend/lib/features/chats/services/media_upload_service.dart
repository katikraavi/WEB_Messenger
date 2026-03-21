import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'media_picker_service.dart';

/// Media Upload Service Model
class UploadedMedia {
  final String id;
  final String fileName;
  final String mimeType;
  final int fileSizeBytes;
  final String filePath;
  final String? originalName;
  final DateTime createdAt;

  UploadedMedia({
    required this.id,
    required this.fileName,
    required this.mimeType,
    required this.fileSizeBytes,
    required this.filePath,
    this.originalName,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'file_name': fileName,
    'mime_type': mimeType,
    'file_size_bytes': fileSizeBytes,
    'file_path': filePath,
    'original_name': originalName,
    'created_at': createdAt.toIso8601String(),
  };

  static UploadedMedia fromJson(Map<String, dynamic> json) {
    // Validate all required fields before parsing
    final id = json['id'] as String?;
    final fileName = json['file_name'] as String?;
    final mimeType = json['mime_type'] as String?;
    final fileSizeBytes = json['file_size_bytes'] as int?;
    final filePath = json['file_path'] as String?;
    final createdAtStr = json['created_at'] as String?;

    if (id == null || id.isEmpty) {
      throw Exception('Invalid response: missing or empty id field');
    }
    if (fileName == null || fileName.isEmpty) {
      throw Exception('Invalid response: missing or empty file_name field');
    }
    if (mimeType == null || mimeType.isEmpty) {
      throw Exception('Invalid response: missing or empty mime_type field');
    }
    if (fileSizeBytes == null) {
      throw Exception('Invalid response: missing file_size_bytes field');
    }
    if (filePath == null || filePath.isEmpty) {
      throw Exception('Invalid response: missing or empty file_path field');
    }
    if (createdAtStr == null || createdAtStr.isEmpty) {
      throw Exception('Invalid response: missing or empty created_at field');
    }

    return UploadedMedia(
      id: id,
      fileName: fileName,
      mimeType: mimeType,
      fileSizeBytes: fileSizeBytes,
      filePath: filePath,
      originalName: json['original_name'] as String?,
      createdAt: DateTime.parse(createdAtStr),
    );
  }
}

/// Media Upload Service (T074)
///
/// Handles uploading picked media files to the backend
class MediaUploadService {
  final http.Client _httpClient;
  final String _baseUrl;

  MediaUploadService({http.Client? httpClient, String? baseUrl})
    : _httpClient = httpClient ?? http.Client(),
      _baseUrl = baseUrl ?? 'http://localhost:8081';

  /// Upload media file (T074)
  ///
  /// Parameters:
  /// - pickedMedia: Media file picked from device
  /// - token: JWT authentication token
  ///
  /// Returns: UploadedMedia with server metadata
  ///
  /// Throws: Exception if upload fails
  ///
  /// Note: Videos are streamed from disk to avoid loading entire file into memory
  Future<UploadedMedia> uploadMedia({
    required PickedMediaFile pickedMedia,
    required String token,
  }) async {
    try {
      // Validate before upload
      if (!pickedMedia.isValid) {
        throw Exception('Invalid media file');
      }

      debugPrint(
        '[MediaUploadService] Uploading ${pickedMedia.mimeType}: ${pickedMedia.sizeBytes ~/ 1024}KB',
      );

      final url = Uri.parse('$_baseUrl/api/media/upload');
      late int statusCode;
      late String responseBody;

      // Validate MIME type format for both image and video
      if (pickedMedia.mimeType.isEmpty) {
        throw Exception('MIME type is empty');
      }
      final mimeParts = pickedMedia.mimeType.split('/');
      if (mimeParts.length != 2) {
        throw Exception(
          'Invalid MIME type format: ${pickedMedia.mimeType}. Expected format: type/subtype',
        );
      }
      if (mimeParts[0].isEmpty || mimeParts[1].isEmpty) {
        throw Exception(
          'Invalid MIME type parts: ${pickedMedia.mimeType}. Parts cannot be empty',
        );
      }

      final mediaType = http.MediaType(mimeParts[0], mimeParts[1]);

      // Both image and video uploads use multipart/form-data
      final request = http.MultipartRequest('POST', url)
        ..headers.addAll({'Authorization': 'Bearer $token'})
        ..fields['mime_type'] = pickedMedia.mimeType
        ..fields['file_name'] = pickedMedia.name;

      if (pickedMedia.bytes != null) {
        // Image upload: add bytes directly
        request.files.add(
          http.MultipartFile(
            'file',
            Stream.value(pickedMedia.bytes!),
            pickedMedia.bytes!.length,
            filename: pickedMedia.name,
            contentType: mediaType,
          ),
        );
      } else {
        // Video upload: stream from file
        if (pickedMedia.path.isEmpty) {
          throw Exception('Invalid video file path: ${pickedMedia.path}');
        }

        final file = File(pickedMedia.path);

        if (!await file.exists()) {
          throw Exception('Video file not found at ${pickedMedia.path}');
        }

        debugPrint(
          '[MediaUploadService] Streaming video from: ${pickedMedia.path}',
        );

        final fileLength = await file.length();
        final fileStream = file.openRead();

        request.files.add(
          http.MultipartFile(
            'file',
            fileStream,
            fileLength,
            filename: pickedMedia.name,
            contentType: mediaType,
          ),
        );
      }

      try {
        final response = await request.send();
        statusCode = response.statusCode;
        responseBody = await response.stream.bytesToString();
      } catch (e) {
        debugPrint('[MediaUploadService] Upload stream error: $e');
        rethrow;
      }

      if (statusCode == 201) {
        try {
          final mediaData = jsonDecode(responseBody) as Map<String, dynamic>;
          final uploadedMedia = UploadedMedia.fromJson(mediaData);
          debugPrint(
            '[MediaUploadService] Upload successful: ${uploadedMedia.id}',
          );
          return uploadedMedia;
        } catch (parseError) {
          debugPrint(
            '[MediaUploadService] Response parsing error: $parseError',
          );
          debugPrint('[MediaUploadService] Response body: $responseBody');
          throw Exception('Server returned invalid response: $parseError');
        }
      } else if (statusCode == 413) {
        throw Exception('File too large (max 50MB)');
      } else if (statusCode == 401) {
        throw Exception('Unauthorized: Invalid or expired token');
      } else if (statusCode >= 400) {
        try {
          final error = jsonDecode(responseBody) as Map<String, dynamic>;
          throw Exception('Upload failed: ${error['error']}');
        } catch (e) {
          throw Exception('Upload failed: $statusCode');
        }
      } else {
        throw Exception('Upload failed: $statusCode');
      }
    } catch (e) {
      debugPrint('[MediaUploadService] Upload error: $e');
      rethrow;
    }
  }

  /// Attach uploaded media to message (T075)
  ///
  /// Links an already-uploaded media file to a message
  ///
  /// Parameters:
  /// - messageId: Message to attach media to
  /// - mediaId: ID of uploaded media file
  /// - token: JWT authentication token
  ///
  /// Returns: Attachment metadata
  Future<Map<String, dynamic>> attachMediaToMessage({
    required String messageId,
    required String mediaId,
    required String token,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/api/messages/$messageId/attach-media');

      final response = await _httpClient.put(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'media_id': mediaId}),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint(
          '[MediaUploadService] Media attached to message: $messageId',
        );
        return result;
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Invalid or expired token');
      } else if (response.statusCode == 403) {
        throw Exception('Forbidden: You can only attach to your own messages');
      } else if (response.statusCode == 404) {
        throw Exception('Message or media not found');
      } else {
        throw Exception('Failed to attach media: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[MediaUploadService] Attach error: $e');
      rethrow;
    }
  }

  /// Download media file (T076)
  ///
  /// Parameters:
  /// - mediaId: ID of media to download
  /// - token: JWT authentication token
  ///
  /// Returns: File bytes
  Future<Uint8List> downloadMedia({
    required String mediaId,
    required String token,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/api/media/$mediaId/download');

      debugPrint('[MediaUploadService] Downloading media: $mediaId');

      final response = await _httpClient.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        debugPrint('[MediaUploadService] Download complete: $mediaId');
        return response.bodyBytes;
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Invalid or expired token');
      } else if (response.statusCode == 404) {
        throw Exception('Media not found');
      } else {
        throw Exception('Download failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[MediaUploadService] Download error: $e');
      rethrow;
    }
  }
}
