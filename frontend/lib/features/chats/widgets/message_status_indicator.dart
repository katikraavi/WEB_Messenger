import 'package:flutter/material.dart';
import '../models/message_model.dart';

/// Message status indicator widget (T026)
/// 
/// Displays message status with animated transitions:
/// - ✓ (single checkmark) - sent
/// - ✓✓ (double checkmark) - delivered
/// - ✓✓ (double checkmark, blue) - read
class MessageStatusIndicator extends StatefulWidget {
  final Message message;
  final Duration? animationDuration;

  const MessageStatusIndicator({
    Key? key,
    required this.message,
    this.animationDuration = const Duration(milliseconds: 300),
  }) : super(key: key);

  @override
  State<MessageStatusIndicator> createState() => _MessageStatusIndicatorState();
}

class _MessageStatusIndicatorState extends State<MessageStatusIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimation();
  }

  void _initAnimation() {
    _animationController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(-0.2, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
  }

  @override
  void didUpdateWidget(MessageStatusIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If status changed, restart animation
    if (oldWidget.message.status != widget.message.status) {
      _animationController.reset();
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.message.isSending) {
      // Loading state - show nothing, parent handles spinner
      return const SizedBox.shrink();
    }

    final status = widget.message.status;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: _buildStatusIcon(),
      ),
    );
  }

  /// Build status icon based on message status
  Widget _buildStatusIcon() {
    final status = _normalizeStatus(widget.message.status);
    final readCount = widget.message.readCount ?? 0;
    
    // For group chats, show yellow indicator if any recipient has read the message
    final isRead = status == 'read' || readCount > 0;
    final isDelivered = status == 'delivered';

    if (isRead) {
      return _buildDoubleCheckmark(isYellow: true);
    } else if (isDelivered) {
      return _buildDoubleCheckmark(isYellow: false);
    } else {
      return _buildSingleCheckmark();
    }
  }

  String _normalizeStatus(String? rawStatus) {
    final status = (rawStatus ?? '').trim().toLowerCase();
    if (status.isEmpty) return 'sent';

    if (status == 'read' || status.contains('read')) {
      return 'read';
    }
    if (status == 'delivered' || status.contains('deliver')) {
      return 'delivered';
    }

    return 'sent';
  }

  Widget _buildGroupReceiptSummary() {
    final recipientCount = widget.message.recipientCount ?? 0;
    final deliveredCount = widget.message.deliveredCount ?? 0;
    final readCount = widget.message.readCount ?? 0;

    String label;
    Color color;

    if (recipientCount == 0) {
      label = 'Sent';
      color = Colors.grey.shade500;
    } else if (readCount == recipientCount) {
      label = 'Read $readCount/$recipientCount';
      color = Colors.yellow.shade700;
    } else if (readCount > 0) {
      label = 'Read $readCount/$recipientCount';
      color = Colors.yellow.shade700;
    } else if (deliveredCount > 0) {
      label = 'Delivered $deliveredCount/$recipientCount';
      color = Colors.grey.shade600;
    } else {
      label = 'Sent';
      color = Colors.grey.shade500;
    }

    return Tooltip(
      message: label,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  /// Build single checkmark icon (sent status)
  Widget _buildSingleCheckmark() {
    return Tooltip(
      message: 'Sent ✓',
      child: Icon(
        Icons.check,
        size: 14,
        color: Colors.grey.shade500,
        semanticLabel: 'Message sent',
      ),
    );
  }

  /// Build double checkmark icon (delivered or read status)
  Widget _buildDoubleCheckmark({required bool isYellow}) {
    return Tooltip(
      message: isYellow ? 'Read ✓✓ (YELLOW)' : 'Delivered ✓✓',
      child: CustomPaint(
        size: const Size(14, 12),
        painter: DoubleCheckmarkPainter(
          color: isYellow ? Colors.yellow.shade700 : Colors.grey.shade500,
          strokeWidth: 2.0,
        ),
      ),
    );
  }
}

/// Custom painter for double checkmark icon
class DoubleCheckmarkPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  DoubleCheckmarkPainter({
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // First checkmark (left one)
    // Goes from (2, 6) to (4, 8) to (6, 4)
    final path1 = Path()
      ..moveTo(2, 6)
      ..lineTo(4, 8.5)
      ..lineTo(7, 4);

    canvas.drawPath(path1, paint);

    // Second checkmark (right one)
    // Overlaps slightly and continues right
    // Goes from (5, 6) to (7, 8) to (11, 3)
    final path2 = Path()
      ..moveTo(5, 6)
      ..lineTo(7, 8.5)
      ..lineTo(12, 3);

    canvas.drawPath(path2, paint);
  }

  @override
  bool shouldRepaint(DoubleCheckmarkPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

/// Extension for message display utilities
extension MessageDisplayExt on Message {
  /// Get formatted time string
  String getDisplayTime() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final messageDay = DateTime(createdAt.year, createdAt.month, createdAt.day);

    String formattedDate;
    if (messageDay == today) {
      formattedDate = 'Today';
    } else if (messageDay == yesterday) {
      formattedDate = 'Yesterday';
    } else {
      formattedDate =
          '${createdAt.month}/${createdAt.day}/${createdAt.year}';
    }

    final timeStr =
        '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';

    return '$formattedDate $timeStr';
  }
}
