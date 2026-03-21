import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../../core/services/websocket_service.dart';
import '../../features/chats/providers/receive_messages_provider.dart';
import '../../features/chats/providers/typing_indicator_provider.dart';
import '../services/chat_api_service.dart';

/// Application initialization service (T032, T047)
/// 
/// Handles startup tasks:
/// - Connect to WebSocket
/// - Initialize message listeners
/// - Setup real-time event handling (including typing indicators)
class AppInitializationService {
  static bool _isInitialized = false;
  static WidgetRef? _riverpodRef;

  /// Initialize real-time messaging (once per app lifetime)
  /// 
  /// Called from main.dart after user authenticates
  /// 
  /// Parameters:
  /// - token: JWT authentication token
  /// - userId: Current user ID
  /// - webSocketService: WebSocket service instance
  /// - apiService: API service instance
  /// - ref: Riverpod ref for state management (T047)
  static Future<void> initializeRealtimeMessaging({
    required String token,
    required String userId,
    required WebSocketService webSocketService,
    required ChatApiService apiService,
    required WidgetRef ref,
  }) async {
    if (_isInitialized) {
      debugPrint('[AppInitialization] Realtime messaging already initialized');
      return;
    }

    try {
      debugPrint('[AppInitialization] 🚀 Initializing realtime messaging...');
      
      _riverpodRef = ref;

      // Connect to WebSocket
      await webSocketService.connect(
        token: token,
        userId: userId,
        url: 'ws://localhost:8081/ws/messages',
      );

      debugPrint('[AppInitialization] ✓ WebSocket connected');

      // Initialize receive messages listener (will subscribe to WebSocket events)
      final listener = ReceiveMessagesListener(
        webSocketService: webSocketService,
        apiService: apiService,
        currentUserId: userId,
        token: token,
      );

      debugPrint('[AppInitialization] ✓ Receive messages listener initialized');
      
      // Setup typing event routing (T047)
      _setupTypingEventRouting(webSocketService, ref);

      _isInitialized = true;
      debugPrint('[AppInitialization] ✅ Realtime messaging initialized');
    } catch (e, st) {
      debugPrint('[AppInitialization] ❌ Error initializing: $e\n$st');
      rethrow;
    }
  }
  
  /// Setup typing event routing to typing indicator provider (T047)
  static void _setupTypingEventRouting(
    WebSocketService webSocketService,
    WidgetRef ref,
  ) {
    debugPrint('[AppInitialization] 📡 Setting up typing event routing...');
    
    webSocketService.eventStream.listen((event) {
      final eventType = event['type'];
      
      if (eventType == 'user_typing' || eventType == 'typing.start') {
        _handleTypingStart(event, ref);
      } else if (eventType == 'typing.stop') {
        _handleTypingStop(event, ref);
      }
    });
  }
  
  /// Route typing.start event to typing indicator provider (T047)
  static void _handleTypingStart(Map<String, dynamic> event, WidgetRef ref) {
    try {
      final chatId = event['chatId'] as String?;
      final data = event['data'] as Map<String, dynamic>?;
      
      if (chatId == null || data == null) return;
      
      final userId = data['userId'] as String?;
      final username = data['username'] as String?;
      
      if (userId == null || username == null) return;
      
      debugPrint('[AppInitialization] ⌨️ User typing: $username in chat $chatId');
      
      // Update typing indicator state
      ref.read(typingIndicatorProvider.notifier).handleTypingStart(
        chatId,
        userId,
        username,
      );
    } catch (e) {
      debugPrint('[AppInitialization] ❌ Error handling typing start: $e');
    }
  }
  
  /// Route typing.stop event to typing indicator provider (T047)
  static void _handleTypingStop(Map<String, dynamic> event, WidgetRef ref) {
    try {
      final chatId = event['chatId'] as String?;
      final data = event['data'] as Map<String, dynamic>?;
      
      if (chatId == null || data == null) return;
      
      final userId = data['userId'] as String?;
      
      if (userId == null) return;
      
      debugPrint('[AppInitialization] ⌨️ User stopped typing in chat $chatId');
      
      // Update typing indicator state
      ref.read(typingIndicatorProvider.notifier).handleTypingStop(
        chatId,
        userId,
      );
    } catch (e) {
      debugPrint('[AppInitialization] ❌ Error handling typing stop: $e');
    }
  }

  /// Cleanup on app shutdown
  static Future<void> shutdown({
    required WebSocketService webSocketService,
  }) async {
    debugPrint('[AppInitialization] 🛑 Shutting down realtime messaging');
    await webSocketService.disconnect();
    _isInitialized = false;
  }
}

/// Riverpod provider for app state management
final appStateProvider = StateNotifierProvider<AppStateNotifier, bool>((ref) {
  return AppStateNotifier();
});

class AppStateNotifier extends StateNotifier<bool> {
  AppStateNotifier() : super(false);

  void markInitialized() {
    state = true;
  }

  void markShutdown() {
    state = false;
  }
}
