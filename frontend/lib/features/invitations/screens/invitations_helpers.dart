part of 'invitations_screen.dart';

String _formatDate(DateTime dateTime) {
  final now = DateTime.now();
  final difference = now.difference(dateTime);

  if (difference.inSeconds < 60) {
    return 'just now';
  } else if (difference.inMinutes < 60) {
    return '${difference.inMinutes}m ago';
  } else if (difference.inHours < 24) {
    return '${difference.inHours}h ago';
  } else if (difference.inDays < 7) {
    return '${difference.inDays}d ago';
  } else {
    return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
  }
}

Widget _buildStatusBadge(String status) {
  Color backgroundColor;
  Color textColor;
  String displayText;
  IconData? icon;

  switch (status.toLowerCase()) {
    case 'pending':
      backgroundColor = Colors.amber.withValues(alpha: 0.2);
      textColor = Colors.amber[800]!;
      displayText = 'Pending';
      icon = Icons.schedule;
      break;
    case 'accepted':
      backgroundColor = Colors.green.withValues(alpha: 0.2);
      textColor = Colors.green[800]!;
      displayText = 'Accepted';
      icon = Icons.check_circle;
      break;
    case 'declined':
      backgroundColor = Colors.red.withValues(alpha: 0.2);
      textColor = Colors.red[800]!;
      displayText = 'Declined';
      icon = Icons.cancel;
      break;
    case 'canceled':
      backgroundColor = Colors.grey.withValues(alpha: 0.2);
      textColor = Colors.grey[800]!;
      displayText = 'Canceled';
      icon = Icons.block;
      break;
    default:
      backgroundColor = Colors.grey.withValues(alpha: 0.2);
      textColor = Colors.grey[800]!;
      displayText = status;
      icon = null;
  }

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
        ],
        Text(
          displayText,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ],
    ),
  );
}

void _showErrorDialog(
  BuildContext context,
  String title,
  String message, {
  VoidCallback? onRetry,
  dynamic error,
}) {
  final isOffline =
      InviteErrorHandler.indicatesOfflineState(error) ||
      (error?.toString().contains('Connection') ?? false);
  final isRecoverable = InviteErrorHandler.isRecoverableError(error);
  final suggestion = InviteErrorHandler.getRecoverySuggestion(error);
  final severity = InviteErrorHandler.getErrorSeverity(error);

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          Icon(
            severity == ErrorSeverity.critical ? Icons.error : Icons.warning,
            color: severity == ErrorSeverity.critical
                ? Colors.red
                : Colors.orange,
            size: 24,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(title)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            if (isOffline) ...[const SizedBox(height: 12), _buildOfflineHint()],
            if (isRecoverable && !isOffline) ...[
              const SizedBox(height: 12),
              _buildRecoveryHint(suggestion),
            ],
            if (suggestion.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildSuggestionChips(suggestion),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Dismiss'),
        ),
        if (isRecoverable && onRetry != null)
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              onRetry();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          )
        else if (isOffline && onRetry != null)
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              // Show Toast instead of immediate retry
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Waiting for connection... Please check your network.',
                  ),
                  duration: Duration(seconds: 3),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            icon: const Icon(Icons.cloud_off),
            label: const Text('Waiting...'),
          ),
      ],
    ),
  );
}

/// Build offline connection hint
Widget _buildOfflineHint() {
  return Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: Colors.red[50],
      border: Border.all(color: Colors.red[200]!),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Row(
      children: [
        Icon(Icons.cloud_off, color: Colors.red[700], size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'No internet connection detected. Please enable WiFi or mobile data.',
            style: TextStyle(color: Colors.red[700], fontSize: 12),
          ),
        ),
      ],
    ),
  );
}

/// Build recovery hint
Widget _buildRecoveryHint(String suggestion) {
  return Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: Colors.blue[50],
      border: Border.all(color: Colors.blue[200]!),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Row(
      children: [
        Icon(Icons.info, color: Colors.blue[700], size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Try: $suggestion',
            style: TextStyle(color: Colors.blue[700], fontSize: 12),
          ),
        ),
      ],
    ),
  );
}

/// Build suggestion action chips
Widget _buildSuggestionChips(String suggestionText) {
  final suggestions = suggestionText.split('•').map((s) => s.trim()).toList();

  return Wrap(
    spacing: 6,
    children: suggestions
        .where((s) => s.isNotEmpty)
        .map(
          (suggestion) => Chip(
            label: Text(suggestion, style: const TextStyle(fontSize: 11)),
            backgroundColor: Colors.grey[200],
            onDeleted: null,
          ),
        )
        .toList(),
  );
}

// ---------------------------------------------------------------------------
// Group Invitations Tab
// ---------------------------------------------------------------------------

/// Stateful widget that loads and displays pending group invitations.
