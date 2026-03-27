import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:frontend/core/notifications/app_feedback_service.dart';
import 'package:frontend/core/services/api_client.dart';
import '../models/message_model.dart';
import '../services/chat_api_service.dart';
import '../services/message_encryption_service.dart';
import 'messages_provider.dart';

/// Send message state
class SendMessageState {
  final bool isLoading;
  final String? error;
  final String? lastSentMessageId;

  const SendMessageState({
    this.isLoading = false,
    this.error,
    this.lastSentMessageId,
  });

  bool get isError => error != null;

  SendMessageState copyWith({
    bool? isLoading,
    String? error,
    String? lastSentMessageId,
  }) {
    return SendMessageState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastSentMessageId: lastSentMessageId ?? this.lastSentMessageId,
    );
  }
}

/// Send message notifier (T043, T027)
/// 
/// Handles:
/// - Optimistic message updates (show message immediately with isSending=true)
/// - Simple base64 encoding for MVP (not production encryption)
/// - Calling API to send message
/// - Replacing optimistic message with server response
/// - Error handling with error state on message
/// 
/// Flow:
/// 1. Create optimistic message with isSending=true and temp ID
/// 2. Add to messages provider immediately for instant UI feedback
/// 3. Send HTTP POST request
/// 4. On success: Replace temp message with server response
/// 5. On failure: Mark message with error, keep for retry
class SendMessageNotifier extends StateNotifier<SendMessageState> {
  SendMessageNotifier(this.ref) : super(const SendMessageState());

  final Ref ref;

  static String get _baseUrl => ApiClient.getBaseUrl();

  /// Send a message to a chat with optimistic updates (T027)
  /// 
  /// Parameters:
  /// - chatId: The chat to send message to
  /// - plaintext: The message content (plaintext, will be base64 encoded)
  /// - token: JWT authentication token
  /// - currentUserId: The current user ID (sender)
  /// 
  /// Flow:
  /// 1. Create optimistic message with isSending=true
  /// 2. Add to messages list immediately
  /// 3. Send to server
  /// 4. Replace optimistic with real message on success
  /// 5. Mark with error on failure
  /// 
  /// Throws: Exception on critical errors
  Future<void> sendMessage({
    required String chatId,
    required String plaintext,
    required String token,
    required String currentUserId,
  }) async {
    final optimisticId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final optimisticCreatedAt = DateTime.now().toUtc();

    final optimisticMessage = Message(
      id: optimisticId,
      chatId: chatId,
      senderId: currentUserId,
      recipientId: '',
      encryptedContent: plaintext,
      status: 'sent',
      createdAt: optimisticCreatedAt,
      isSending: true,
      error: null,
      decryptionError: null,
    );

    await _sendMessageInternal(
      chatId: chatId,
      plaintext: plaintext,
      token: token,
      currentUserId: currentUserId,
      optimisticMessage: optimisticMessage,
      addOptimisticMessage: true,
    );
  }

  Future<void> retryMessage({
    required Message failedMessage,
    required String token,
    required String currentUserId,
  }) async {
    final plaintext = failedMessage.decryptedContent ?? failedMessage.encryptedContent;
    final retryingMessage = failedMessage.copyWith(
      senderId: currentUserId,
      isSending: true,
      error: null,
      decryptionError: null,
    );

    await _sendMessageInternal(
      chatId: failedMessage.chatId,
      plaintext: plaintext,
      token: token,
      currentUserId: currentUserId,
      optimisticMessage: retryingMessage,
      addOptimisticMessage: false,
    );
  }

  void clearError() {
    if (state.error == null) {
      return;
    }

    state = state.copyWith(error: null);
  }

  Future<void> _sendMessageInternal({
    required String chatId,
    required String plaintext,
    required String token,
    required String currentUserId,
    required Message optimisticMessage,
    required bool addOptimisticMessage,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      if (plaintext.isEmpty) {
        throw ArgumentError('Message cannot be empty');
      }

      if (plaintext.length > 5000) {
        throw ArgumentError('Message exceeds 5000 character limit');
      }

      if (addOptimisticMessage) {
        _updateMessagesOptimistic(chatId, token, currentUserId, optimisticMessage, isAdding: true);
      } else {
        _upsertLocalMessage(chatId, token, currentUserId, optimisticMessage);
      }

      // Encrypt message using AES-256-GCM (same as backend)
      final encryptedContent = await MessageEncryptionService.encryptMessage(
        plaintext,
        currentUserId,
      );
      final apiService = ChatApiService(baseUrl: _baseUrl);

      final sentMessage = await apiService.sendMessage(
        token: token,
        chatId: chatId,
        encryptedContent: encryptedContent,
      );

      // Decrypt received message for local display
      // Use sentMessage.senderId to decrypt (it's the sender's key)
      final decryptedMessage = await MessageEncryptionService.decryptMessage(
        sentMessage,
        userId: sentMessage.senderId,
      );

      _updateMessagesOptimistic(
        chatId,
        token,
        currentUserId,
        decryptedMessage,
        isAdding: false,
        replaceId: optimisticMessage.id,
      );

      state = state.copyWith(
        isLoading: false,
        lastSentMessageId: sentMessage.id,
      );
    } catch (e, st) {

      final errorMessage = e.toString();
      final failedMessage = optimisticMessage.copyWith(
        isSending: false,
        error: errorMessage,
      );

      _updateMessagesOptimistic(
        chatId,
        token,
        currentUserId,
        failedMessage,
        isAdding: false,
        replaceId: optimisticMessage.id,
      );

      state = state.copyWith(
        isLoading: false,
        error: errorMessage,
      );

      AppFeedbackService.showError(
        'Message was not sent. Use Send again to retry.',
      );
    }
  }

  void _upsertLocalMessage(
    String chatId,
    String token,
    String currentUserId,
    Message message,
  ) {
    try {
      final cacheKey = (chatId: chatId, token: token, currentUserId: currentUserId);
      final messagesNotifier = ref.read(localMessagesProvider(cacheKey).notifier);
      messagesNotifier.upsertMessage(message);
    } catch (e) {
    }
  }

  /// Update messages list with optimistic message (T027)
  /// 
  /// This method immediately updates the local messages list
  /// by directly adding to the notifier state
  void _updateMessagesOptimistic(
    String chatId,
    String token,
    String currentUserId,
    Message message, {
    required bool isAdding,
    String? replaceId,
  }) {
    try {
      // Get the local messages notifier for this chat
      final cacheKey = (chatId: chatId, token: token, currentUserId: currentUserId);
      final messagesNotifier = ref.read(localMessagesProvider(cacheKey).notifier);
      
      if (isAdding) {
        // Add new optimistic message directly to the notifier
        messagesNotifier.addMessage(message);
      } else if (replaceId != null) {
        // Replace optimistic message with server response
        messagesNotifier.replaceOptimisticMessage(replaceId, message);
      }
    } catch (e) {
      // Continue anyway - message will still appear from server
    }
  }
}

/// Send message provider (T043, T027)
final sendMessageProvider =
    StateNotifierProvider<SendMessageNotifier, SendMessageState>((ref) {
  return SendMessageNotifier(ref);
});
