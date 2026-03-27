import 'dart:async';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:frontend/core/services/api_client.dart';
import 'package:video_player/video_player.dart';
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
/// - Search result highlighting
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

  /// Whether this message is currently the focused search result
  final bool isCurrentSearchResult;

  /// Whether this message is a search result (but not the current one)
  final bool isOtherSearchResult;

  /// Search query to highlight in the message content
  final String? searchQuery;

  const MessageBubble({
    super.key,
    required this.message,
    required this.currentUserId,
    this.onLongPress,
    this.onRetry,
    this.onEdit,
    this.onDelete,
    this.isLastFromSender = true,
    this.isFirstFromSender = true,
    this.isCurrentSearchResult = false,
    this.isOtherSearchResult = false,
    this.searchQuery,
  });

  /// Check if message is sent by current user
  bool get isSentByUser => message.senderId == currentUserId;

  /// Get display content (decrypted if available)
  String get displayContent => message.getDisplayContent();

  String get failureLabel => message.hasError ? 'Not sent' : 'Failed to send';

  @override
  Widget build(BuildContext context) {
    // Reduce padding for grouped messages from same sender
    final verticalPadding = isFirstFromSender ? 8.0 : 2.0;

    return Align(
      alignment: isSentByUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: verticalPadding,
        ),
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
                  if (!isSentByUser &&
                      isFirstFromSender &&
                      message.senderUsername != null)
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
                        border: isCurrentSearchResult
                            ? Border.all(
                                color: Colors.orange.shade600,
                                width: 3,
                              )
                            : isOtherSearchResult
                                ? Border.all(
                                    color: Colors.amber.shade300,
                                    width: 2,
                                  )
                                : message.hasError
                                    ? Border.all(
                                        color: Colors.red.shade300,
                                        width: 1,
                                      )
                                    : null,
                        boxShadow: isCurrentSearchResult
                            ? [
                                BoxShadow(
                                  color: Colors.orange.withValues(alpha: 0.5),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                              ]
                            : isOtherSearchResult
                                ? [
                                    BoxShadow(
                                      color: Colors.amber.withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : message.isSending
                                    ? [
                                        BoxShadow(
                                          color: Colors.blue.withValues(
                                            alpha: 0.3,
                                          ),
                                          blurRadius: 4,
                                          spreadRadius: 1,
                                        ),
                                      ]
                                    : null,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
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
                              child: _buildHighlightedText(displayContent, searchQuery),
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
                              if (isSentByUser && message.hasReceiptTracking)
                                MessageStatusIndicator(
                                  key: ValueKey(
                                    '${message.id}_${message.status}',
                                  ),
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
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.red.shade600,
                            size: 14,
                          ),
                          Text(
                            failureLabel,
                            style: TextStyle(
                              color: Colors.red.shade600,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (onRetry != null) ...[
                            GestureDetector(
                              onTap: onRetry,
                              child: Text(
                                'Send again',
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

    final resolvedMediaUrl = _resolveMediaUrl(mediaUrl);

    if (mimeType.startsWith('image/')) {
      // Image media
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: BoxConstraints(maxWidth: 250, maxHeight: 300),
          color: Colors.grey.shade200,
          child: Image.network(
            resolvedMediaUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              color: Colors.grey.shade300,
              child: Icon(Icons.broken_image, color: Colors.grey.shade600),
            ),
          ),
        ),
      );
    } else if (mimeType.startsWith('video/')) {
      // Wrap video player in error boundary to prevent platform crashes
      return _VideoPlayerErrorBoundary(url: resolvedMediaUrl);
    } else if (mimeType.startsWith('audio/')) {
      return _InlineAudioPlayer(url: resolvedMediaUrl);
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

  String _resolveMediaUrl(String mediaUrl) {
    if (mediaUrl.startsWith('http://') || mediaUrl.startsWith('https://')) {
      return mediaUrl;
    }

    final baseUrl = ApiClient.getBaseUrl();

    if (mediaUrl.startsWith('/')) {
      return '$baseUrl$mediaUrl';
    }

    return '$baseUrl/$mediaUrl';
  }

  /// Build profile picture widget for received messages
  Widget _buildProfilePicture() {
    return UserAvatarWidget(
      imageUrl: message.senderAvatarUrl,
      radius: 18,
      username: message.senderUsername,
    );
  }

  /// Build text widget with search term highlighting
  Widget _buildHighlightedText(String text, String? searchQuery) {
    // If no search query or empty query, return plain text
    if (searchQuery == null || searchQuery.trim().isEmpty) {
      return Text(
        text,
        style: TextStyle(
          color: _getTextColor(),
          fontSize: 16,
          height: 1.4,
        ),
        softWrap: true,
      );
    }

    // Split text by search term (case-insensitive)
    final query = searchQuery.toLowerCase();
    final lowerText = text.toLowerCase();
    final spans = <TextSpan>[];
    
    int lastIndex = 0;
    int index = 0;

    while ((index = lowerText.indexOf(query, lastIndex)) != -1) {
      // Add non-matching text before the match
      if (index > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, index),
          style: TextStyle(
            color: _getTextColor(),
            fontSize: 16,
            height: 1.4,
          ),
        ));
      }

      // Add highlighted match
      spans.add(TextSpan(
        text: text.substring(index, index + query.length),
        style: TextStyle(
          color: Colors.black87,
          fontSize: 16,
          height: 1.4,
          backgroundColor: Colors.yellow[300],
          fontWeight: FontWeight.w600,
        ),
      ));

      lastIndex = index + query.length;
    }

    // Add remaining text after last match
    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: TextStyle(
          color: _getTextColor(),
          fontSize: 16,
          height: 1.4,
        ),
      ));
    }

    // If no matches found, return plain text
    if (spans.isEmpty) {
      return Text(
        text,
        style: TextStyle(
          color: _getTextColor(),
          fontSize: 16,
          height: 1.4,
        ),
        softWrap: true,
      );
    }

    return RichText(
      text: TextSpan(children: spans),
      softWrap: true,
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

class _InlineAudioPlayer extends StatefulWidget {
  final String url;

  const _InlineAudioPlayer({required this.url});

  @override
  State<_InlineAudioPlayer> createState() => _InlineAudioPlayerState();
}

class _InlineAudioPlayerState extends State<_InlineAudioPlayer> {
  late final Player _player;
  bool _initialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _initialize();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      await _player.open(Media(widget.url));
      await _player.pause();
      if (!mounted) {
        return;
      }
      setState(() {
        _initialized = true;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _hasError = true;
      });
    }
  }

  Future<void> _togglePlayback(bool isPlaying) async {
    if (isPlaying) {
      await _player.pause();
      return;
    }

    await _player.play();
  }

  Future<void> _seekTo(double value, Duration duration) async {
    final milliseconds = (duration.inMilliseconds * value).round();
    await _player.seek(Duration(milliseconds: milliseconds));
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.error_outline),
      );
    }

    if (!_initialized) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return Container(
      width: 250,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: StreamBuilder<bool>(
        stream: _player.stream.playing,
        initialData: _player.state.playing,
        builder: (context, playingSnapshot) {
          final isPlaying = playingSnapshot.data ?? false;
          return StreamBuilder<Duration>(
            stream: _player.stream.position,
            initialData: _player.state.position,
            builder: (context, positionSnapshot) {
              final position = positionSnapshot.data ?? Duration.zero;
              return StreamBuilder<Duration>(
                stream: _player.stream.duration,
                initialData: _player.state.duration,
                builder: (context, durationSnapshot) {
                  final duration = durationSnapshot.data ?? Duration.zero;
                  final progress = duration.inMilliseconds <= 0
                      ? 0.0
                      : (position.inMilliseconds / duration.inMilliseconds)
                            .clamp(0.0, 1.0);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => _togglePlayback(isPlaying),
                            icon: Icon(
                              isPlaying
                                  ? Icons.pause_circle_filled
                                  : Icons.play_circle_fill,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Audio message',
                              style: TextStyle(
                                color: Colors.grey.shade900,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: progress,
                        onChanged: duration.inMilliseconds <= 0
                            ? null
                            : (value) => _seekTo(value, duration),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

/// Error boundary widget for video player to catch platform crashes
class _VideoPlayerErrorBoundary extends StatefulWidget {
  final String url;

  const _VideoPlayerErrorBoundary({required this.url});

  @override
  State<_VideoPlayerErrorBoundary> createState() =>
      _VideoPlayerErrorBoundaryState();
}

class _VideoPlayerErrorBoundaryState extends State<_VideoPlayerErrorBoundary> {
  bool _hasError = false;

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _buildFallbackUI();
    }

    return _InlineVideoPlayer(
      url: widget.url,
      onError: () {
        if (mounted) {
          setState(() {
            _hasError = true;
          });
        }
      },
    );
  }

  Widget _buildFallbackUI() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 250, maxHeight: 300),
        color: Colors.black12,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.video_file, color: Colors.grey.shade400, size: 40),
              const SizedBox(height: 8),
              Text(
                'Video unavailable',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                widget.url.split('/').last,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineVideoPlayer extends StatefulWidget {
  final String url;
  final VoidCallback onError;

  const _InlineVideoPlayer({required this.url, required this.onError});

  @override
  State<_InlineVideoPlayer> createState() => _InlineVideoPlayerState();
}

class _InlineVideoPlayerState extends State<_InlineVideoPlayer> {
  VideoPlayerController? _controller;
  Timer? _progressTimer;
  bool _showControls = true;
  bool _isMuted = false;
  bool _initialized = false;
  bool _hasError = false;
  double _aspectRatio = 16 / 9;
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  bool get _isPlaying => _controller?.value.isPlaying ?? false;

  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      final controller = _controller;
      if (!mounted || !_initialized || controller == null) {
        return;
      }
      final durationMs = controller.value.duration.inMilliseconds;
      final positionMs = controller.value.position.inMilliseconds;
      setState(() {
        _progress = durationMs <= 0
            ? 0.0
            : (positionMs / durationMs).clamp(0.0, 1.0);
      });
    });
  }

  Future<void> _initialize() async {
    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.url),
      );
      _controller = controller;

      await controller.initialize().timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Video loading timeout'),
      );
      controller.setLooping(false);

      final ratio = controller.value.aspectRatio;
      if (ratio > 0) {
        _aspectRatio = ratio;
      }

      controller.addListener(() {
        if (mounted) setState(() {});
      });
      _startProgressTimer();

      if (!mounted) return;
      setState(() {
        _initialized = true;
      });
    } catch (e) {
      widget.onError();
      if (!mounted) return;
      setState(() {
        _hasError = true;
      });
    }
  }

  Future<void> _togglePlayback() async {
    final player = _controller;
    if (player == null || !_initialized) return;

    if (_isPlaying) {
      await player.pause();
      setState(() {
        _showControls = true;
      });
    } else {
      await player.play();
      setState(() {
        _showControls = false;
      });
    }
  }

  Future<void> _toggleMute() async {
    final player = _controller;
    if (player == null) return;
    _isMuted = !_isMuted;
    await player.setVolume(_isMuted ? 0 : 1);
    if (mounted) setState(() {});
  }

  Future<void> _seekTo(double fraction) async {
    final player = _controller;
    if (player == null || !player.value.isInitialized) return;
    final durationMs = player.value.duration.inMilliseconds;
    if (durationMs <= 0) return;
    final ms = (durationMs * fraction).round();
    await player.seekTo(Duration(milliseconds: ms));
    if (mounted) {
      setState(() {
        _progress = fraction.clamp(0.0, 1.0);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Error state
    if (_hasError) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 250),
          color: Colors.black,
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.video_file, color: Colors.grey.shade400, size: 40),
                const SizedBox(height: 8),
                Text(
                  'Video unavailable',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.url.split('/').last,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Loading spinner while initializing
    if (!_initialized) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 250),
          color: Colors.black,
          child: const AspectRatio(
            aspectRatio: 16 / 9,
            child: Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
        ),
      );
    }

    // Initialized: render player
    final player = _controller!;
    final durationMs = player.value.duration.inMilliseconds;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 250, maxHeight: 300),
        color: Colors.black,
        child: AspectRatio(
          aspectRatio: _aspectRatio,
          child: GestureDetector(
            onTap: () => setState(() {
              _showControls = !_showControls;
            }),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(child: VideoPlayer(player)),
                if (_showControls || !_isPlaying)
                  Container(color: Colors.black.withValues(alpha: 0.28)),
                if (_showControls || !_isPlaying)
                  IconButton(
                    onPressed: _togglePlayback,
                    iconSize: 48,
                    color: Colors.white,
                    icon: Icon(
                      _isPlaying
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_fill,
                    ),
                  ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: IconButton(
                    onPressed: _toggleMute,
                    color: Colors.white,
                    icon: Icon(_isMuted ? Icons.volume_off : Icons.volume_up),
                  ),
                ),
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 8,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 5,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 10,
                      ),
                    ),
                    child: Slider(
                      value: _progress,
                      onChanged: durationMs <= 0 ? null : _seekTo,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
