import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../models/chat_model.dart';
import 'chats_provider.dart';
import '../services/message_websocket_service.dart';
import '../services/message_encryption_service.dart';
import '../models/message_model.dart';
import 'dart:convert';

/// Provider for active (unarchived) chats
/// 
/// For MVP: Requires passing JWT token
final activeChatListProvider = StreamProvider.family<List<Chat>, String>((ref, token) async* {
  // Await initial chat list
  final chats = await ref.watch(chatsProvider(token).future);
  final apiService = ref.read(chatApiServiceProvider);
  List<Chat> enrichedChats = await Future.wait(chats.map((chat) async {
    // If chat already has preview, use it
    if (chat.lastMessagePreview != null && chat.lastMessagePreview!.isNotEmpty) {
      return chat;
    }
    // Fetch latest message for chat
    final messages = await apiService.fetchMessages(token: token, chatId: chat.id, limit: 1);
    if (messages.isNotEmpty) {
      final msg = messages.first;
      String preview = '';
      try {
        preview = utf8.decode(base64Decode(msg.encryptedContent));
      } catch (_) {
        preview = '[Encrypted]';
      }
      return Chat(
        id: chat.id,
        participant1Id: chat.participant1Id,
        participant2Id: chat.participant2Id,
        isParticipant1Archived: chat.isParticipant1Archived,
        isParticipant2Archived: chat.isParticipant2Archived,
        createdAt: chat.createdAt,
        updatedAt: chat.updatedAt,
        lastMessagePreview: preview,
        lastMessageTimestamp: msg.createdAt,
        lastMessageSenderAvatarUrl: msg.senderId,
        lastMessageStatus: msg.status,
      );
    }
    return chat;
  }).toList());
  enrichedChats.sort((a, b) {
    final aTime = a.lastMessageTimestamp ?? a.updatedAt;
    final bTime = b.lastMessageTimestamp ?? b.updatedAt;
    return bTime.compareTo(aTime);
  });
  yield enrichedChats;

  // Listen to WebSocket events using .stream
  final wsEventStream = ref.watch(chatWebSocketEventProvider.stream);
  await for (final event in wsEventStream) {
    if (event.type == WebSocketEventType.messageCreated || event.type == WebSocketEventType.messageStatusChanged) {
      final chatId = event.chatId;
      try {
        // Always fetch the latest message for the affected chat
        final messages = await apiService.fetchMessages(token: token, chatId: chatId, limit: 1);
        if (messages.isNotEmpty) {
          final msg = messages.first;
          String preview = '';
          try {
            preview = utf8.decode(base64Decode(msg.encryptedContent));
          } catch (_) {
            preview = '[Encrypted]';
          }
          enrichedChats = enrichedChats.map((chat) {
            if (chat.id == chatId) {
              return Chat(
                id: chat.id,
                participant1Id: chat.participant1Id,
                participant2Id: chat.participant2Id,
                isParticipant1Archived: chat.isParticipant1Archived,
                isParticipant2Archived: chat.isParticipant2Archived,
                createdAt: chat.createdAt,
                updatedAt: chat.updatedAt,
                lastMessagePreview: preview,
                lastMessageTimestamp: msg.createdAt,
                lastMessageSenderAvatarUrl: msg.senderId,
                lastMessageStatus: msg.status,
              );
            }
            return chat;
          }).toList();
          // Re-sort
          enrichedChats.sort((a, b) {
            final aTime = a.lastMessageTimestamp ?? a.updatedAt;
            final bTime = b.lastMessageTimestamp ?? b.updatedAt;
            return bTime.compareTo(aTime);
          });
          yield enrichedChats;
        }
      } catch (e) {
        // Skip errors (e.g., 403 if user is not a participant in this chat)
        debugPrint('[ActiveChatListProvider] Error fetching messages for chat $chatId: $e');
      }
    }
  }
});

/// Provider for archived chats
final archivedChatListProvider = FutureProvider.family<List<Chat>, String>((ref, token) async {
  // Get all chats
  final chats = await ref.watch(chatsProvider(token).future);
  // Filter to archived (would need to know current user ID from UI)
  return [];
});

/// StreamProvider for WebSocket events
final chatWebSocketEventProvider = StreamProvider<WebSocketEvent>((ref) {
  final wsService = MessageWebSocketService();
  return wsService.eventStream;
});
