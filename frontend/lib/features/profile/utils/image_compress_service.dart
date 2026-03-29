import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../utils/profile_logger.dart';

/// Image Compression Service
/// 
/// Provides intelligent image compression to reduce file size while maintaining quality.
/// Used when images exceed size limits to allow upload without user intervention.
/// 
/// Compression strategy:
/// - Step 1: Try compression at 85% quality
/// - Step 2: If still too large, resize to 75% dimensions + 80% quality
/// - Step 3: If still too large, resize to 50% dimensions + 75% quality
/// - Stops when file is under 5MB or quality becomes too poor
class ImageCompressionService {
  static const int targetFileSize = 5242880; // 5MB target
  static const int maxDimension = 4000; // Max pixel dimension to avoid huge files
  static const List<int> qualityLevels = [90, 85, 80, 75, 70];

  /// Compress image bytes to target file size
  /// 
  /// Intelligently reduces image quality and dimensions to reach target size.
  /// Returns compressed bytes or original if already under target size.
  static Future<Uint8List> compressImage({
    required Uint8List imageBytes,
    required String filename,
    int targetSize = targetFileSize,
  }) async {
    try {
      ProfileLogger.logStateChange(
        'compression',
        'Start: ${imageBytes.length ~/ 1048576}MB to fit in ${targetSize ~/ 1048576}MB',
      );

      // If already under target, return as-is
      if (imageBytes.length <= targetSize) {
        ProfileLogger.logStateChange('compression', 'Already under target size');
        return imageBytes;
      }

      // Decode image
      final image = img.decodeImage(imageBytes);
      if (image == null) {
        ProfileLogger.logError('compression', 'Failed to decode image for compression');
        return imageBytes;
      }

      Uint8List? bestCompressionBytes;
      int bestSize = imageBytes.length;

      // Strategy 1: Try quality compression only (no resize)
      for (final quality in qualityLevels) {
        final compressed = img.encodeJpg(image, quality: quality);
        if (compressed.length <= targetSize) {
          bestCompressionBytes = compressed;
          bestSize = compressed.length;
          final originalMB = imageBytes.length / 1048576;
          final compressedMB = bestSize / 1048576;
          ProfileLogger.logStateChange(
            'compression',
            'Quality-only: $originalMB → $compressedMB MB (Q$quality)',
          );
          return bestCompressionBytes;
        }
        if (compressed.length < bestSize) {
          bestCompressionBytes = compressed;
          bestSize = compressed.length;
        }
      }

      // Strategy 2: Resize + quality compression
      var resizeScale = 0.9;
      while (resizeScale >= 0.3 && bestSize > targetSize) {
        final newWidth = (image.width * resizeScale).toInt();
        final newHeight = (image.height * resizeScale).toInt();
        
        if (newWidth < 100 || newHeight < 100) break;

        final resized = img.copyResize(
          image,
          width: newWidth,
          height: newHeight,
          interpolation: img.Interpolation.linear,
        );

        for (final quality in qualityLevels) {
          final compressed = img.encodeJpg(resized, quality: quality);
          if (compressed.length <= targetSize) {
            bestCompressionBytes = compressed;
            bestSize = compressed.length;
            final originalMB = imageBytes.length / 1048576;
            final compressedMB = bestSize / 1048576;
            final scale = (resizeScale * 100).toStringAsFixed(0);
            ProfileLogger.logStateChange(
              'compression',
              'Resize+Quality: $originalMB → $compressedMB MB (${scale}% size, Q$quality)',
            );
            return bestCompressionBytes;
          }
          if (compressed.length < bestSize) {
            bestCompressionBytes = compressed;
            bestSize = compressed.length;
          }
        }

        resizeScale -= 0.1;
      }

      // If we have any compressed version better than original, use it
      if (bestCompressionBytes != null && bestSize < imageBytes.length) {
        final originalMB = imageBytes.length / 1048576;
        final compressedMB = bestSize / 1048576;
        ProfileLogger.logStateChange(
          'compression',
          'Final: $originalMB → $compressedMB MB (${((1 - bestSize / imageBytes.length) * 100).toStringAsFixed(1)}% reduction)',
        );
        return bestCompressionBytes;
      }

      // If compression didn't help much, return original
      ProfileLogger.logStateChange(
        'compression',
        'Could not compress below target - returning best available',
      );
      return bestCompressionBytes ?? imageBytes;
    } catch (e) {
      ProfileLogger.logError('compression', 'Error during compression: $e');
      return imageBytes;
    }
  }

  /// Get compression ratio as percentage
  static double getCompressionRatio(int originalSize, int compressedSize) {
    if (originalSize == 0) return 0;
    return ((originalSize - compressedSize) / originalSize * 100);
  }

  /// Format bytes to human-readable size
  static String formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }
}
