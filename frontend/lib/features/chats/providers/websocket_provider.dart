import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/message_websocket_service.dart';

/// WebSocket service provider (singleton)
final messageWebSocketProvider =
    StateNotifierProvider<WebSocketNotifier, MessageWebSocketService>(
      (ref) => WebSocketNotifier(),
    );

/// WebSocket state notifier
class WebSocketNotifier extends StateNotifier<MessageWebSocketService> {
  WebSocketNotifier() : super(MessageWebSocketService());

  /// Connect to WebSocket
  Future<void> connect({
    required String token,
    required String userId,
  }) async {
    try {
      await state.connect(
        token: token,
        userId: userId,
        baseUrl: 'ws://localhost:8081',
      );
    } catch (e) {
      print('[WebSocketNotifier] Error connecting: $e');
      rethrow;
    }
  }

  /// Subscribe to a chat
  void subscribeToChat(String chatId) {
    state.subscribeToChat(chatId);
  }

  /// Unsubscribe from chat
  void unsubscribeFromChat() {
    state.unsubscribeFromChat();
  }

  /// Send typing indicator
  void sendTyping(String chatId) {
    state.sendTyping(chatId: chatId);
  }

  /// Stop typing
  void stopTyping(String chatId) {
    state.sendStoppedTyping(chatId: chatId);
  }

  /// Disconnect
  Future<void> disconnect() async {
    await state.disconnect();
  }

  @override
  void dispose() {
    state.dispose();
    super.dispose();
  }
}

/// Stream of real-time message events
final messageEventStreamProvider =
    StreamProvider.autoDispose<WebSocketEvent>((ref) {
  final webSocket = ref.watch(messageWebSocketProvider);
  return webSocket.eventStream;
});

/// Stream of typing indicators
final typingIndicatorsProvider =
    StreamProvider.autoDispose<({String userId, String chatId, bool isTyping})>(
      (ref) {
  final webSocket = ref.watch(messageWebSocketProvider);
  return webSocket.typingIndicators;
});
