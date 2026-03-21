import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      final apiService = ChatApiService(baseUrl: 'http://localhost:8081');

      // Fetch messages for this chat
      try {
        final messages = await apiService.fetchMessages(
          token: token,
          chatId: chatId,
          limit: 50,
        );
        return messages;
      } catch (e) {
        print('[MessagesProvider] Error fetching messages: $e');
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
    print(
      '[LocalMessagesNotifier] 👁️ Chat $chatId viewer active: $_isViewerActive',
    );

    // When viewer becomes active, mark all current unread messages as read
    if (isActive) {
      print(
        '[LocalMessagesNotifier] 📖 Viewer activated - marking all unread messages as read',
      );
      markAllUnreadAsRead();
    }
  }

  /// Mark all currently unread messages as read (called when chat becomes visible)
  Future<void> markAllUnreadAsRead() async {
    final unreadMessages = state
        .where((m) => m.status != 'read' && m.senderId != currentUserId)
        .toList();

    if (unreadMessages.isEmpty) {
      print('[LocalMessagesNotifier] ℹ️ No unread messages to mark');
      return;
    }

    print(
      '[LocalMessagesNotifier] 📋 Marking ${unreadMessages.length} unread messages as read',
    );

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
      print('[LocalMessagesNotifier] ❌ Error during initialization: $e');
    }
  }

  /// Setup WebSocket listener - called from provider after creation
  void setupWebSocketListener(MessageWebSocketService webSocket) {
    _webSocketSubscription = webSocket.eventStream.listen(
      (event) async {
        await _handleWebSocketEvent(event);
      },
      onError: (error) {
        print('[LocalMessagesNotifier] ⚠️ WebSocket stream error: $error');
      },
      cancelOnError: false,
    );
  }

  /// Handle incoming WebSocket event
  Future<void> _handleWebSocketEvent(WebSocketEvent event) async {
    try {
      // Only process messages for this chat
      if (event.chatId != chatId) {
        print(
          '[LocalMessagesNotifier] ⏭️ Ignoring event for different chat: ${event.chatId} != $chatId',
        );
        return;
      }

      // Skip typing indicators FIRST - they come as messageCreated events but aren't real messages
      if (event.data.containsKey('type') &&
          event.data['type'] == 'typing_indicator') {
        print('[LocalMessagesNotifier] ⏭️ Skipping typing indicator');
        return;
      }

      print(
        '[LocalMessagesNotifier] 📥 Received WebSocket event for chat $chatId (type: ${event.type})',
      );

      // Handle new messages
      if (event.type == WebSocketEventType.messageCreated) {
        try {
          // Parse the message
          final message = Message.fromJson(event.data);
          print('[LocalMessagesNotifier] ✅ Parsed message: ${message.id}');

          // Decrypt if encrypted (messages from WebSocket arrive encrypted)
          if (!message.isDecrypted && message.encryptedContent.isNotEmpty) {
            try {
              final decryptedMessage =
                  await MessageEncryptionService.decryptMessage(message);
              print(
                '[LocalMessagesNotifier] 🔓 Decrypted message: ${message.id}',
              );
              addMessage(decryptedMessage);

              // AUTO-READ: If new message from other user AND chat is being viewed, mark as read
              if (decryptedMessage.senderId != currentUserId &&
                  _isViewerActive) {
                print(
                  '[LocalMessagesNotifier] 🔵 Incoming message from other user while chat active: ${decryptedMessage.senderId}',
                );
                print(
                  '[LocalMessagesNotifier] 🟨 Auto-marking as read: ${decryptedMessage.id}',
                );
                markAsReadAndBroadcast(decryptedMessage.id, chatId);
              }
            } catch (decryptError) {
              print(
                '[LocalMessagesNotifier] ❌ Decryption failed: $decryptError',
              );
              // Add message with decryption error
              addMessage(message);
            }
          } else {
            addMessage(message);
            // AUTO-READ: If new message from other user AND chat is being viewed, mark as read
            if (message.senderId != currentUserId && _isViewerActive) {
              print(
                '[LocalMessagesNotifier] 🔵 Incoming message from other user while chat active: ${message.senderId}',
              );
              print(
                '[LocalMessagesNotifier] 🟨 Auto-marking as read: ${message.id}',
              );
              markAsReadAndBroadcast(message.id, chatId);
            }
          }
        } catch (parseError) {
          print('[LocalMessagesNotifier] ❌ Error parsing message: $parseError');
          print('[LocalMessagesNotifier] Event data: ${event.data}');
        }
      }
      // Handle message status updates (sent, delivered, read)
      else if (event.type == WebSocketEventType.messageStatusChanged) {
        final messageId = event.data['messageId'] as String?;
        final newStatus = event.data['newStatus'] as String?;

        if (messageId != null && newStatus != null) {
          print(
            '[LocalMessagesNotifier] 📨 Status update: $messageId → $newStatus',
          );
          updateMessageStatus(messageId, newStatus);
        }
      }
    } catch (e) {
      print('[LocalMessagesNotifier] ❌ Error handling WebSocket event: $e');
    }
  }

  /// Load messages from server
  Future<void> loadMessagesFromServer() async {
    try {
      final apiService = ChatApiService(baseUrl: 'http://localhost:8081');

      final messages = await apiService.fetchMessages(
        token: token,
        chatId: chatId,
        limit: 50,
      );

      print(
        '[LocalMessagesNotifier] 📥 Fetched ${messages.length} messages from server',
      );

      // Decrypt messages
      final decryptedMessages = await MessageEncryptionService.decryptMessages(
        messages,
      );

      // Sort by time (oldest first)
      decryptedMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      // Only set state if we haven't already added any WebSocket messages
      if (state.isEmpty) {
        state = decryptedMessages;
        print(
          '[LocalMessagesNotifier] ✅ Set initial ${decryptedMessages.length} messages',
        );
      } else {
        // Merge: add server messages that aren't already in state (from WebSocket)
        for (final msg in decryptedMessages) {
          if (!state.any((m) => m.id == msg.id)) {
            addMessage(msg);
          }
        }
        print(
          '[LocalMessagesNotifier] ✅ Merged ${decryptedMessages.length} messages (${state.length} total)',
        );
      }

      // If the user is currently viewing this chat, ensure any unread incoming
      // messages loaded from server are immediately marked as read.
      if (_isViewerActive) {
        print(
          '[LocalMessagesNotifier] 👁️ Viewer active after load - marking unread messages as read',
        );
        await markAllUnreadAsRead();
      }
    } catch (e) {
      print('[LocalMessagesNotifier] ❌ Error loading messages: $e');
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
        print('[LocalMessagesNotifier] ✅ Added new message: ${message.id}');
        print('[LocalMessagesNotifier] 📊 Message order (first 2, last 2):');
        if (state.length > 3) {
          print(
            '[LocalMessagesNotifier]   Index 0: ${state[0].id} - ${state[0].createdAt}',
          );
          print(
            '[LocalMessagesNotifier]   Index 1: ${state[1].id} - ${state[1].createdAt}',
          );
          print(
            '[LocalMessagesNotifier]   Index ${state.length - 2}: ${state[state.length - 2].id} - ${state[state.length - 2].createdAt}',
          );
          print(
            '[LocalMessagesNotifier]   Index ${state.length - 1}: ${state[state.length - 1].id} - ${state[state.length - 1].createdAt}',
          );
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
        print(
          '[LocalMessagesNotifier] ℹ️ Message already exists: ${message.id}',
        );
      }
    }
  }

  /// Mark a message as delivered via API
  void _markMessageAsDelivered(String messageId) {
    // Call the API to mark as delivered
    ChatApiService(baseUrl: 'http://localhost:8081')
        .updateMessageStatus(
          token: token,
          chatId: chatId,
          messageId: messageId,
          newStatus: 'delivered',
        )
        .then((_) {
          print('[LocalMessagesNotifier] 📦 Marked $messageId as delivered');
        })
        .catchError((e) {
          print(
            '[LocalMessagesNotifier] ⚠️ Error marking $messageId as delivered: $e',
          );
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
    print(
      '[LocalMessagesNotifier] ✓ Replaced optimistic message $tempId with ${serverMessage.id}',
    );
  }

  void upsertMessage(Message message) {
    final index = state.indexWhere((existing) => existing.id == message.id);
    if (index >= 0) {
      final updatedMessages = [...state];
      updatedMessages[index] = message;
      updatedMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      state = updatedMessages;
      print(
        '[LocalMessagesNotifier] 🔄 Updated existing message: ${message.id}',
      );
      return;
    }

    addMessage(message);
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
  void updateMessageStatus(String messageId, String newStatus) {
    final index = state.indexWhere((m) => m.id == messageId);
    if (index >= 0) {
      final updated = state[index];
      final currentStatus = updated.status;

      // Only update if it's a genuine upgrade in status hierarchy
      if (_isStatusUpgrade(currentStatus, newStatus)) {
        print(
          '[LocalMessagesNotifier] 📦 Status upgrade: $messageId $currentStatus → $newStatus',
        );
        final newList = [...state];
        // Use copyWith to preserve all fields and just update status
        newList[index] = updated.copyWith(status: newStatus);
        state = newList;
        print(
          '[LocalMessagesNotifier] ✅ State updated for $messageId, new status: ${newList[index].status}',
        );
      } else if (currentStatus == newStatus) {
        print(
          '[LocalMessagesNotifier] ℹ️ Status already $currentStatus for $messageId, no change needed',
        );
      } else {
        print(
          '[LocalMessagesNotifier] ⏸️ Skipping downgrade: $currentStatus → $newStatus for $messageId (keeping $currentStatus)',
        );
      }
    } else {
      print(
        '[LocalMessagesNotifier] ⚠️ Message not found: $messageId (total messages: ${state.length})',
      );
    }
  }

  /// Mark message as read AND call API (for incoming messages when chat is open)
  Future<void> markAsReadAndBroadcast(String messageId, String chatId) async {
    try {
      print(
        '[LocalMessagesNotifier] 🔴 markAsReadAndBroadcast called for $messageId',
      );

      // First update local state
      updateMessageStatus(messageId, 'read');

      // Then call API to broadcast to sender
      final apiService = ChatApiService(baseUrl: 'http://localhost:8081');
      print(
        '[LocalMessagesNotifier] 📤 Calling API to mark $messageId as read and broadcast...',
      );
      await apiService.updateMessageStatus(
        token: token,
        chatId: chatId,
        messageId: messageId,
        newStatus: 'read',
      );
      print(
        '[LocalMessagesNotifier] ✅ API call success: $messageId marked as read',
      );
    } catch (e) {
      print('[LocalMessagesNotifier] ⚠️ Error marking $messageId as read: $e');
    }
  }

  /// Cleanup resources
  @override
  void dispose() {
    _webSocketSubscription?.cancel();
    print('[LocalMessagesNotifier] ✅ Disposed WebSocket subscription');
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
            print(
              '[LocalMessagesProvider] ✅ Notifier initialized for chat ${params.chatId}',
            );
          })
          .catchError((e) {
            print('[LocalMessagesProvider] ❌ Initialization error: $e');
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
            print(
              '[MessagesWithCacheProvider] 📨 WebSocket event: ${event.type.name} for chat ${event.chatId}',
            );
            if (event.chatId == chatId &&
                (event.type == WebSocketEventType.messageCreated ||
                    event.type == WebSocketEventType.messageReceived)) {
              print(
                '[MessagesWithCacheProvider] 🔄 Invalidating cache for chat $chatId',
              );
              ref
                  .read(messagesCacheInvalidatorProvider(chatId).notifier)
                  .state++;
            }
          });
        } catch (e) {
          print('[MessagesWithCacheProvider] Error setting up listener: $e');
        }
      });

      // Fetch messages
      final apiService = ChatApiService(baseUrl: 'http://localhost:8081');

      try {
        print(
          '[MessagesWithCacheProvider] 🔄 Fetching messages for chat $chatId...',
        );
        final messages = await apiService.fetchMessages(
          token: token,
          chatId: chatId,
          limit: 50,
        );

        // Decrypt all messages using the encryption service
        final encryptedMessages = messages;
        final decryptedMessages =
            await MessageEncryptionService.decryptMessages(encryptedMessages);

        print(
          '[MessagesWithCacheProvider] ✓ Fetched and decrypted ${decryptedMessages.length} messages',
        );
        return decryptedMessages;
      } catch (e) {
        print('[MessagesWithCacheProvider] Error fetching messages: $e');
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

      final apiService = ChatApiService(baseUrl: 'http://localhost:8081');

      try {
        print(
          '[EditMessageProvider] 📝 Editing message $messageId with new content',
        );

        final editedMessage = await apiService.editMessage(
          token: token,
          chatId: chatId,
          messageId: messageId,
          newEncryptedContent: newContent,
        );

        print('[EditMessageProvider] ✓ Message edited successfully');

        // Invalidate messages cache to refresh
        ref.invalidate(
          messagesWithCacheProvider((chatId: chatId, token: token)),
        );

        return editedMessage;
      } catch (e) {
        print('[EditMessageProvider] ❌ Error editing message: $e');
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

      final apiService = ChatApiService(baseUrl: 'http://localhost:8081');

      try {
        print('[DeleteMessageProvider] 🗑️ Deleting message $messageId');

        await apiService.deleteMessage(
          token: token,
          chatId: chatId,
          messageId: messageId,
        );

        print('[DeleteMessageProvider] ✓ Message deleted successfully');

        // Invalidate messages cache to refresh
        ref.invalidate(
          messagesWithCacheProvider((chatId: chatId, token: token)),
        );
      } catch (e) {
        print('[DeleteMessageProvider] ❌ Error deleting message: $e');
        rethrow;
      }
    });
