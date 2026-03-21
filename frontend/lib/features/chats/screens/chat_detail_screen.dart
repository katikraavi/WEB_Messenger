import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as provider_pkg;
import 'dart:async';
import 'dart:convert';
import 'package:frontend/core/notifications/app_feedback_service.dart';
import 'package:frontend/core/services/app_exception_logger.dart';
import '../models/message_model.dart' show Message;
import '../providers/messages_provider.dart';
import '../providers/message_status_provider.dart';
import '../providers/send_message_provider.dart';
import '../providers/typing_indicator_provider.dart';
import '../providers/websocket_provider.dart';
import '../services/chat_api_service.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_input_box.dart';
import '../widgets/typing_indicator.dart';
import '../widgets/edit_message_dialog.dart';
import '../widgets/user_avatar_widget.dart';
import '../services/media_picker_service.dart';
import '../services/media_upload_service.dart';
import '../services/message_encryption_service.dart';
import '../services/audio_recording_service.dart';
import '../services/chat_notification_settings_service.dart';
import '../../auth/providers/auth_provider.dart' as auth;

String _displayName(String? value) {
  if (value == null || value.isEmpty) {
    return 'Unknown';
  }

  return value[0].toUpperCase() + value.substring(1);
}

/// Screen for displaying a single chat conversation (T042-T043, T025-T027)
///
/// Features:
/// - Displays message history for a specific chat
/// - Real-time message sending with encryption
/// - Optimistic message updates (shows message immediately with loading indicator)
/// - Pull-to-refresh to load older messages
/// - Shows participant name in app bar
/// - Auto-scrolls to newest message on send
/// - Status indicators with animated checkmarks
class ChatDetailScreen extends ConsumerStatefulWidget {
  /// The chat ID
  final String chatId;

  /// The other participant's user ID
  final String otherUserId;

  /// The other participant's display name
  final String otherUserName;

  /// The other participant's profile picture URL (optional)
  final String? otherUserAvatarUrl;

  const ChatDetailScreen({
    Key? key,
    required this.chatId,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserAvatarUrl,
  }) : super(key: key);

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen> {
  late ScrollController _scrollController;
  late final WebSocketNotifier _webSocketNotifier;
  LocalMessagesNotifier? _localMessagesNotifier;

  // Track whether we've enabled viewer active mode
  bool _viewerActiveEnabled = false;
  bool _isRecordingAudio = false;
  bool _isChatMuted = false;
  bool _notificationSettingsLoaded = false;
  String? _headerErrorMessage;
  bool _showReconnectAction = false;
  bool _isReconnectInProgress = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _webSocketNotifier = ref.read(messageWebSocketProvider.notifier);

    // Connect to WebSocket for real-time messaging after frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _connectWebSocket();
    });
  }

  /// Connect to WebSocket and subscribe to chat
  Future<void> _connectWebSocket() async {
    try {
      final authProvider = provider_pkg.Provider.of<auth.AuthProvider>(
        context,
        listen: false,
      );

      final token = authProvider.token;
      final userId = authProvider.user?.userId;

      if (token == null || userId == null) {
        debugPrint(
          '[ChatDetail] Cannot connect to WebSocket - not authenticated',
        );
        return;
      }

      // Get the websocket service from riverpod
      // Connect if not already connected
      if (!ref.read(messageWebSocketProvider).isConnected) {
        await _webSocketNotifier.connect(token: token, userId: userId);
      }

      // Subscribe to this chat
      _webSocketNotifier.subscribeToChat(widget.chatId);
      await _reloadMessagesAfterReconnect();
      _clearHeaderError();

      debugPrint(
        '[ChatDetail] ✓ Connected to WebSocket for chat ${widget.chatId}',
      );
    } catch (e) {
      AppExceptionLogger.log(e, context: 'ChatDetailScreen._connectWebSocket');
      _showHeaderError(
        'Realtime connection lost. Showing the last synced messages.',
        canRetry: true,
      );
      AppFeedbackService.showWarning(
        'Realtime updates are unavailable for this chat. Showing the last synced messages.',
      );
    }
  }

  Future<void> _reloadMessagesAfterReconnect() async {
    final authProvider = provider_pkg.Provider.of<auth.AuthProvider>(
      context,
      listen: false,
    );
    final token = authProvider.token;
    final userId = authProvider.user?.userId;

    if (token == null || userId == null) {
      return;
    }

    await ref
        .read(
          localMessagesProvider((
            chatId: widget.chatId,
            token: token,
            currentUserId: userId,
          )).notifier,
        )
        .loadMessagesFromServer();
  }

  void _showHeaderError(String message, {required bool canRetry}) {
    if (!mounted) {
      return;
    }

    setState(() {
      _headerErrorMessage = message;
      _showReconnectAction = canRetry;
      _isReconnectInProgress = false;
    });
  }

  void _clearHeaderError() {
    if (!mounted) {
      return;
    }

    if (_headerErrorMessage == null && !_isReconnectInProgress) {
      return;
    }

    setState(() {
      _headerErrorMessage = null;
      _showReconnectAction = false;
      _isReconnectInProgress = false;
    });
  }

  Future<void> _retryRealtimeConnection() async {
    if (_isReconnectInProgress) {
      return;
    }

    setState(() {
      _isReconnectInProgress = true;
      _headerErrorMessage = 'Reconnecting to realtime updates...';
      _showReconnectAction = false;
    });

    try {
      await _webSocketNotifier.disconnect();
      await _connectWebSocket();
      if (!mounted) {
        return;
      }
      AppFeedbackService.showInfo('Realtime connection restored.');
    } catch (e, st) {
      AppExceptionLogger.log(
        e,
        stackTrace: st,
        context: 'ChatDetailScreen._retryRealtimeConnection',
      );
      _showHeaderError(
        'Reconnect failed. Messenger is still showing the last stable messages.',
        canRetry: true,
      );
      AppFeedbackService.showError('Reconnect failed. Try again.');
    }
  }

  PreferredSizeWidget? _buildHeaderErrorBanner() {
    if (_headerErrorMessage == null) {
      return null;
    }

    return PreferredSize(
      preferredSize: const Size.fromHeight(52),
      child: Container(
        width: double.infinity,
        color: Colors.orange.shade50,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.error_outline, size: 18, color: Colors.orange.shade900),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _headerErrorMessage!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.orange.shade900,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (_isReconnectInProgress)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.orange.shade900,
                ),
              )
            else if (_showReconnectAction)
              TextButton(
                onPressed: _retryRealtimeConnection,
                child: const Text('Retry'),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Note: We disable viewer in deactivate() before dispose() since that's safer
    _scrollController.dispose();

    // Unsubscribe from chat and optionally disconnect
    try {
      _webSocketNotifier.unsubscribeFromChat();

      // Optionally disconnect if leaving the app entirely
      // For now, keep connection alive for other chats
      // wsNotifier.disconnect();
    } catch (e) {
      AppExceptionLogger.log(e, context: 'ChatDetailScreen.dispose');
    }

    super.dispose();
  }

  /// Called when widget is removed from tree, before dispose
  /// This is where we safely disable viewer mode
  @override
  void deactivate() {
    debugPrint(
      '[ChatDetail] 🚪 deactivate() called - disabling viewer mode for chat ${widget.chatId}',
    );

    if (_viewerActiveEnabled) {
      try {
        if (_localMessagesNotifier != null) {
          // Disable viewer mode - new messages should NOT auto-read
          _localMessagesNotifier!.setChatBeingViewed(false);
          _viewerActiveEnabled = false;
          debugPrint('[ChatDetail] ✓ Viewer mode disabled');
        }
      } catch (e) {
        AppExceptionLogger.log(e, context: 'ChatDetailScreen.deactivate');
      }
    }

    super.deactivate();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Trigger auto-mark-as-read when entering chat (T020)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final authProvider = provider_pkg.Provider.of<auth.AuthProvider>(
          context,
          listen: false,
        );

        if (authProvider.token != null) {
          // Trigger auto-read provider to mark unread messages as read
          // This will cause the recipient to show "read" status (blue checkmarks) to the sender
          debugPrint(
            '[ChatDetail] 🔔 Triggering auto-mark-as-read for chat ${widget.chatId}',
          );
          ref.read(
            autoMarkAsReadProvider((
              chatId: widget.chatId,
              token: authProvider.token!,
              currentUserId: authProvider.user!.userId,
            )),
          );
        }
      }
    });
  }

  /// Send typing start/stop event via WebSocket (T044)
  void _sendTypingEvent(String eventType) {
    try {
      if (eventType == 'typing.start') {
        _webSocketNotifier.sendTyping(widget.chatId);
      } else if (eventType == 'typing.stop') {
        _webSocketNotifier.stopTyping(widget.chatId);
      }

      debugPrint('[ChatDetail] Sent typing event: $eventType');
    } catch (e) {
      AppExceptionLogger.log(e, context: 'ChatDetailScreen._sendTypingEvent');
    }
  }

  /// Scroll to bottom of message list (newest messages)
  void _scrollToBottom() {
    // Schedule scroll after frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Handle message retry (T025 error state)
  Future<void> _handleRetry(
    Message failedMessage,
    String token,
    String currentUserId,
  ) async {
    // Only allow retry for messages with errors
    if (failedMessage.error == null) {
      return;
    }

    await ref
        .read(sendMessageProvider.notifier)
        .retryMessage(
          failedMessage: failedMessage,
          token: token,
          currentUserId: currentUserId,
        );
    _scrollToBottom();
  }

  /// Show context menu for message edit/delete (T052, T061)
  void _showMessageContextMenu(Message message, String token) {
    // Don't show menu for already deleted messages
    if (message.isDeleted) {
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(context);
                _showEditMessageDialog(message, token);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmationDialog(message, token);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Show edit message dialog (T052, T053)
  void _showEditMessageDialog(Message message, String token) {
    showDialog(
      context: context,
      builder: (context) => EditMessageDialog(
        messageId: message.id,
        currentContent: message.getDisplayContent(),
        onSave: (newContent) {
          _handleEditMessage(message, newContent, token);
        },
      ),
    );
  }

  /// Show delete confirmation dialog (T061)
  void _showDeleteConfirmationDialog(Message message, String token) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              unawaited(_handleDeleteMessage(message, token));
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  /// Handle message edit (T055)
  Future<void> _handleEditMessage(
    Message message,
    String newContent,
    String token,
  ) async {
    try {
      // For now, we'll just show a snackbar since backend isn't deployed yet
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Message edit feature coming soon'),
          action: SnackBarAction(label: 'OK', onPressed: () {}),
        ),
      );

      // TODO: Uncomment when backend is ready
      /*
      final editedMessage = await ref.read(editMessageProvider(
        (
          widget.chatId,
          message.id,
          newContent,
          token,
        ),
      ).future);
      
      debugPrint('[ChatDetail] ✅ Message edited: ${message.id}');
      
      // Refresh message list to show updated content
      await ref.refresh(
        messagesWithCacheProvider(
          (chatId: widget.chatId, token: token),
        ),
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message edited successfully')),
      );
      */
    } catch (e) {
      debugPrint('[ChatDetail] ❌ Error editing message: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to edit: $e')));
    }
  }

  /// Handle message delete (T062)
  Future<void> _handleDeleteMessage(Message message, String token) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Deleting message...'),
          duration: const Duration(seconds: 1),
        ),
      );

      // TODO: Uncomment when backend is ready
      /*
      await ref.read(deleteMessageProvider(
        (widget.chatId, message.id, token),
      ).future);

      debugPrint('[ChatDetail] ✅ Message deleted: ${message.id}');

      // Refresh message list to reflect deletion
      await ref.refresh(
        messagesWithCacheProvider(
          (chatId: widget.chatId, token: token),
        ),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message deleted')),
      );
      */
    } catch (e) {
      debugPrint('[ChatDetail] ❌ Error deleting message: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
    }
  }

  /// Handle image attachment (T079)
  Future<void> _handleImageAttachment(String token) async {
    try {
      debugPrint('[ChatDetail] 📸 Image attachment started');

      // Pick image from device
      final pickedMedia = await MediaPickerService.pickImage();
      if (pickedMedia == null) {
        debugPrint('[ChatDetail] ℹ️ Image selection cancelled');
        return;
      }

      // Show loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Uploading image...'),
          duration: Duration(seconds: 30),
        ),
      );

      // Upload media to backend
      final uploadService = MediaUploadService();
      final uploadedMedia = await uploadService.uploadMedia(
        pickedMedia: pickedMedia,
        token: token,
      );

      debugPrint('[ChatDetail] ✅ Image uploaded: ${uploadedMedia.id}');

      final chatApiService = ChatApiService(baseUrl: 'http://localhost:8081');
      final mediaPath = '/uploads/media/${uploadedMedia.fileName}';
      final sentMessage = await chatApiService.sendMessage(
        token: token,
        chatId: widget.chatId,
        encryptedContent: base64Encode(utf8.encode('[Image]')),
        mediaUrl: mediaPath,
        mediaType: uploadedMedia.mimeType,
      );
      final decryptedMessage = await MessageEncryptionService.decryptMessage(
        sentMessage,
      );

      ref
          .read(
            localMessagesProvider((
              chatId: widget.chatId,
              token: token,
              currentUserId: currentUserIdFromContext(),
            )).notifier,
          )
          .upsertMessage(decryptedMessage);

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Image sent: ${uploadedMedia.originalName ?? uploadedMedia.fileName}',
          ),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('[ChatDetail] ❌ Image upload error: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to upload image: $e')));
    }
  }

  /// Handle video attachment (T080)
  Future<void> _handleVideoAttachment(String token) async {
    try {
      debugPrint('[ChatDetail] 🎬 Video attachment started');

      // Pick video from device
      final pickedMedia = await MediaPickerService.pickVideo();
      if (pickedMedia == null) {
        debugPrint('[ChatDetail] ℹ️ Video selection cancelled');
        return;
      }

      // Show loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Uploading video...'),
          duration: Duration(seconds: 60),
        ),
      );

      // Upload media to backend
      final uploadService = MediaUploadService();
      final uploadedMedia = await uploadService.uploadMedia(
        pickedMedia: pickedMedia,
        token: token,
      );

      debugPrint('[ChatDetail] ✅ Video uploaded: ${uploadedMedia.id}');

      final chatApiService = ChatApiService(baseUrl: 'http://localhost:8081');
      final mediaPath = '/uploads/media/${uploadedMedia.fileName}';
      final sentMessage = await chatApiService.sendMessage(
        token: token,
        chatId: widget.chatId,
        encryptedContent: base64Encode(utf8.encode('[Video]')),
        mediaUrl: mediaPath,
        mediaType: uploadedMedia.mimeType,
      );
      final decryptedMessage = await MessageEncryptionService.decryptMessage(
        sentMessage,
      );

      ref
          .read(
            localMessagesProvider((
              chatId: widget.chatId,
              token: token,
              currentUserId: currentUserIdFromContext(),
            )).notifier,
          )
          .upsertMessage(decryptedMessage);

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Video sent: ${uploadedMedia.originalName ?? uploadedMedia.fileName}',
          ),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('[ChatDetail] ❌ Video upload error: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to upload video: $e')));
    }
  }

  Future<void> _handleAudioRecordingTap(String token) async {
    final recordingService = AudioRecordingService.instance;

    try {
      if (!recordingService.isRecording) {
        await recordingService.startRecording();
        if (!mounted) {
          return;
        }
        setState(() {
          _isRecordingAudio = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recording audio... tap the mic again to send'),
          ),
        );
        return;
      }

      if (mounted) {
        setState(() {
          _isRecordingAudio = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Uploading audio...'),
            duration: Duration(seconds: 30),
          ),
        );
      }

      final pickedMedia = await recordingService.stopRecording();
      final uploadService = MediaUploadService();
      final uploadedMedia = await uploadService.uploadMedia(
        pickedMedia: pickedMedia,
        token: token,
      );

      final chatApiService = ChatApiService(baseUrl: 'http://localhost:8081');
      final mediaPath = '/uploads/media/${uploadedMedia.fileName}';
      final sentMessage = await chatApiService.sendMessage(
        token: token,
        chatId: widget.chatId,
        encryptedContent: base64Encode(utf8.encode('[Audio]')),
        mediaUrl: mediaPath,
        mediaType: uploadedMedia.mimeType,
      );
      final decryptedMessage = await MessageEncryptionService.decryptMessage(
        sentMessage,
      );

      ref
          .read(
            localMessagesProvider((
              chatId: widget.chatId,
              token: token,
              currentUserId: currentUserIdFromContext(),
            )).notifier,
          )
          .upsertMessage(decryptedMessage);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Audio message sent')));
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRecordingAudio = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to record audio: $e')));
      }
    }
  }

  Future<void> _loadNotificationSettings(String token) async {
    try {
      final isMuted = await ChatNotificationSettingsService.instance
          .fetchMuteStatus(token: token, chatId: widget.chatId);
      if (!mounted) {
        return;
      }
      setState(() {
        _isChatMuted = isMuted;
        _notificationSettingsLoaded = true;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _notificationSettingsLoaded = true;
      });
    }
  }

  Future<void> _toggleChatMute(String token) async {
    final nextValue = !_isChatMuted;
    try {
      await ChatNotificationSettingsService.instance.setMuted(
        token: token,
        chatId: widget.chatId,
        isMuted: nextValue,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _isChatMuted = nextValue;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nextValue
                ? 'Chat notifications muted'
                : 'Chat notifications unmuted',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update notifications: $e')),
      );
    }
  }

  String currentUserIdFromContext() {
    final authProvider = provider_pkg.Provider.of<auth.AuthProvider>(
      context,
      listen: false,
    );
    return authProvider.user!.userId;
  }

  @override
  Widget build(BuildContext context) {
    // Get current user ID and token from old provider package
    final authProvider = provider_pkg.Provider.of<auth.AuthProvider>(context);
    final currentUserId = authProvider.user?.userId;
    final token = authProvider.token;

    if (currentUserId == null || token == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.otherUserName)),
        body: const Center(child: Text('Not authenticated')),
      );
    }

    if (!_notificationSettingsLoaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadNotificationSettings(token);
      });
    }

    // Watch messages for this chat (T042) - using localMessagesProvider for real-time updates
    final localMessagesKey = (
      chatId: widget.chatId,
      token: token,
      currentUserId: currentUserId,
    );
    _localMessagesNotifier = ref.read(
      localMessagesProvider(localMessagesKey).notifier,
    );
    final messages = ref.watch(localMessagesProvider(localMessagesKey));

    // Notify the notifier that this chat is now being viewed - new messages should be auto-read
    ref
        .read(
          localMessagesProvider((
            chatId: widget.chatId,
            token: token,
            currentUserId: currentUserId,
          )).notifier,
        )
        .setChatBeingViewed(true);
    _viewerActiveEnabled = true;

    // Auto-scroll to bottom when new messages arrive
    ref.listen(
      localMessagesProvider((
        chatId: widget.chatId,
        token: token,
        currentUserId: currentUserId,
      )),
      (previous, next) {
        // Only scroll if we actually have new messages
        if (previous != null && next.length > previous.length) {
          _scrollToBottom();
        }
      },
    );

    // Watch send message state
    final sendState = ref.watch(sendMessageProvider);
    ref.listen<SendMessageState>(sendMessageProvider, (previous, next) {
      if (next.error == null || next.error == previous?.error) {
        return;
      }

      AppFeedbackService.showError(next.error!);
      ref.read(sendMessageProvider.notifier).clearError();
    });

    // Watch message status updates via WebSocket (T020 - Message Status System)
    ref.watch(messageStatusUpdateProvider).whenData((statusUpdate) {
      if (statusUpdate != null) {
        final (:messageId, :newStatus, :chatId) = statusUpdate;
        debugPrint('[ChatDetail] 📡 Status update: $messageId -> $newStatus');

        // Handle status change via notifier
        if (authProvider.token != null) {
          ref
              .read(messageStatusNotifierProvider.notifier)
              .handleStatusChange(
                messageId,
                newStatus,
                chatId: chatId,
                token: authProvider.token!,
              );
        }
      }
    });

    // Watch typing indicator updates from WebSocket (T046)
    ref.watch(typingIndicatorUpdatesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                // Avatar with proper fallback handling
                UserAvatarWidget(
                  imageUrl: widget.otherUserAvatarUrl,
                  radius: 16,
                  username: widget.otherUserName,
                ),
                const SizedBox(width: 12),
                // Name
                Text(widget.otherUserName),
              ],
            ),
            Text(
              'Signed in as: ${_displayName(authProvider.user?.username)}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.blue[900],
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        centerTitle: false,
        elevation: 1,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'toggle_mute') {
                _toggleChatMute(token);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'toggle_mute',
                child: Row(
                  children: [
                    Icon(
                      _isChatMuted
                          ? Icons.notifications_active
                          : Icons.notifications_off,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isChatMuted
                          ? 'Unmute notifications'
                          : 'Mute notifications',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: _buildHeaderErrorBanner(),
      ),
      body: Column(
        children: [
          // Message history (T042, T025-T027)
          Expanded(
            child: _buildMessagesView(context, messages, token, currentUserId),
          ),

          // Typing indicator (T045, T047)
          Consumer(
            builder: (context, ref, child) {
              // Get current user ID
              final currentUserId = authProvider.user?.userId;

              // Watch typing users for this chat
              final typingUsers = ref.watch(
                typingUsersForChatProvider(widget.chatId),
              );

              // Filter out current user and map to usernames
              final typingUsernames = typingUsers
                  .where((user) => user.userId != currentUserId)
                  .map((user) => user.username)
                  .toList();

              return TypingIndicator(
                typingUsernames: typingUsernames,
                showIndicator: typingUsernames.isNotEmpty,
              );
            },
          ),

          // Message input box (T023, T024, T027, T044)
          MessageInputBox(
            onSend: (text) async {
              // Stop typing indicator when sending
              ref
                  .read(messageWebSocketProvider.notifier)
                  .stopTyping(widget.chatId);

              try {
                // Send message via provider (handles optimistic update automatically)
                await ref
                    .read(sendMessageProvider.notifier)
                    .sendMessage(
                      chatId: widget.chatId,
                      plaintext: text,
                      token: token,
                      currentUserId: currentUserId,
                    );

                _scrollToBottom();
              } catch (e) {
                debugPrint('[ChatDetail] Send error: $e');

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to send message: $e')),
                  );
                }
              }
            },
            isLoading: sendState.isLoading,
            // Typing event handlers (T044)
            onTypingStart: () {
              _sendTypingEvent('typing.start');
            },
            onTypingStop: () {
              _sendTypingEvent('typing.stop');
            },
            onTypingRefresh: () {
              _sendTypingEvent(
                'typing.start',
              ); // Refresh by sending start again
            },
            // Media attachment handlers (T078)
            onImageTap: () {
              _handleImageAttachment(token);
            },
            onVideoTap: () {
              _handleVideoAttachment(token);
            },
            onAudioTap: () {
              _handleAudioRecordingTap(token);
            },
            isRecordingAudio: _isRecordingAudio,
          ),
        ],
      ),
    );
  }

  /// Build the messages view
  Widget _buildMessagesView(
    BuildContext context,
    List<Message> messages,
    String token,
    String currentUserId,
  ) {
    // Combine server messages with local optimistic pending messages (T027)
    // Sort oldest first (natural order) - ListView shows top to bottom
    final allMessages = [...messages]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt)); // Oldest first

    if (allMessages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No messages yet',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Start a conversation!',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    // Schedule scroll to bottom after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });

    return ListView.builder(
      controller: _scrollController,
      itemCount: allMessages.length,
      itemBuilder: (context, index) {
        final message = allMessages[index];

        // Check if this is last message from same sender (show avatar)
        final isLastFromSender =
            index == allMessages.length - 1 ||
            allMessages[index + 1].senderId != message.senderId;

        // Check if this is first message from same sender (show name)
        final isFirstFromSender =
            index == 0 || allMessages[index - 1].senderId != message.senderId;

        return MessageBubble(
          key: ValueKey('${message.id}_${message.status}'),
          message: message,
          currentUserId: currentUserId,
          isFirstFromSender: isFirstFromSender,
          isLastFromSender: isLastFromSender,
          onRetry: message.hasError
              ? () => _handleRetry(message, token, currentUserId)
              : null,
          onLongPress: message.senderId == currentUserId
              ? () => _showMessageContextMenu(message, token)
              : null,
          onEdit: message.senderId == currentUserId
              ? (newContent) => _handleEditMessage(message, newContent, token)
              : null,
        );
      },
    );
  }
}
