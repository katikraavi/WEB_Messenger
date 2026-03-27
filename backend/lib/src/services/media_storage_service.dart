import 'dart:io';
import 'dart:typed_data';
import 'package:postgres/postgres.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;

typedef Connection = PostgreSQLConnection;

/// Media Storage Model
class MediaFile {
  final String id;
  final String uploaderId;
  final String fileName;
  final String? mimeType;
  final int fileSizeBytes;
  final String filePath;
  final String? originalName;
  final DateTime createdAt;

  MediaFile({
    required this.id,
    required this.uploaderId,
    required this.fileName,
    this.mimeType,
    required this.fileSizeBytes,
    required this.filePath,
    this.originalName,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'uploader_id': uploaderId,
    'file_name': fileName,
    'mime_type': mimeType,
    'file_size_bytes': fileSizeBytes,
    'file_path': filePath,
    'original_name': originalName,
    'created_at': createdAt.toIso8601String(),
  };

  static MediaFile fromJson(Map<String, dynamic> json) => MediaFile(
    id: json['id'] as String,
    uploaderId: json['uploader_id'] as String,
    fileName: json['file_name'] as String,
    mimeType: json['mime_type'] as String?,
    fileSizeBytes: json['file_size_bytes'] as int,
    filePath: json['file_path'] as String,
    originalName: json['original_name'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}

/// Media Storage Service (T067-T069)
/// 
/// Handles:
/// - File upload and validation
/// - Media compression
/// - Storage management
/// - File retrieval
class MediaStorageService {
  final Connection connection;
  final String uploadDir;
  
  static const int maxFileSize = 52428800; // 50MB in bytes
  static const List<String> allowedMimeTypes = [
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/gif',
    'video/mp4',
    'video/quicktime',
    'video/x-msvideo',
    'audio/wav',
    'audio/x-wav',
    'audio/mpeg',
    'audio/mp4',
    'audio/aac',
    'audio/x-m4a',
  ];

  MediaStorageService({
    required this.connection,
    this.uploadDir = './uploads/media',
  }) {
    _ensureUploadDirExists();
  }

  /// Ensure upload directory exists
  void _ensureUploadDirExists() {
    final dir = Directory(uploadDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
  }

  /// Validate file before upload (T067)
  /// 
  /// Checks:
  /// - File size <= 50MB
  /// - MIME type is allowed
  /// - File extension matches MIME type
  /// 
  /// Throws: ArgumentError if validation fails
  void validateFile(String fileName, int fileSize, String? mimeType) {
    if (fileSize > maxFileSize) {
      throw ArgumentError(
        'File size exceeds maximum of ${maxFileSize ~/ 1048576}MB '
        '(received: ${fileSize ~/ 1048576}MB)',
      );
    }

    if (mimeType == null || !allowedMimeTypes.contains(mimeType)) {
      throw ArgumentError(
        'File type not supported. Allowed types: ${allowedMimeTypes.join(", ")}',
      );
    }

    // Validate file extension matches MIME type
    final ext = path.extension(fileName).toLowerCase();
    _validateExtension(ext, mimeType);
  }

  /// Validate file extension matches MIME type (T067)
  void _validateExtension(String ext, String mimeType) {
    final validExtensions = {
      'image/jpeg': ['.jpg', '.jpeg'],
      'image/png': ['.png'],
      'image/webp': ['.webp'],
      'image/gif': ['.gif'],
      'video/mp4': ['.mp4'],
      'video/quicktime': ['.mov'],
      'video/x-msvideo': ['.avi'],
      'audio/wav': ['.wav'],
      'audio/x-wav': ['.wav'],
      'audio/mpeg': ['.mp3'],
      'audio/mp4': ['.m4a', '.mp4'],
      'audio/aac': ['.aac'],
      'audio/x-m4a': ['.m4a'],
    };

    final allowed = validExtensions[mimeType] ?? [];
    if (!allowed.contains(ext)) {
      throw ArgumentError(
        'File extension $ext does not match MIME type $mimeType',
      );
    }
  }

  /// Upload media file (T068)
  /// 
  /// Parameters:
  /// - fileBytes: Raw file data
  /// - fileName: Original file name
  /// - mimeType: MIME type of file
  /// - uploaderId: UUID of user uploading
  /// 
  /// Returns: MediaFile with storage info
  /// 
  /// Throws: ArgumentError if validation fails, Exception if storage fails
  Future<MediaFile> uploadFile({
    required Uint8List fileBytes,
    required String fileName,
    required String mimeType,
    required String uploaderId,
  }) async {
    try {
      // Validate file
      validateFile(fileName, fileBytes.length, mimeType);

      // Generate safe file name with UUID prefix
      final fileId = Uuid().v4();
      final ext = path.extension(fileName);
      final safeFileName = '$fileId$ext';
      final filePath = '$uploadDir/$safeFileName';

      // Write file to disk
      final file = File(filePath);
      await file.writeAsBytes(fileBytes);

      // Store metadata in database
      final mediaId = Uuid();
      final id = mediaId.v4();

      await connection.execute(
        '''
        INSERT INTO media_storage
        (id, uploader_id, file_name, mime_type, file_size_bytes, file_path, original_name)
        VALUES (@id, @uploaderId, @fileName, @mimeType, @fileSize, @filePath, @originalName)
        ''',
        substitutionValues: {
          'id': id,
          'uploaderId': uploaderId,
          'fileName': safeFileName,
          'mimeType': mimeType,
          'fileSize': fileBytes.length,
          'filePath': filePath,
          'originalName': fileName,
        },
      );

      print('[MediaStorageService] ✓ File uploaded: $id by $uploaderId');

      return MediaFile(
        id: id,
        uploaderId: uploaderId,
        fileName: safeFileName,
        mimeType: mimeType,
        fileSizeBytes: fileBytes.length,
        filePath: filePath,
        originalName: fileName,
        createdAt: DateTime.now(),
      );
    } catch (e) {
      print('[MediaStorageService] ❌ Upload error: $e');
      throw Exception('Failed to upload file: $e');
    }
  }

  /// Get media file by ID (T069)
  Future<MediaFile?> getMediaById(String mediaId) async {
    try {
      final result = await connection.query(
        '''
        SELECT id, uploader_id, file_name, mime_type, file_size_bytes, file_path, original_name, created_at
        FROM media_storage
        WHERE id = @mediaId
        ''',
        substitutionValues: {'mediaId': mediaId},
      );

      if (result.isEmpty) return null;

      final row = result.first;
      return MediaFile(
        id: row[0] as String,
        uploaderId: row[1] as String,
        fileName: row[2] as String,
        mimeType: row[3] as String?,
        fileSizeBytes: row[4] as int,
        filePath: row[5] as String,
        originalName: row[6] as String?,
        createdAt: row[7] as DateTime,
      );
    } catch (e) {
      print('[MediaStorageService] ❌ Error getting media: $e');
      throw Exception('Failed to get media: $e');
    }
  }

  /// Download file bytes from storage
  Future<Uint8List> downloadFile(String mediaId) async {
    try {
      final media = await getMediaById(mediaId);
      if (media == null) {
        throw ArgumentError('Media not found: $mediaId');
      }

      final file = File(media.filePath);
      if (!file.existsSync()) {
        throw Exception('File not found on disk: ${media.filePath}');
      }

      return await file.readAsBytes();
    } catch (e) {
      print('[MediaStorageService] ❌ Download error: $e');
      rethrow;
    }
  }

  /// Delete media file (hard delete) (T069)
  Future<bool> deleteMedia(String mediaId, String requestingUserId) async {
    try {
      final media = await getMediaById(mediaId);
      if (media == null) {
        throw ArgumentError('Media not found: $mediaId');
      }

      // Verify uploader
      if (media.uploaderId != requestingUserId) {
        throw ArgumentError(
          'Only the uploader can delete media',
        );
      }

      // Delete from database
      await connection.execute(
        'DELETE FROM media_storage WHERE id = @mediaId',
        substitutionValues: {'mediaId': mediaId},
      );

      // Delete from disk
      final file = File(media.filePath);
      if (file.existsSync()) {
        await file.delete();
      }

      print('[MediaStorageService] ✓ Media deleted: $mediaId');
      return true;
    } catch (e) {
      print('[MediaStorageService] ❌ Delete error: $e');
      throw Exception('Failed to delete media: $e');
    }
  }
}
