import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Widget to display copyable error messages
/// Shows error text with a copy button
class CopyableErrorWidget extends StatelessWidget {
  final String error;
  final String? title;
  final IconData icon;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;
  final VoidCallback? onRetry;

  const CopyableErrorWidget({
    Key? key,
    required this.error,
    this.title,
    this.icon = Icons.error_outline,
    this.backgroundColor = const Color.fromARGB(255, 255, 243, 243),
    this.borderColor = const Color.fromARGB(255, 244, 67, 54),
    this.textColor = const Color.fromARGB(255, 211, 47, 47),
    this.onRetry,
  }) : super(key: key);

  void _copyError(BuildContext context) {
    Clipboard.setData(ClipboardData(text: error));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Error copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row with icon
          Row(
            children: [
              Icon(icon, color: textColor, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title ?? 'Error',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Error message (selectable)
          SelectableText(
            error,
            style: TextStyle(
              color: textColor,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _copyError(context),
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copy Error'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: textColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              if (onRetry != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Widget for inline error displays in containers/banners
class CopyableErrorBanner extends StatelessWidget {
  final String error;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;
  final Color iconColor;

  const CopyableErrorBanner({
    Key? key,
    required this.error,
    this.backgroundColor = const Color.fromARGB(255, 255, 243, 243),
    this.borderColor = const Color.fromARGB(255, 244, 67, 54),
    this.textColor = const Color.fromARGB(255, 211, 47, 47),
    this.iconColor = const Color.fromARGB(255, 244, 67, 54),
  }) : super(key: key);

  void _copyError(BuildContext context) {
    Clipboard.setData(ClipboardData(text: error));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Error copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: iconColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onLongPress: () => _copyError(context),
              child: SelectableText(
                error,
                style: TextStyle(
                  color: textColor,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            onPressed: () => _copyError(context),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
            tooltip: 'Copy error',
          ),
        ],
      ),
    );
  }
}

/// Utility function to show copyable error snackbar
void showCopyableErrorSnackBar(BuildContext context, String errorMessage) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Expanded(
            child: SelectableText(
              errorMessage,
              style: const TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: errorMessage));
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Error copied!'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            child: const Icon(Icons.copy, size: 18, color: Colors.white),
          ),
        ],
      ),
      backgroundColor: Colors.red[700],
      duration: const Duration(seconds: 8),
    ),
  );
}
