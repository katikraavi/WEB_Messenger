import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:frontend/core/services/api_client.dart';
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
  final FirebaseStorage _storage;

  MediaUploadService({
    http.Client? httpClient,
    String? baseUrl,
    FirebaseStorage? storage,
  })
    : _httpClient = httpClient ?? http.Client(),
      _baseUrl = baseUrl ?? ApiClient.getBaseUrl(),
      _storage = storage ?? FirebaseStorage.instance;

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
  /// Uploads directly to Firebase Storage to avoid backend memory/disk pressure.
  Future<UploadedMedia> uploadMedia({
    required PickedMediaFile pickedMedia,
    required String token,
  }) async {
    try {
      // Web uses backend upload directly to avoid browser CORS dependency
      // on Firebase Storage bucket configuration.
      if (kIsWeb) {
        return _uploadMediaViaBackend(pickedMedia: pickedMedia, token: token);
      }

      // Validate before upload
      if (!pickedMedia.isValid) {
        throw Exception('Invalid media file');
      }


      if (Firebase.apps.isEmpty) {
        throw Exception('Firebase is not initialized');
      }

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

      final uploadId = Uuid().v4();
      final originalExt = pickedMedia.name.contains('.')
          ? pickedMedia.name.split('.').last.toLowerCase()
          : 'bin';
      final storagePath = 'chat_media/$uploadId.$originalExt';

      final metadata = SettableMetadata(
        contentType: pickedMedia.mimeType,
        customMetadata: {
          'originalName': pickedMedia.name,
          'uploadedVia': 'chat_media',
        },
      );

      final ref = _storage.ref().child(storagePath);

      UploadTask task;
      if (pickedMedia.bytes != null) {
        task = ref.putData(pickedMedia.bytes!, metadata);
      } else {
        if (pickedMedia.path.isEmpty) {
          throw Exception('Invalid media file path: ${pickedMedia.path}');
        }
        final file = File(pickedMedia.path);
        if (!await file.exists()) {
          throw Exception('Media file not found at ${pickedMedia.path}');
        }
        task = ref.putFile(file, metadata);
      }

      await task.timeout(
        const Duration(seconds: 180),
        onTimeout: () => throw TimeoutException(
          'Upload took too long (180 seconds). Please check your connection and try again.',
          const Duration(seconds: 180),
        ),
      );

      final downloadUrl = await ref.getDownloadURL();

      return UploadedMedia(
        id: uploadId,
        fileName: '$uploadId.$originalExt',
        mimeType: pickedMedia.mimeType,
        fileSizeBytes: pickedMedia.sizeBytes,
        filePath: downloadUrl,
        originalName: pickedMedia.name,
        createdAt: DateTime.now().toUtc(),
      );
    } catch (e) {
      // Web Firebase Storage may fail when bucket CORS is not configured yet.
      // Fallback to backend upload to keep messaging functional.
      if (kIsWeb) {
        return _uploadMediaViaBackend(pickedMedia: pickedMedia, token: token);
      }
      rethrow;
    }
  }

  Future<UploadedMedia> _uploadMediaViaBackend({
    required PickedMediaFile pickedMedia,
    required String token,
  }) async {
    final url = Uri.parse('$_baseUrl/api/media/upload');

    final mimeParts = pickedMedia.mimeType.split('/');
    final mediaType = http.MediaType(mimeParts[0], mimeParts[1]);

    final request = http.MultipartRequest('POST', url)
      ..headers.addAll({'Authorization': 'Bearer $token'})
      ..fields['mime_type'] = pickedMedia.mimeType
      ..fields['file_name'] = pickedMedia.name;

    if (pickedMedia.bytes != null) {
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
      if (pickedMedia.path.isEmpty) {
        throw Exception('Invalid media file path: ${pickedMedia.path}');
      }

      final file = File(pickedMedia.path);
      if (!await file.exists()) {
        throw Exception('Media file not found at ${pickedMedia.path}');
      }

      final fileLength = await file.length();
      request.files.add(
        http.MultipartFile(
          'file',
          file.openRead(),
          fileLength,
          filename: pickedMedia.name,
          contentType: mediaType,
        ),
      );
    }

    final response = await request.send().timeout(
      const Duration(seconds: 120),
      onTimeout: () => throw TimeoutException(
        'Upload took too long (120 seconds). Please check your connection and try again.',
        const Duration(seconds: 120),
      ),
    );

    final statusCode = response.statusCode;
    final responseBody = await response.stream.bytesToString();

    if (statusCode == 201) {
      final mediaData = jsonDecode(responseBody) as Map<String, dynamic>;
      return UploadedMedia.fromJson(mediaData);
    }

    if (statusCode == 413) {
      throw Exception('File too large (max 50MB)');
    }

    if (statusCode == 401) {
      throw Exception('Unauthorized: Invalid or expired token');
    }

    throw Exception('Upload failed: $statusCode');
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


      final response = await _httpClient.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Invalid or expired token');
      } else if (response.statusCode == 404) {
        throw Exception('Media not found');
      } else {
        throw Exception('Download failed: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }
}
