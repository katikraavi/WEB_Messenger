import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/services/api_client.dart';
import 'package:frontend/core/notifications/app_feedback_service.dart';
import '../models/message_model.dart';
import '../services/chat_api_service.dart';
import '../services/message_encryption_service.dart';
import '../services/message_websocket_service.dart';
import './websocket_provider.dart';

/// Messages provider (T044, T036-T037)
///
/// Fetches messages for a specific chat with JWT token
/// Enhanced to reactively include messages received via WebSocket
final messagesProvider =
    FutureProvider.family<List<Message>, ({String chatId, String token})>((
      ref,
      params,
    ) async {
      final token = params.token;
      final chatId = params.chatId;

      if (token.isEmpty) {
        throw Exception('User not authenticated');
      }

      // Get API service
      final apiService = ChatApiService(baseUrl: ApiClient.getBaseUrl());

      // Fetch messages for this chat
      try {
        final messages = await apiService.fetchMessages(
          token: token,
          chatId: chatId,
          limit: 50,
        );
        return messages;
      } catch (e) {
        rethrow;
      }
    });

/// State notifier for locally managing messages
class LocalMessagesNotifier extends StateNotifier<List<Message>> {
  final String chatId;
  final String token;
  final String currentUserId; // Current user's ID to identify own messages
  StreamSubscription? _webSocketSubscription;
  bool _initialized = false;
  bool _isViewerActive = false; // Track if this chat is currently being viewed

  LocalMessagesNotifier({
    required this.chatId,
    required this.token,
    required this.currentUserId,
  }) : super([]) {
    // Don't initialize here - let the provider handle it
  }

  /// Set whether this chat is currently being viewed by the user
  void setChatBeingViewed(bool isActive) {
    _isViewerActive = isActive;

    // When viewer becomes active, mark all current unread messages as read
    if (isActive) {
      markAllUnreadAsRead();
    }
  }

  /// Mark all currently unread messages as read (called when chat becomes visible)
  Future<void> markAllUnreadAsRead() async {
    final unreadMessages = state
        .where(
          (m) =>
              m.status != 'read' &&
              m.senderId != currentUserId,
        )
        .toList();

    if (unreadMessages.isEmpty) {
      return;
    }


    // Mark each unread message as read
    for (final message in unreadMessages) {
      await markAsReadAndBroadcast(message.id, chatId);
    }
  }

  /// Initialize by loading messages from server (call this once)
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      await loadMessagesFromServer();
    } catch (e) {
    }
  }

  /// Setup WebSocket listener - called from provider after creation
  void setupWebSocketListener(MessageWebSocketService webSocket) {
    _webSocketSubscription = webSocket.eventStream.listen(
      (event) async {
        await _handleWebSocketEvent(event);
      },
      onError: (error) {
      },
      cancelOnError: false,
    );
  }

  /// Handle incoming WebSocket event
  Future<void> _handleWebSocketEvent(WebSocketEvent event) async {
    try {
      // Only process messages for this chat
      if (event.chatId != chatId) {
        return;
      }

      // Skip typing indicators FIRST - they come as messageCreated events but aren't real messages
      if (event.data.containsKey('type') &&
          event.data['type'] == 'typing_indicator') {
        return;
      }


      // Handle new messages
      if (event.type == WebSocketEventType.messageCreated) {
        try {
          // Parse the message
          final message = Message.fromJson(event.data);

          // Decrypt if encrypted (messages from WebSocket arrive encrypted)
          // IMPORTANT: Use senderId (who encrypted it), not currentUserId (who's receiving it)
          if (!message.isDecrypted && message.encryptedContent.isNotEmpty) {
            try {
              final decryptedMessage =
                  await MessageEncryptionService.decryptMessage(
                    message,
                    userId: message.senderId,
                  );
              addMessage(decryptedMessage);

              // AUTO-READ: If new message from other user AND chat is being viewed, mark as read
              if (decryptedMessage.senderId != currentUserId &&
                  _isViewerActive) {
                markAsReadAndBroadcast(decryptedMessage.id, chatId);
              }
            } catch (decryptError) {
              // Add message with decryption error
              addMessage(message);
            }
          } else {
            addMessage(message);
            // AUTO-READ: If new message from other user AND chat is being viewed, mark as read
            if (message.senderId != currentUserId && _isViewerActive) {
              markAsReadAndBroadcast(message.id, chatId);
            }
          }
        } catch (parseError) {
        }
      }
      // Handle message status updates (sent, delivered, read)
      else if (event.type == WebSocketEventType.messageStatusChanged) {
        final messageId = event.data['messageId'] as String?;
        final newStatus = event.data['newStatus'] as String?;
        final aggregateStatus = event.data['aggregateStatus'] as String?;
        final recipientCount = event.data['recipientCount'] as int?;
        final deliveredCount = event.data['deliveredCount'] as int?;
        final readCount = event.data['readCount'] as int?;

        if (messageId != null && newStatus != null) {
          updateMessageStatus(
            messageId,
            newStatus,
            aggregateStatus: aggregateStatus,
            recipientCount: recipientCount,
            deliveredCount: deliveredCount,
            readCount: readCount,
          );
        }
      } else if (event.type == WebSocketEventType.messageEdited) {
        final message = Message.fromJson(event.data);
        final decryptedMessage = await MessageEncryptionService.decryptMessage(
          message,
          userId: currentUserId,
        );
        upsertMessage(decryptedMessage);
      } else if (event.type == WebSocketEventType.messageDeleted) {
        final message = Message.fromJson(event.data);
        upsertMessage(message.copyWith(decryptedContent: '[Message deleted]'));
      }
    } catch (e) {
    }
  }

  /// Load messages from server
  Future<void> loadMessagesFromServer() async {
    try {
      final apiService = ChatApiService(baseUrl: ApiClient.getBaseUrl());

      final messages = await apiService.fetchMessages(
        token: token,
        chatId: chatId,
        limit: 50,
      );


      // Decrypt messages using AES-256-GCM with user-specific key
      final decryptedMessages = await MessageEncryptionService.decryptMessages(
        messages,
        userId: currentUserId,
      );

      // Sort by time (oldest first)
      decryptedMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      // Only set state if we haven't already added any WebSocket messages
      if (state.isEmpty) {
        state = decryptedMessages;
      } else {
        // Merge: add server messages that aren't already in state (from WebSocket)
        for (final msg in decryptedMessages) {
          if (!state.any((m) => m.id == msg.id)) {
            addMessage(msg);
          }
        }
      }

      // If the user is currently viewing this chat, ensure any unread incoming
      // messages loaded from server are immediately marked as read.
      if (_isViewerActive) {
        await markAllUnreadAsRead();
      }
    } catch (e) {
      AppFeedbackService.showWarning(
        state.isEmpty
            ? 'Could not load messages. Pull to retry.'
            : 'Could not refresh messages. Showing the last synced conversation.',
      );
      // Update state only if empty
      if (state.isEmpty) {
        state = [];
      }
    }
  }

  /// Add a new message to the list (received via WebSocket)
  void addMessage(Message message) {
    if (message.chatId == chatId) {
      // Check if message already exists by ID
      if (!state.any((m) => m.id == message.id)) {
        // Add message and keep sorted (oldest first)
        final updatedMessages = [...state, message];
        updatedMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        state = updatedMessages;

        // Debug: print message order
        if (state.length > 3) {
        }

        // Mark RECEIVED messages as delivered immediately
        // Only for messages from the OTHER person (senderId != currentUserId)
        // Messages we sent ourselves should not be marked as delivered by us
        if (message.senderId != currentUserId &&
            !message.id.startsWith('temp_') &&
            !message.isSending &&
            (message.status == 'sent' || message.status.isEmpty)) {
          _markMessageAsDelivered(message.id);
        }
      } else {
      }
    }
  }

  /// Mark a message as delivered via API
  void _markMessageAsDelivered(String messageId) {
    // Call the API to mark as delivered
    ChatApiService(baseUrl: ApiClient.getBaseUrl())
        .updateMessageStatus(
          token: token,
          chatId: chatId,
          messageId: messageId,
          newStatus: 'delivered',
        )
        .then((_) {
        })
        .catchError((e) {
        });
  }

  /// Remove optimistic message and add the server response
  void replaceOptimisticMessage(String tempId, Message serverMessage) {
    final messages = state.where((m) => m.id != tempId).toList();
    if (!messages.any((m) => m.id == serverMessage.id)) {
      messages.add(serverMessage);
    }
    messages.sort((a, b) => a.createdAt.compareTo(b.createdAt)); // Oldest first
    state = messages;
  }

  void upsertMessage(Message message) {
    final index = state.indexWhere((existing) => existing.id == message.id);
    if (index >= 0) {
      final updatedMessages = [...state];
      updatedMessages[index] = message;
      updatedMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      state = updatedMessages;
      return;
    }

    addMessage(message);
  }

  void markMessageDeleted(String messageId) {
    final index = state.indexWhere((message) => message.id == messageId);
    if (index < 0) {
      return;
    }

    final updatedMessages = [...state];
    updatedMessages[index] = updatedMessages[index].copyWith(
      isDeleted: true,
      deletedAt: DateTime.now().toUtc(),
      decryptedContent: '[Message deleted]',
    );
    state = updatedMessages;
  }

  /// Status hierarchy: sent (0) < delivered (1) < read (2)
  /// Returns true if newStatus is higher in hierarchy than currentStatus
  bool _isStatusUpgrade(String currentStatus, String newStatus) {
    const statusHierarchy = {'sent': 0, 'delivered': 1, 'read': 2};
    final currentLevel = statusHierarchy[currentStatus] ?? -1;
    final newLevel = statusHierarchy[newStatus] ?? -1;
    return newLevel > currentLevel;
  }

  /// Update message status - only allow status upgrades (sent → delivered → read), never downgrades
  void updateMessageStatus(
    String messageId,
    String newStatus, {
    String? aggregateStatus,
    int? recipientCount,
    int? deliveredCount,
    int? readCount,
  }) {
    final index = state.indexWhere((m) => m.id == messageId);
    if (index >= 0) {
      final updated = state[index];
      final nextStatus = updated.senderId == currentUserId
          ? (aggregateStatus ?? newStatus)
          : newStatus;
      final currentStatus = updated.status;

      // Only update if it's a genuine upgrade in status hierarchy
      if (_isStatusUpgrade(currentStatus, nextStatus)) {
        final newList = [...state];
        // Use copyWith to preserve all fields and just update status
        newList[index] = updated.copyWith(
          status: nextStatus,
          recipientCount: recipientCount,
          deliveredCount: deliveredCount,
          readCount: readCount,
        );
        state = newList;
      } else if (currentStatus == nextStatus) {
        final newList = [...state];
        newList[index] = updated.copyWith(
          recipientCount: recipientCount,
          deliveredCount: deliveredCount,
          readCount: readCount,
        );
        state = newList;
      } else {
      }
    } else {
    }
  }

  /// Mark message as read AND call API (for incoming messages when chat is open)
  Future<void> markAsReadAndBroadcast(String messageId, String chatId) async {
    try {
      final targetMessage = state.cast<Message?>().firstWhere(
            (message) => message?.id == messageId,
            orElse: () => null,
          );
      if (targetMessage == null) {
        return;
      }

      // First update local state
      updateMessageStatus(messageId, 'read');

      // Then call API to broadcast to sender
      final apiService = ChatApiService(baseUrl: ApiClient.getBaseUrl());
      await apiService.updateMessageStatus(
        token: token,
        chatId: chatId,
        messageId: messageId,
        newStatus: 'read',
      );
    } catch (e) {
    }
  }

  /// Cleanup resources
  @override
  void dispose() {
    _webSocketSubscription?.cancel();
    super.dispose();
  }
}

/// Local messages provider
final localMessagesProvider =
    StateNotifierProvider.family<
      LocalMessagesNotifier,
      List<Message>,
      ({String chatId, String token, String currentUserId})
    >((ref, params) {
      // Create the notifier with current user ID passed as parameter
      final notifier = LocalMessagesNotifier(
        chatId: params.chatId,
        token: params.token,
        currentUserId: params.currentUserId,
      );

      // Set up WebSocket listener FIRST (before loading messages)
      // This ensures any WebSocket events won't be lost when we set initial state
      final webSocket = ref.read(messageWebSocketProvider);
      notifier.setupWebSocketListener(webSocket);

      // Load messages from server AFTER WebSocket is set up
      // This prevents race conditions where WebSocket events are lost
      notifier
          .initialize()
          .then((_) {
          })
          .catchError((e) {
          });

      // Return the notifier - its state will be updated as messages load and arrive
      return notifier;
    });

/// Messages cache invalidator for a specific chat
final messagesCacheInvalidatorProvider = StateProvider.family<int, String>(
  (ref, chatId) => 0,
);

/// Messages provider with cache invalidation support (T036-T037)
///
/// Enhanced to reactively include messages received via WebSocket
/// and auto-update when new messages are received
final messagesWithCacheProvider =
    FutureProvider.family<List<Message>, ({String chatId, String token})>((
      ref,
      params,
    ) async {
      final chatId = params.chatId;
      final token = params.token;

      // Watch the cache invalidator to trigger refreshes
      ref.watch(messagesCacheInvalidatorProvider(chatId));

      // Set up a stream listener for WebSocket message events
      // This will invalidate cache when messages arrive in real-time
      Future.delayed(Duration.zero, () {
        try {
          final webSocket = ref.watch(messageWebSocketProvider);
          webSocket.eventStream.listen((event) {
            if (event.chatId == chatId &&
                (event.type == WebSocketEventType.messageCreated ||
                    event.type == WebSocketEventType.messageReceived)) {
              ref
                  .read(messagesCacheInvalidatorProvider(chatId).notifier)
                  .state++;
            }
          });
        } catch (e) {
        }
      });

      // Fetch messages
      final apiService = ChatApiService(baseUrl: ApiClient.getBaseUrl());

      try {
        final messages = await apiService.fetchMessages(
          token: token,
          chatId: chatId,
          limit: 50,
        );

        // Decrypt all messages using AES-256-GCM encryption service
        // Note: We don't have access to currentUserId here in this provider,
        // so we use the token to derive a temporary user context
        final encryptedMessages = messages;
        // For now, use a placeholder - in production this should be retrieved from auth context
        final currentUserId = 'user_from_token'; // TODO: Extract actual user ID from token
        final decryptedMessages =
            await MessageEncryptionService.decryptMessages(
              encryptedMessages,
              userId: currentUserId,
            );

        return decryptedMessages;
      } catch (e) {
        rethrow;
      }
    });

/// Edit message provider (T055, US4)
///
/// Allows editing an existing message with optimistic updates
final editMessageProvider =
    FutureProvider.family<Message, (String, String, String, String)>((
      ref,
      params,
    ) async {
      final chatId = params.$1;
      final messageId = params.$2;
      final newContent = params.$3;
      final token = params.$4;

      if (token.isEmpty) {
        throw Exception('User not authenticated');
      }

      final apiService = ChatApiService(baseUrl: ApiClient.getBaseUrl());

      try {

        final editedMessage = await apiService.editMessage(
          token: token,
          chatId: chatId,
          messageId: messageId,
          newEncryptedContent: newContent,
        );


        // Invalidate messages cache to refresh
        ref.invalidate(
          messagesWithCacheProvider((chatId: chatId, token: token)),
        );

        return editedMessage;
      } catch (e) {
        rethrow;
      }
    });

/// Delete message provider
///
/// Deletes a message by ID and invalidates the messages cache
final deleteMessageProvider =
    FutureProvider.family<void, (String, String, String)>((ref, params) async {
      final chatId = params.$1;
      final messageId = params.$2;
      final token = params.$3;

      if (token.isEmpty) {
        throw Exception('User not authenticated');
      }

      final apiService = ChatApiService(baseUrl: ApiClient.getBaseUrl());

      try {

        await apiService.deleteMessage(
          token: token,
          chatId: chatId,
          messageId: messageId,
        );


        // Invalidate messages cache to refresh
        ref.invalidate(
          messagesWithCacheProvider((chatId: chatId, token: token)),
        );
      } catch (e) {
        rethrow;
      }
    });
