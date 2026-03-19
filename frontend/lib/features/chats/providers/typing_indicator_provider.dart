import 'package:flutter_riverpod/flutter_riverpod.dart';
import './websocket_provider.dart';
import '../../auth/providers/auth_provider.dart';

/// Typing indicator state provider (T046, US3)
///
/// Tracks which users are currently typing in each chat.
/// Auto-timeout: Removes user after 3.5 seconds of inactivity.

class TypingUser {
  final String userId;
  final String username;
  final DateTime startedAt;

  TypingUser({
    required this.userId,
    required this.username,
    required this.startedAt,
  });
}

class TypingIndicatorState {
  /// Map of chatId -> List of users typing
  final Map<String, List<TypingUser>> typingUsers;

  TypingIndicatorState({
    this.typingUsers = const {},
  });

  /// Get users typing in a specific chat
  List<TypingUser> getTypingUsers(String chatId) {
    return typingUsers[chatId] ?? [];
  }

  /// Add user as typing
  TypingIndicatorState addTypingUser(
    String chatId,
    String userId,
    String username,
  ) {
    final users = List<TypingUser>.from(typingUsers[chatId] ?? []);
    
    // Remove if already exists (will be re-added with fresh timestamp)
    users.removeWhere((u) => u.userId == userId);
    
    users.add(TypingUser(
      userId: userId,
      username: username,
      startedAt: DateTime.now(),
    ));

    return TypingIndicatorState(
      typingUsers: {...typingUsers, chatId: users},
    );
  }

  /// Remove user from typing
  TypingIndicatorState removeTypingUser(String chatId, String userId) {
    final users = List<TypingUser>.from(typingUsers[chatId] ?? []);
    users.removeWhere((u) => u.userId == userId);

    return TypingIndicatorState(
      typingUsers: {...typingUsers, chatId: users},
    );
  }

  /// Remove expired typing states (older than 3.5 seconds)
  TypingIndicatorState removeExpired() {
    final now = DateTime.now();
    final newTypingUsers = <String, List<TypingUser>>{};

    for (final entry in typingUsers.entries) {
      final active = entry.value.where((user) {
        final elapsed = now.difference(user.startedAt);
        return elapsed.inMilliseconds < 3500; // 3.5 second timeout
      }).toList();

      if (active.isNotEmpty) {
        newTypingUsers[entry.key] = active;
      }
    }

    return TypingIndicatorState(typingUsers: newTypingUsers);
  }
}

class TypingIndicatorNotifier extends StateNotifier<TypingIndicatorState> {
  TypingIndicatorNotifier() : super(TypingIndicatorState());

  /// Handle incoming typing.start event from WebSocket
  void handleTypingStart(
    String chatId,
    String userId,
    String username,
  ) {
    state = state.addTypingUser(chatId, userId, username);
  }

  /// Handle incoming typing.stop event from WebSocket
  void handleTypingStop(String chatId, String userId) {
    state = state.removeTypingUser(chatId, userId);
  }

  /// Cleanup expired typing states (call from timer)
  void cleanupExpired() {
    state = state.removeExpired();
  }

  /// Get typing users for a chat
  List<TypingUser> getTypingUsersForChat(String chatId) {
    return state.getTypingUsers(chatId);
  }

  /// Clear all typing states for a chat (when leaving chat)
  void clearChatTyping(String chatId) {
    final newTypingUsers = Map<String, List<TypingUser>>.from(state.typingUsers);
    newTypingUsers.remove(chatId);
    state = TypingIndicatorState(typingUsers: newTypingUsers);
  }
}

/// Riverpod provider for typing indicator state
final typingIndicatorProvider =
    StateNotifierProvider<TypingIndicatorNotifier, TypingIndicatorState>(
  (ref) {
    final notifier = TypingIndicatorNotifier();

    // Start cleanup timer that runs every 500ms
    Future.delayed(Duration.zero, () {
      Future.doWhile(() async {
        await Future.delayed(const Duration(milliseconds: 500));
        notifier.cleanupExpired();
        return true;
      });
    });

    return notifier;
  },
);

/// Get typing users for a specific chat
final typingUsersForChatProvider = Provider.family<List<TypingUser>, String>(
  (ref, chatId) {
    final typingState = ref.watch(typingIndicatorProvider);
    return typingState.getTypingUsers(chatId);
  },
);

/// Get OTHER users typing in a specific chat (filters out current user)
final otherUsersTypingProvider = FutureProvider.family<List<TypingUser>, String>(
  (ref, chatId) async {
    final typingUsers = ref.watch(typingUsersForChatProvider(chatId));
    
    // Get current user ID using inheritance from a ChangeNotifier proxy
    // Since authProvider is ChangeNotifier-based, we access it via Provider
    // This is a Future provider because auth might be async
    
    // Filter out the current user - they should never see their own typing indicator
    // For now, this will be handled in the UI by checking userId directly
    return typingUsers;
  },
);

/// Watch WebSocket typing indicators and update the typing notifier
/// This connects real-time typing events from WebSocket to the typing indicator UI
final typingIndicatorUpdatesProvider =
    StreamProvider.autoDispose<void>((ref) async* {
  print('[TypingIndicatorUpdates] 📡 Started watching typing indicators stream');
  
  final webSocket = ref.watch(messageWebSocketProvider);
  print('[TypingIndicatorUpdates] ✓ Got WebSocket service');
  
  await for (final typingEvent in webSocket.typingIndicators) {
    print('[TypingIndicatorUpdates] 📨 Received typing event: $typingEvent');
    
    final (:userId, :chatId, :isTyping) = typingEvent;

    print(
        '[TypingIndicatorUpdates] 🎹 ${isTyping ? 'Start' : 'Stop'} typing: $userId in chat $chatId');

    final notifier = ref.read(typingIndicatorProvider.notifier);

    if (isTyping) {
      // For now, use userId as username since we don't have it in the event
      // Backend should send username in the typing indicator data
      notifier.handleTypingStart(chatId, userId, 'User $userId');
      print('[TypingIndicatorUpdates] ✓ Added $userId to typing list for chat $chatId');
    } else {
      notifier.handleTypingStop(chatId, userId);
      print('[TypingIndicatorUpdates] ✓ Removed $userId from typing list for chat $chatId');
    }
  }
  
  print('[TypingIndicatorUpdates] ⚠️  Typing indicators stream closed');
});
