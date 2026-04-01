import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/message_websocket_service.dart';
import '../../../core/services/api_client.dart';
import '../../profile/providers/profile_cache_invalidator.dart';

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
      final wsUrl = ApiClient.getWebSocketUrl('');
      await state.connect(
        token: token,
        userId: userId,
        baseUrl: wsUrl,
      );
    } catch (e) {
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
    StreamProvider.autoDispose<({String userId, String username, String chatId, bool isTyping})>(
      (ref) {
  final webSocket = ref.watch(messageWebSocketProvider);
  return webSocket.typingIndicators;
});

/// 🖼️ Effect: Listen for profile_updated events and invalidate avatar caches
/// 
/// When a user changes their profile picture:
/// 1. Backend broadcasts profile_updated event via WebSocket
/// 2. This effect intercepts the event
/// 3. Invalidates the user's profile cache
/// 4. All watching widgets (chat list, avatars, etc.) refresh automatically
/// 
/// This ensures profile pictures update in real-time across all screens.
final profileUpdateListenerEffect = FutureProvider.autoDispose<void>((ref) async {
  final eventStream = ref.watch(messageEventStreamProvider);
  
  await eventStream.when(
    loading: () async {},
    error: (err, stack) async {},
    data: (event) async {
      // Check if this is a profile_updated event
      if (event.data['type'] == 'profile_updated') {
        final userId = event.data['userId'] as String?;
        
        if (userId != null) {
          // Invalidate this specific user's profile cache
          ref.read(profileUserCacheInvalidatorProvider(userId).notifier).state++;
          
          // Also invalidate ALL profile-related caches to refresh:
          // - Chat list avatars
          // - Message avatars
          // - Group member lists
          // - Any other avatar displays
          ref.read(profileCacheInvalidatorProvider.notifier).state++;
        }
      }
    },
  );
});
