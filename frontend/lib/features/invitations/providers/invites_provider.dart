import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_invite_model.dart';
import '../services/invite_api_service.dart';
import '../../../core/services/api_client.dart';
import '../../chats/providers/chats_provider.dart';
import '../../chats/providers/active_chats_provider.dart';
import '../../search/providers/search_results_provider.dart';
import './invitation_websocket_provider.dart';

// API Service Provider
final inviteApiServiceProvider = Provider<InviteApiService>((ref) {
  // Use the same base URL as ApiClient for consistency
  // Token will be added by InviteApiService when making requests
  return InviteApiService(
    baseUrl: ApiClient.getBaseUrl(),
    authToken: null, // Token is handled by secure storage in the service
  );
});

// Invalidator for clearing all invite data when user logs out
final invitesCacheInvalidatorProvider = StateProvider<int>((ref) {
  return 0; // Version number to force cache refresh when incremented
});

// Query Providers

/// Provides list of pending invitations for current user
final pendingInvitesProvider = FutureProvider<List<ChatInviteModel>>((
  ref,
) async {
  // Watch the cache invalidator to refresh when user changes
  ref.watch(invitesCacheInvalidatorProvider);

  print('[Invites] Fetching pending invitations...');
  final apiService = ref.watch(inviteApiServiceProvider);
  try {
    print('[Invites] API Service base URL: ${ApiClient.getBaseUrl()}');
    final invites = await apiService.fetchPendingInvites();
    print('[Invites] ✅ Successfully fetched ${invites.length} pending invites');
    return invites;
  } catch (e) {
    print('[Invites] ❌ Error fetching pending invites: $e');
    rethrow;
  }
});

/// Provides list of sent invitations for current user
final sentInvitesProvider = FutureProvider<List<ChatInviteModel>>((ref) async {
  // Watch the cache invalidator to refresh when user changes
  ref.watch(invitesCacheInvalidatorProvider);

  print('[Invites] Fetching sent invitations...');
  final apiService = ref.watch(inviteApiServiceProvider);
  try {
    final invites = await apiService.fetchSentInvites();
    print('[Invites] ✅ Successfully fetched ${invites.length} sent invites');
    return invites;
  } catch (e) {
    print('[Invites] ❌ Error fetching sent invites: $e');
    rethrow;
  }
});

/// Provides count of pending invitations (for badge display)
final pendingInviteCountProvider = FutureProvider<int>((ref) async {
  print('[Invites] Fetching pending invite count...');
  final apiService = ref.watch(inviteApiServiceProvider);
  try {
    final count = await apiService.getPendingInviteCount();
    print('[Invites] ✅ Pending invite count: $count');
    return count;
  } catch (e) {
    print('[Invites] ❌ Error fetching pending invite count: $e');
    rethrow;
  }
});

// Mutation Providers (State Notifiers for side effects)

/// Provider for send invite mutation state and operations
final sendInviteMutationProvider =
    StateNotifierProvider<SendInviteMutationNotifier, SendInviteState>((ref) {
      final apiService = ref.watch(inviteApiServiceProvider);
      return SendInviteMutationNotifier(apiService, ref);
    });

/// Provider for accept invite mutation state and operations
final acceptInviteMutationProvider =
    StateNotifierProvider<AcceptInviteMutationNotifier, AcceptInviteState>((
      ref,
    ) {
      final apiService = ref.watch(inviteApiServiceProvider);
      return AcceptInviteMutationNotifier(apiService, ref);
    });

/// Provider for decline invite mutation state and operations
final declineInviteMutationProvider =
    StateNotifierProvider<DeclineInviteMutationNotifier, DeclineInviteState>((
      ref,
    ) {
      final apiService = ref.watch(inviteApiServiceProvider);
      return DeclineInviteMutationNotifier(apiService, ref);
    });

/// Provider for cancel invite mutation state and operations
final cancelInviteMutationProvider =
    StateNotifierProvider<CancelInviteMutationNotifier, CancelInviteState>((
      ref,
    ) {
      final apiService = ref.watch(inviteApiServiceProvider);
      return CancelInviteMutationNotifier(apiService, ref);
    });

// State classes for mutations

class SendInviteState {
  final bool isLoading;
  final ChatInviteModel? data;
  final String? error;

  SendInviteState({this.isLoading = false, this.data, this.error});

  SendInviteState copyWith({
    bool? isLoading,
    ChatInviteModel? data,
    String? error,
  }) {
    return SendInviteState(
      isLoading: isLoading ?? this.isLoading,
      data: data ?? this.data,
      error: error ?? this.error,
    );
  }
}

class AcceptInviteState {
  final bool isLoading;
  final ChatInviteModel? data;
  final String? error;

  AcceptInviteState({this.isLoading = false, this.data, this.error});

  AcceptInviteState copyWith({
    bool? isLoading,
    ChatInviteModel? data,
    String? error,
  }) {
    return AcceptInviteState(
      isLoading: isLoading ?? this.isLoading,
      data: data ?? this.data,
      error: error ?? this.error,
    );
  }
}

class DeclineInviteState {
  final bool isLoading;
  final ChatInviteModel? data;
  final String? error;

  DeclineInviteState({this.isLoading = false, this.data, this.error});

  DeclineInviteState copyWith({
    bool? isLoading,
    ChatInviteModel? data,
    String? error,
  }) {
    return DeclineInviteState(
      isLoading: isLoading ?? this.isLoading,
      data: data ?? this.data,
      error: error ?? this.error,
    );
  }
}

class CancelInviteState {
  final bool isLoading;
  final ChatInviteModel? data;
  final String? error;

  CancelInviteState({this.isLoading = false, this.data, this.error});

  CancelInviteState copyWith({
    bool? isLoading,
    ChatInviteModel? data,
    String? error,
  }) {
    return CancelInviteState(
      isLoading: isLoading ?? this.isLoading,
      data: data ?? this.data,
      error: error ?? this.error,
    );
  }
}

// State Notifier implementations

class SendInviteMutationNotifier extends StateNotifier<SendInviteState> {
  final InviteApiService _apiService;
  final Ref _ref;

  SendInviteMutationNotifier(this._apiService, this._ref)
    : super(SendInviteState());

  /// Send invitation and invalidate queries on success
  Future<void> sendInvite(String recipientId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _apiService.sendInvite(recipientId);
      state = state.copyWith(isLoading: false, data: result);

      // Refresh both pending and sent invites immediately
      _ref.invalidate(sentInvitesProvider);
      _ref.invalidate(pendingInvitesProvider);
      _ref.refresh(sentInvitesProvider);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  /// Reset state
  void reset() {
    state = SendInviteState();
  }
}

class AcceptInviteMutationNotifier extends StateNotifier<AcceptInviteState> {
  final InviteApiService _apiService;
  final Ref _ref;

  AcceptInviteMutationNotifier(this._apiService, this._ref)
    : super(AcceptInviteState());

  /// Accept invitation and invalidate queries on success
  Future<void> acceptInvite(String inviteId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _apiService.acceptInvite(inviteId);
      state = state.copyWith(isLoading: false, data: result);

      // Invalidate invitation queries to refresh lists
      _ref.invalidate(pendingInvitesProvider);
      _ref.invalidate(pendingInviteCountProvider);

      // Also invalidate chat list - when invitation is accepted, a chat is created on backend
      try {
        final token = await _ref.read(authTokenProvider.future);
        if (token.isNotEmpty) {
          _ref.invalidate(activeChatListProvider(token));
          _ref.invalidate(chatsProvider(token));
        }
      } catch (e) {
        print('[AcceptInvite] Could not invalidate chat providers: $e');
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  /// Reset state
  void reset() {
    state = AcceptInviteState();
  }
}

class DeclineInviteMutationNotifier extends StateNotifier<DeclineInviteState> {
  final InviteApiService _apiService;
  final Ref _ref;

  DeclineInviteMutationNotifier(this._apiService, this._ref)
    : super(DeclineInviteState());

  /// Decline invitation and invalidate queries on success
  Future<void> declineInvite(String inviteId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _apiService.declineInvite(inviteId);
      state = state.copyWith(isLoading: false, data: result);

      // Invalidate both queries to refresh lists
      _ref.invalidate(pendingInvitesProvider);
      _ref.invalidate(pendingInviteCountProvider);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  /// Reset state
  void reset() {
    state = DeclineInviteState();
  }
}

class CancelInviteMutationNotifier extends StateNotifier<CancelInviteState> {
  final InviteApiService _apiService;
  final Ref _ref;

  CancelInviteMutationNotifier(this._apiService, this._ref)
    : super(CancelInviteState());

  /// Cancel invitation and invalidate queries on success
  Future<void> cancelInvite(String inviteId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _apiService.cancelInvite(inviteId);
      state = state.copyWith(isLoading: false, data: result);

      // Invalidate both queries to refresh lists
      _ref.invalidate(sentInvitesProvider);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  /// Reset state
  void reset() {
    state = CancelInviteState();
  }
}

// Real-time Updates from WebSocket

/// Provider that watches invitation events from WebSocket and invalidates caches
/// This enables real-time updates without requiring manual refresh
final invitationRealtimeUpdatesProvider = FutureProvider.autoDispose<void>((
  ref,
) async {
  // Watch the WebSocket invitation event stream
  ref.watch(invitationEventStreamProvider).whenData((event) {
    if (event == null) return;

    final (:eventType, :invite) = event;

    print(
      '[InvitationsRealtime] 📡 Received invitation event: $eventType (inviteId: ${invite.id})',
    );

    // Invalidate appropriate caches based on event type
    switch (eventType) {
      case 'sent':
        // When we send an invitation, refresh sent invitations list
        print(
          '[InvitationsRealtime] 📤 Sent invitation - refreshing sent list',
        );
        ref.invalidate(sentInvitesProvider);
        break;

      case 'accepted':
        // When an invitation is accepted (either by current user or sender sees acceptance)
        print(
          '[InvitationsRealtime] ✅ Invitation accepted - refreshing both lists',
        );
        ref.invalidate(pendingInvitesProvider);
        ref.invalidate(sentInvitesProvider);
        ref.invalidate(pendingInviteCountProvider);

        // Also refresh chat lists since a new chat was created
        // Note: Chat providers are invalidated through their own WebSocket message handlers
        break;

      case 'declined':
        // When an invitation is declined, refresh both lists
        print(
          '[InvitationsRealtime] ❌ Invitation declined - refreshing both lists',
        );
        ref.invalidate(pendingInvitesProvider);
        ref.invalidate(sentInvitesProvider);
        ref.invalidate(pendingInviteCountProvider);
        break;

      case 'cancelled':
        // When an invitation is cancelled, refresh sent invitations
        print(
          '[InvitationsRealtime] 🚫 Invitation cancelled - refreshing sent list',
        );
        ref.invalidate(sentInvitesProvider);
        break;

      default:
        print('[InvitationsRealtime] ⚠️  Unknown event type: $eventType');
    }
  });
});
