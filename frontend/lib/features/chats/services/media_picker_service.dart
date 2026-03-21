import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart' as img;

/// Media File Model
class PickedMediaFile {
  final String name;
  final String path;
  final Uint8List? bytes; // Optional for videos (streaming instead)
  final String mimeType;
  final int sizeBytes;

  PickedMediaFile({
    required this.name,
    required this.path,
    this.bytes,
    required this.mimeType,
    required this.sizeBytes,
  });

  bool get isImage => mimeType.startsWith('image/');
  bool get isVideo => mimeType.startsWith('video/');
  bool get isAudio => mimeType.startsWith('audio/');
  bool get isValid => sizeBytes > 0 && sizeBytes <= 52428800; // 50MB
}

/// Media Picker Service (T073)
///
/// Handles selecting images and videos from device
class MediaPickerService {
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

  static final _picker = img.ImagePicker();

  /// Pick an image from device
  ///
  /// Returns: PickedMediaFile or null if cancelled
  static Future<PickedMediaFile?> pickImage() async {
    try {
      final image = await _picker.pickImage(source: img.ImageSource.gallery);
      if (image == null) return null;

      final bytes = await image.readAsBytes();
      final fileName = image.name;

      // Determine MIME type from extension
      final mimeType = _getMimeTypeFromName(fileName);

      if (!allowedMimeTypes.contains(mimeType)) {
        throw Exception('Image type not supported: $mimeType');
      }

      if (bytes.length > maxFileSize) {
        throw Exception(
          'Image too large: ${bytes.length ~/ 1048576}MB (max 50MB)',
        );
      }

      return PickedMediaFile(
        name: fileName,
        path: image.path,
        bytes: bytes,
        mimeType: mimeType,
        sizeBytes: bytes.length,
      );
    } catch (e) {
      debugPrint('[MediaPickerService] Error picking image: $e');
      rethrow;
    }
  }

  /// Pick a video from device
  ///
  /// Returns: PickedMediaFile or null if cancelled
  /// Note: Video bytes are NOT loaded into memory. Only path and size are stored.
  /// Video upload uses streaming to handle large files efficiently.
  static Future<PickedMediaFile?> pickVideo() async {
    try {
      final video = await _picker.pickVideo(source: img.ImageSource.gallery);
      if (video == null) return null;

      final fileName = video.name;

      // Determine MIME type from extension
      final mimeType = _getMimeTypeFromName(fileName);

      if (!allowedMimeTypes.contains(mimeType)) {
        throw Exception('Video type not supported: $mimeType');
      }

      // Get file size without loading into memory
      final file = File(video.path);
      final fileSizeBytes = await file.length();

      if (fileSizeBytes > maxFileSize) {
        throw Exception(
          'Video too large: ${fileSizeBytes ~/ 1048576}MB (max 50MB)',
        );
      }

      debugPrint(
        '[MediaPickerService] Picked video: $fileName (${fileSizeBytes ~/ 1048576}MB)',
      );

      // For videos, bytes is null - we'll stream during upload
      return PickedMediaFile(
        name: fileName,
        path: video.path,
        bytes: null,
        mimeType: mimeType,
        sizeBytes: fileSizeBytes,
      );
    } catch (e) {
      debugPrint('[MediaPickerService] Error picking video: $e');
      rethrow;
    }
  }

  /// Pick either image or video
  static Future<PickedMediaFile?> pickMedia() async {
    try {
      final result = await _picker.pickImage(source: img.ImageSource.gallery);
      if (result == null) return null;

      final bytes = await result.readAsBytes();
      final fileName = result.name;
      final mimeType = _getMimeTypeFromName(fileName);

      if (!allowedMimeTypes.contains(mimeType)) {
        throw Exception('Media type not supported: $mimeType');
      }

      if (bytes.length > maxFileSize) {
        throw Exception(
          'File too large: ${bytes.length ~/ 1048576}MB (max 50MB)',
        );
      }

      return PickedMediaFile(
        name: fileName,
        path: result.path,
        bytes: bytes,
        mimeType: mimeType,
        sizeBytes: bytes.length,
      );
    } catch (e) {
      debugPrint('[MediaPickerService] Error picking media: $e');
      rethrow;
    }
  }

  /// Get MIME type from file name
  static String _getMimeTypeFromName(String fileName) {
    final ext = fileName.toLowerCase().split('.').last;
    final mimeMap = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'webp': 'image/webp',
      'gif': 'image/gif',
      'mp4': 'video/mp4',
      'mov': 'video/quicktime',
      'avi': 'video/x-msvideo',
      'wav': 'audio/wav',
      'mp3': 'audio/mpeg',
      'm4a': 'audio/x-m4a',
      'aac': 'audio/aac',
    };
    return mimeMap[ext] ?? 'application/octet-stream';
  }
}
