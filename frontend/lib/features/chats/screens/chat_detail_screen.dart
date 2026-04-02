import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as provider_pkg;
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'package:frontend/core/notifications/app_feedback_service.dart';
import 'package:frontend/core/services/app_exception_logger.dart';
import 'package:frontend/core/services/api_client.dart';
import '../models/message_model.dart' show Message;
import '../providers/messages_provider.dart';
import '../providers/message_status_provider.dart';
import '../providers/send_message_provider.dart';
import '../providers/typing_indicator_provider.dart';
import '../providers/websocket_provider.dart';
import '../services/chat_api_service.dart';
import '../services/message_encryption_service.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_input_box.dart';
import '../widgets/typing_indicator.dart';
import '../widgets/edit_message_dialog.dart';
import '../widgets/user_avatar_widget.dart';
import '../services/media_picker_service.dart';
import '../services/media_upload_service.dart';
import '../services/message_encryption_service.dart';
import '../services/chat_notification_settings_service.dart';
import '../widgets/message_search_bar.dart';
import '../services/message_search_service.dart';
import 'group_chat_screen.dart';
import '../../auth/providers/auth_provider.dart' as auth;
import '../../invitations/services/group_invite_service.dart';

part 'chat_detail_screen_handlers.dart';

String _displayName(String? value) {
  if (value == null || value.isEmpty) {
    return 'Unknown';
  }

  return value[0].toUpperCase() + value.substring(1);
}

String get _backendBaseUrl => ApiClient.getBaseUrl();

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

  /// Whether this thread is a group conversation.
  final bool isGroup;

  const ChatDetailScreen({
    Key? key,
    required this.chatId,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserAvatarUrl,
    this.isGroup = false,
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
  bool _isChatMuted = false;
  bool _notificationSettingsLoaded = false;
  String? _headerErrorMessage;
  bool _showReconnectAction = false;
  bool _isReconnectInProgress = false;
  Map<String, String> _groupMemberUsernamesById = const {};

  // Message search state (T020 / GAP-003)
  bool _searchActive = false;
  List<String> _searchResultIds = [];
  int _searchResultIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  final MessageSearchService _messageSearchService = MessageSearchService(
    baseUrl: _backendBaseUrl,
  );

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
        return;
      }

      // Get the websocket service from riverpod
      // Connect if not already connected
      if (!ref.read(messageWebSocketProvider).isConnected) {
        await _webSocketNotifier.connect(token: token, userId: userId);
      }

      // Subscribe to this chat
      _webSocketNotifier.subscribeToChat(widget.chatId);
      await _loadGroupMemberUsernames(token);
      await _reloadMessagesAfterReconnect();
      _clearHeaderError();
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

  Future<void> _loadGroupMemberUsernames(String token) async {
    if (!widget.isGroup) {
      return;
    }

    try {
      final service = GroupInviteService(baseUrl: _backendBaseUrl);
      final members = await service.fetchGroupMembers(
        token: token,
        groupId: widget.chatId,
      );

      if (!mounted) {
        return;
      }

      final map = <String, String>{
        for (final member in members)
          member.userId: member.username,
      };

      setState(() {
        _groupMemberUsernamesById = map;
      });
    } catch (_) {
      // Keep chat usable even if member lookup fails.
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

  bool _useWideWebLayout(BuildContext context) {
    return kIsWeb && MediaQuery.sizeOf(context).width >= 1100;
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
    _searchController.dispose();

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
    if (_viewerActiveEnabled) {
      try {
        if (_localMessagesNotifier != null) {
          // Disable viewer mode - new messages should NOT auto-read
          _localMessagesNotifier!.setChatBeingViewed(false);
          _viewerActiveEnabled = false;
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
          ref.read(
            autoMarkAsReadProvider((
              chatId: widget.chatId,
              token: authProvider.token!,
              currentUserId: authProvider.user!.userId,
              isGroup: widget.isGroup,
            )),
          );
        }
      }
    });
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

    if (!widget.isGroup && !_notificationSettingsLoaded) {
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
        // Handle status change via notifier
        if (authProvider.token != null) {
          ref
              .read(messageStatusNotifierProvider.notifier)
              .handleStatusChange(
                statusUpdate.messageId,
                statusUpdate.newStatus,
                chatId: statusUpdate.chatId,
                token: authProvider.token!,
              );
        }
      }
    });

    // Watch typing indicator updates from WebSocket (T046)
    ref.watch(typingIndicatorUpdatesProvider);

    final useWideWebLayout = _useWideWebLayout(context);

    return Scaffold(
      backgroundColor: useWideWebLayout ? const Color(0xFFF5F8FE) : null,
      appBar: AppBar(
        backgroundColor: useWideWebLayout ? Colors.white : null,
        titleSpacing: useWideWebLayout ? 20 : null,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                widget.isGroup
                    ? CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.indigo.shade100,
                        child: const Icon(
                          Icons.group,
                          color: Colors.indigo,
                          size: 18,
                        ),
                      )
                    : UserAvatarWidget(
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
              widget.isGroup
                  ? 'Group conversation'
                  : 'Signed in as: ${_displayName(authProvider.user?.username)}',
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
          // Search icon - available for both direct and group chats
          IconButton(
            icon: Icon(_searchActive ? Icons.search_off : Icons.search),
            tooltip: _searchActive ? 'Close search' : 'Search messages',
            onPressed: () {
              setState(() {
                _searchActive = !_searchActive;
                if (!_searchActive) {
                  _searchResultIds = [];
                  _searchResultIndex = 0;
                  _searchController.clear();
                }
              });
            },
          ),
          if (widget.isGroup) ...[
            // View members button
            IconButton(
              icon: const Icon(Icons.group),
              tooltip: 'View members',
              onPressed: () {
                final size = MediaQuery.sizeOf(context);
                final dialogWidth =
                    (size.width * 0.9).clamp(340.0, 920.0).toDouble();
                final dialogHeight =
                    (size.height * 0.86).clamp(420.0, 760.0).toDouble();

                showDialog<void>(
                  context: context,
                  barrierDismissible: true,
                  builder: (dialogContext) {
                    return Dialog(
                      insetPadding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 24,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: SizedBox(
                        width: dialogWidth,
                        height: dialogHeight,
                        child: GroupChatScreen(
                          groupId: widget.chatId,
                          initialGroupName: widget.otherUserName,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ]
          else
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
      body: Container(
        decoration: useWideWebLayout
            ? const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFF5F8FE), Color(0xFFEDF4FF)],
                ),
              )
            : null,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: useWideWebLayout ? 1080 : double.infinity,
            ),
            child: Container(
              margin: EdgeInsets.fromLTRB(
                useWideWebLayout ? 16 : 0,
                useWideWebLayout ? 16 : 0,
                useWideWebLayout ? 16 : 0,
                0,
              ),
              decoration: BoxDecoration(
                color: useWideWebLayout
                    ? Colors.white.withValues(alpha: 0.9)
                    : null,
                borderRadius: BorderRadius.circular(useWideWebLayout ? 24 : 0),
                border: useWideWebLayout
                    ? Border.all(color: const Color(0xFFE1EAF7))
                    : null,
                boxShadow: useWideWebLayout
                    ? [
                        BoxShadow(
                          color: Colors.blueGrey.withValues(alpha: 0.06),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                children: [
                  // Message search bar (T020 / GAP-003)
                  if (_searchActive)
                    MessageSearchBar(
                      controller: _searchController,
                      onQueryChanged: (query) async {
                        final trimmed = query.trim();
                        setState(() {
                          _searchResultIndex = 0;
                        });
                        if (trimmed.length >= 2) {
                          final results = await _messageSearchService
                              .searchMessages(
                                chatId: widget.chatId,
                                query: trimmed,
                                token: token,
                              );
                          if (mounted) {
                            setState(() {
                              _searchResultIds = results
                                  .map((r) => r.messageId)
                                  .toList();
                              _searchResultIndex = 0;
                            });
                          }
                        } else {
                          setState(() {
                            _searchResultIds = [];
                            _searchResultIndex = 0;
                          });
                        }
                      },
                      totalResults: _searchResultIds.length,
                      currentIndex: _searchResultIndex,
                      onNext: () {
                        if (_searchResultIds.isNotEmpty) {
                          setState(() {
                            _searchResultIndex =
                                (_searchResultIndex + 1) %
                                _searchResultIds.length;
                          });
                        }
                      },
                      onPrevious: () {
                        if (_searchResultIds.isNotEmpty) {
                          setState(() {
                            _searchResultIndex =
                                (_searchResultIndex -
                                    1 +
                                    _searchResultIds.length) %
                                _searchResultIds.length;
                          });
                        }
                      },
                      onClose: () {
                        setState(() {
                          _searchActive = false;
                          _searchResultIds = [];
                          _searchResultIndex = 0;
                        });
                        _searchController.clear();
                      },
                    ),
                  // Message history (T042, T025-T027)
                  // Message history (T042, T025-T027)
                  Expanded(
                    child: _buildMessagesView(
                      context,
                      messages,
                      token,
                      currentUserId,
                    ),
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
                  Container(
                    padding: EdgeInsets.fromLTRB(
                      useWideWebLayout ? 12 : 0,
                      useWideWebLayout ? 8 : 8,
                      useWideWebLayout ? 12 : 0,
                      useWideWebLayout ? 12 : 24,
                    ),
                    decoration: BoxDecoration(
                      color: useWideWebLayout ? const Color(0xFFF9FBFF) : null,
                      border: useWideWebLayout
                          ? const Border(
                              top: BorderSide(color: Color(0xFFE1EAF7)),
                            )
                          : null,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(useWideWebLayout ? 24 : 0),
                        bottomRight: Radius.circular(useWideWebLayout ? 24 : 0),
                      ),
                    ),
                    child: MessageInputBox(
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
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to send message: $e'),
                              ),
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
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
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
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          decoration: BoxDecoration(
            color: const Color(0xFFF7FAFF),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE1EAF7)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No messages yet',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 8),
              Text(
                widget.isGroup
                    ? 'Start the group conversation!'
                    : 'Start a conversation!',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    // Schedule scroll to bottom after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(kIsWeb ? 12 : 0, 12, kIsWeb ? 12 : 0, 16),
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
          authToken: token,
          isGroupChat: widget.isGroup,
          senderNameOverride: widget.isGroup
              ? _groupMemberUsernamesById[message.senderId]
              : null,
          isFirstFromSender: isFirstFromSender,
          isLastFromSender: isLastFromSender,
          isCurrentSearchResult: _searchActive && 
              _searchResultIds.isNotEmpty && 
              _searchResultIndex < _searchResultIds.length &&
              _searchResultIds[_searchResultIndex] == message.id,
          isOtherSearchResult: _searchActive && 
              _searchResultIds.contains(message.id) &&
              !(_searchResultIndex < _searchResultIds.length && 
                _searchResultIds[_searchResultIndex] == message.id),
          searchQuery: _searchActive ? _searchController.text : '',
          onRetry: message.hasError
              ? () => _handleRetry(message, token, currentUserId)
              : null,
          onLongPress: message.senderId == currentUserId && !message.isDeleted
              ? () => _showMessageContextMenu(message, token)
              : null,
          onEdit: message.senderId == currentUserId && !message.isDeleted
              ? (newContent) => _handleEditMessage(message, newContent, token)
              : null,
        );
      },
    );
  }
}

/// Renders a poll embedded in a chat message.
///
/// Expects [message.decryptedContent] to be JSON with at minimum
/// `{"pollId": "<uuid>"}`.
