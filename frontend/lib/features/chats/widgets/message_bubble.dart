import 'package:flutter/material.dart';
import '../models/message_model.dart';
import './message_status_indicator.dart';
import './user_avatar_widget.dart';

/// Message bubble widget (T025, T040, T052, T054)
/// 
/// Displays a message in a chat in a Material Design bubble
/// with support for:
/// - Sent vs received styling
/// - Message status indicators (sent ✓, delivered ✓✓, read ✓✓ blue)
/// - Optimistic UI updates (isSending state)
/// - Error handling with retry
/// - Message timestamps
/// - Edit/Delete menu (long-press context menu) (T052)
/// - "(edited)" indicator for edited messages (T054)
/// - Encryption indicator
/// - Long content wrapping
class MessageBubble extends StatelessWidget {
  final Message message;
  final String currentUserId;
  final VoidCallback? onLongPress;
  final VoidCallback? onRetry; // Callback to retry failed send
  final Function(String)? onEdit; // Callback for edit action (T052)
  final VoidCallback? onDelete; // Callback for delete action (T052)
  
  /// Whether this is the last message from this sender in a group
  final bool isLastFromSender;
  
  /// Whether this is the first message from this sender in a group
  final bool isFirstFromSender;

  const MessageBubble({
    Key? key,
    required this.message,
    required this.currentUserId,
    this.onLongPress,
    this.onRetry,
    this.onEdit,
    this.onDelete,
    this.isLastFromSender = true,
    this.isFirstFromSender = true,
  }) : super(key: key);

  /// Check if message is sent by current user
  bool get isSentByUser => message.senderId == currentUserId;

  /// Get display content (decrypted if available)
  String get displayContent => message.getDisplayContent();

  @override
  Widget build(BuildContext context) {
    // Reduce padding for grouped messages from same sender
    final verticalPadding = isFirstFromSender ? 8.0 : 2.0;
    
    return Align(
      alignment: isSentByUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: verticalPadding),
        child: Row(
          mainAxisAlignment: isSentByUser
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Profile picture for received messages (only show for last message in group)
            if (!isSentByUser)
              Padding(
                padding: const EdgeInsets.only(right: 8.0, bottom: 0),
                child: isLastFromSender
                    ? _buildProfilePicture()
                    : SizedBox(width: 36), // Placeholder for alignment
              ),
            
            // Message bubble column
            Flexible(
              child: Column(
                crossAxisAlignment: isSentByUser
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  // Username - only show for first message in group from receiver
                  if (!isSentByUser && isFirstFromSender && message.senderUsername != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4.0, left: 4.0),
                      child: Text(
                        message.senderUsername!,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  GestureDetector(
                    onLongPress: _showContextMenu,
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.75,
                      ),
                      decoration: BoxDecoration(
                        color: _getBubbleColor(),
                        borderRadius: BorderRadius.circular(16),
                        border: message.hasError ? Border.all(color: Colors.red.shade300, width: 1) : null,
                        boxShadow: message.isSending
                            ? [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.3),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                )
                              ]
                            : null,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Column(
                        crossAxisAlignment: isSentByUser
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          // Media display (T077)
                          if (message.mediaUrl != null)
                            _buildMediaWidget(context),
                          
                          // Message content
                          if (displayContent.isNotEmpty)
                            Padding(
                              padding: message.mediaUrl != null 
                                  ? const EdgeInsets.only(top: 8)
                                  : EdgeInsets.zero,
                              child: Text(
                                displayContent,
                                style: TextStyle(
                                  color: _getTextColor(),
                                  fontSize: 16,
                                  height: 1.4,
                                ),
                                softWrap: true,
                              ),
                            ),
                          const SizedBox(height: 6),
                          // Timestamp + Edited indicator + Status indicator row
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: isSentByUser 
                                ? MainAxisAlignment.end 
                                : MainAxisAlignment.start,
                            children: [
                              // Timestamp
                              Text(
                                message.getDisplayTime(),
                                style: TextStyle(
                                  color: _getSubtleTextColor(),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              // Edited indicator (T054)
                              if (message.editedAt != null) ...[
                                const SizedBox(width: 4),
                                Text(
                                  '(edited)',
                                  style: TextStyle(
                                    color: _getSubtleTextColor(),
                                    fontSize: 11,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                              const SizedBox(width: 6),
                              // Status indicator (only for sent messages)
                              if (isSentByUser)
                                MessageStatusIndicator(
                                  key: ValueKey('${message.id}_${message.status}'),
                                  message: message,
                                ),
                              // Loading spinner if sending
                              if (message.isSending)
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: Padding(
                                    padding: EdgeInsets.only(left: 4),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Error message below bubble
                  if (message.hasError && isSentByUser)
                    Padding(
                      padding: const EdgeInsets.only(top: 6, right: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.red.shade600,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            message.error ?? 'Failed to send',
                            style: TextStyle(
                              color: Colors.red.shade600,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (onRetry != null) ...[
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: onRetry,
                              child: Text(
                                'Retry',
                                style: TextStyle(
                                  color: Colors.blue.shade600,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Get bubble background color based on state
  Color _getBubbleColor() {
    if (message.hasError) {
      return Colors.red.shade50;
    }
    if (isSentByUser) {
      return Colors.blue.shade500;
    }
    return Colors.grey.shade300;
  }

  /// Get text color based on state
  Color _getTextColor() {
    if (message.hasError) {
      return Colors.red.shade900;
    }
    return isSentByUser ? Colors.white : Colors.black;
  }

  /// Get subtle text color for timestamps
  Color _getSubtleTextColor() {
    if (message.hasError) {
      return Colors.red.shade600;
    }
    if (isSentByUser) {
      return Colors.blue.shade100;
    }
    return Colors.grey.shade600;
  }
  
  /// Build media widget (image or video) (T077)
  Widget _buildMediaWidget(BuildContext context) {
    final mediaUrl = message.mediaUrl;
    final mimeType = message.mediaType ?? '';
    
    if (mediaUrl == null) {
      return SizedBox.shrink();
    }
    
    if (mimeType.startsWith('image/')) {
      // Image media
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: 250,
            maxHeight: 300,
          ),
          color: Colors.grey.shade200,
          child: Image.network(
            mediaUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              color: Colors.grey.shade300,
              child: Icon(Icons.broken_image, color: Colors.grey.shade600),
            ),
          ),
        ),
      );
    } else if (mimeType.startsWith('video/')) {
      // Video media - show thumbnail with play button
      return GestureDetector(
        onTap: () {
          // TODO: Open video player
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Video playback coming soon')),
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: 250,
              maxHeight: 300,
            ),
            color: Colors.grey.shade300,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Placeholder thumbnail
                Icon(
                  Icons.videocam,
                  size: 60,
                  color: Colors.grey.shade600,
                ),
                // Play button overlay
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withOpacity(0.5),
                  ),
                  child: Icon(
                    Icons.play_arrow,
                    size: 32,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      // Unknown media type
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.attachment, color: Colors.grey.shade600),
      );
    }
  }

  /// Build profile picture widget for received messages
  Widget _buildProfilePicture() {
    return UserAvatarWidget(
      imageUrl: message.senderAvatarUrl,
      radius: 18,
      username: message.senderUsername,
    );
  }
  
  /// Show context menu for edit/delete (T052)
  void _showContextMenu() {
    onLongPress?.call();
    
    // Only show menu for own messages
    if (!isSentByUser) return;
    
    // Show context menu with edit/delete options
    // This would typically use showMenu or a custom popup
    // For now, this is a placeholder - actual implementation would
    // be in the parent widget's onLongPress handler
  }
}
