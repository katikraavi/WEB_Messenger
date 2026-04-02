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
/// - Media storage in database (persistent on Render)
/// - File retrieval
/// 
/// NOTE: Files are now stored in database instead of ephemeral filesystem
/// This ensures media persists on Render between container restarts
class MediaStorageService {
  final Connection connection;

  static const int maxFileSize = 10485760; // 10MB in bytes
  static const String _storageDirEnv = 'MEDIA_STORAGE_DIR';
  static const String _defaultStorageDir = '/app/backend/uploads/chat_media';
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

  static String _compactError(Object e) {
    final raw = e.toString();
    if (raw.length <= 400) return raw;
    return '${raw.substring(0, 400)}... [truncated]';
  }

  MediaStorageService({
    required this.connection,
  });

  Directory _ensureStorageDirectory() {
    final configured = Platform.environment[_storageDirEnv];
    final directoryPath =
        (configured != null && configured.trim().isNotEmpty)
        ? configured.trim()
        : _defaultStorageDir;
    final directory = Directory(directoryPath);
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    return directory;
  }

  String _resolveDiskPath(String fileName) {
    final mediaDir = _ensureStorageDirectory();
    return path.join(mediaDir.path, fileName);
  }

  String _defaultApiPathForId(String mediaId) => '/api/media/$mediaId/download';

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

  /// Upload media file to persistent disk with metadata in database (T068)
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
      final id = fileId; // Use same UUID for ID and filename
      final mediaPath = _defaultApiPathForId(id);
      final diskPath = _resolveDiskPath(safeFileName);

      // Write file bytes to persistent disk first.
      final mediaFile = File(diskPath);
      await mediaFile.writeAsBytes(fileBytes, flush: true);

      try {
        await connection.execute(
          '''
          INSERT INTO media_storage
          (id, uploader_id, file_name, mime_type, file_size_bytes, file_path, file_data, original_name, created_at)
          VALUES (@id, @uploaderId, @fileName, @mimeType, @fileSize, @filePath, decode('', 'hex')::bytea, @originalName, @createdAt)
          ''',
          substitutionValues: {
            'id': id,
            'uploaderId': uploaderId,
            'fileName': safeFileName,
            'mimeType': mimeType,
            'fileSize': fileBytes.length,
            'filePath': mediaPath,
            'originalName': fileName,
            'createdAt': DateTime.now().toIso8601String(),
          },
        );
      } catch (e) {
        // Local/older schemas may not include file_path column.
        if (e.toString().contains('column "file_path" of relation "media_storage" does not exist')) {
          await connection.execute(
            '''
            INSERT INTO media_storage
            (id, uploader_id, file_name, mime_type, file_size_bytes, file_data, original_name, created_at)
            VALUES (@id, @uploaderId, @fileName, @mimeType, @fileSize, decode('', 'hex')::bytea, @originalName, @createdAt)
            ''',
            substitutionValues: {
              'id': id,
              'uploaderId': uploaderId,
              'fileName': safeFileName,
              'mimeType': mimeType,
              'fileSize': fileBytes.length,
              'originalName': fileName,
              'createdAt': DateTime.now().toIso8601String(),
            },
          );
        } else {
          if (mediaFile.existsSync()) {
            await mediaFile.delete();
          }
          rethrow;
        }
      }

      print('[MediaStorageService] ✓ File uploaded to disk: $id by $uploaderId (${fileBytes.length} bytes)');

      return MediaFile(
        id: id,
        uploaderId: uploaderId,
        fileName: safeFileName,
        mimeType: mimeType,
        fileSizeBytes: fileBytes.length,
        filePath: mediaPath,
        originalName: fileName,
        createdAt: DateTime.now(),
      );
    } catch (e) {
      print('[MediaStorageService] ❌ Upload error: ${_compactError(e)}');
      throw Exception('Failed to upload file');
    }
  }

  /// Get media file by ID (T069)
  Future<MediaFile?> getMediaById(String mediaId) async {
    try {
      List<List<dynamic>> result;
      bool hasFilePath = true;
      try {
        result = await connection.query(
          '''
          SELECT id, uploader_id, file_name, mime_type, file_size_bytes, file_path, original_name, created_at
          FROM media_storage
          WHERE id = @mediaId
          ''',
          substitutionValues: {'mediaId': mediaId},
        );
      } catch (e) {
        if (!e.toString().contains('column "file_path"')) {
          rethrow;
        }
        hasFilePath = false;
        result = await connection.query(
          '''
          SELECT id, uploader_id, file_name, mime_type, file_size_bytes, original_name, created_at
          FROM media_storage
          WHERE id = @mediaId
          ''',
          substitutionValues: {'mediaId': mediaId},
        );
      }

      if (result.isEmpty) return null;

      final row = result.first;
      final createdAtValue = hasFilePath ? row[7] : row[6];
      final createdAt = createdAtValue is DateTime
          ? createdAtValue.toUtc()
          : DateTime.parse(createdAtValue.toString());
      final storedPath = hasFilePath ? row[5] as String? : null;
      final mediaPath =
          (storedPath != null && storedPath.trim().isNotEmpty)
          ? storedPath
          : _defaultApiPathForId(row[0] as String);
      return MediaFile(
        id: row[0] as String,
        uploaderId: row[1] as String,
        fileName: row[2] as String,
        mimeType: row[3] as String?,
        fileSizeBytes: row[4] as int,
        filePath: mediaPath,
        originalName: hasFilePath ? row[6] as String? : row[5] as String?,
        createdAt: createdAt,
      );
    } catch (e) {
      print('[MediaStorageService] ❌ Error getting media: $e');
      throw Exception('Failed to get media: $e');
    }
  }

  /// Download file bytes from disk (fallback to legacy DB blob rows)
  Future<Uint8List> downloadFile(String mediaId) async {
    try {
      final result = await connection.query(
        '''
        SELECT file_data, file_name
        FROM media_storage
        WHERE id = @mediaId
        ''',
        substitutionValues: {'mediaId': mediaId},
      );

      if (result.isEmpty) {
        throw ArgumentError('Media not found: $mediaId');
      }

      final row = result.first;
      final fileData = row[0];
      final fileName = row[1] as String;
      final diskFile = File(_resolveDiskPath(fileName));

      if (diskFile.existsSync()) {
        final bytes = await diskFile.readAsBytes();
        print('[MediaStorageService] ✓ Downloaded media $mediaId from disk (${bytes.length} bytes)');
        return bytes;
      }

      if (fileData is Uint8List && fileData.isNotEmpty) {
        print('[MediaStorageService] ✓ Downloaded legacy blob media $mediaId (${fileData.length} bytes)');
        return fileData;
      }
      if (fileData is List<int> && fileData.isNotEmpty) {
        print('[MediaStorageService] ✓ Downloaded legacy blob media $mediaId (${fileData.length} bytes)');
        return Uint8List.fromList(fileData);
      }

      throw Exception('Media file missing on disk and no legacy blob data found for: $mediaId');
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
      final file = File(_resolveDiskPath(media.fileName));
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
