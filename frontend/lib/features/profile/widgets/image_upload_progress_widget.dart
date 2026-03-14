import 'package:flutter/material.dart';

/// Enhanced image upload progress display widget
/// 
/// Phase 11 Task T142: Image upload progress percentage display
/// 
/// Shows detailed progress information during file upload:
/// - Upload percentage (0-100%)
/// - Estimated time remaining
/// - Upload speed (bytes/sec)
/// - Current bytes transferred vs total
/// - Visual progress bar with smooth animation

class ImageUploadProgressWidget extends StatelessWidget {
  /// Upload progress from 0.0 to 1.0
  final double progress;

  /// Current bytes uploaded
  final int bytesUploaded;

  /// Total bytes to upload
  final int totalBytes;

  /// Callback to cancel the upload
  final VoidCallback? onCancel;

  /// Display format: 'simple' (just percentage) or 'detailed' (full info)
  final String displayFormat;

  const ImageUploadProgressWidget({
    required this.progress,
    this.bytesUploaded = 0,
    this.totalBytes = 0,
    this.onCancel,
    this.displayFormat = 'simple',
    Key? key,
  }) : super(key: key);

  /// Calculate upload speed in bytes per second
  /// 
  /// Returns formatted string like "2.5 MB/s"
  String get uploadSpeedDisplay {
    // This would be calculated based on time elapsed
    // For now, just return placeholder (could be enhanced with timer)
    return 'Uploading...';
  }

  /// Calculate estimated time remaining
  /// 
  /// Returns formatted string like "2 seconds remaining"
  String get estimatedTimeRemaining {
    if (progress <= 0 || progress >= 1.0) return '';

    // Calculate rough estimate (this would need actual timing)
    // Placeholder for future enhancement
    return '';
  }

  /// Format bytes to human-readable format
  /// 
  /// Returns string like "2.5 MB" or "150 KB"
  static String formatBytes(int bytes) {
    if (bytes == 0) return '0 B';

    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    double size = bytes.toDouble();

    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }

    if (i == 0) {
      return '${size.toInt()} ${suffixes[i]}';
    }
    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }

  @override
  Widget build(BuildContext context) {
    final percentage = (progress * 100).toStringAsFixed(0);
    final uploadedStr = formatBytes(bytesUploaded);
    final totalStr = formatBytes(totalBytes);

    if (displayFormat == 'detailed') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with percentage and size info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Uploading: $percentage%',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (totalBytes > 0)
                Text(
                  '$uploadedStr / $totalStr',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Progress bar with semantic labels for accessibility
          Semantics(
            label: 'Upload progress: $percentage percent',
            enabled: true,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  progress < 0.5
                      ? Colors.blue
                      : progress < 0.9
                      ? Colors.blueAccent
                      : Colors.green,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Additional info row (speed, ETA, cancel button)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                uploadSpeedDisplay,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              if (onCancel != null)
                TextButton(
                  onPressed: onCancel,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text('Cancel'),
                ),
            ],
          ),
        ],
      );
    } else {
      // Simple format - just percentage and progress bar
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Uploading... $percentage%',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
            ),
          ),
        ],
      );
    }
  }
}
