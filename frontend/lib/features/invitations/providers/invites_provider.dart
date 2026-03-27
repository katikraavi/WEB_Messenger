import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_invite_model.dart';
import '../services/invite_api_service.dart';
import '../services/group_invite_service.dart';
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

  final apiService = ref.watch(inviteApiServiceProvider);
  try {
    final invites = await apiService.fetchPendingInvites();
    return invites;
  } catch (e) {
    rethrow;
  }
});

/// Provides list of sent invitations for current user
final sentInvitesProvider = FutureProvider<List<ChatInviteModel>>((ref) async {
  // Watch the cache invalidator to refresh when user changes
  ref.watch(invitesCacheInvalidatorProvider);

  final apiService = ref.watch(inviteApiServiceProvider);
  try {
    final invites = await apiService.fetchSentInvites();
    return invites;
  } catch (e) {
    rethrow;
  }
});

/// Provides count of pending invitations (for badge display)
final pendingInviteCountProvider = FutureProvider<int>((ref) async {
  final apiService = ref.watch(inviteApiServiceProvider);
  try {
    final count = await apiService.getPendingInviteCount();
    return count;
  } catch (e) {
    rethrow;
  }
});

/// Provides list of pending group invitations for current user.
final pendingGroupInvitesProvider = FutureProvider<List<GroupInviteModel>>((
  ref,
) async {
  ref.watch(invitesCacheInvalidatorProvider);

  final token = await ref.watch(authTokenProvider.future);
  if (token.isEmpty) {
    return [];
  }

  final service = GroupInviteService(baseUrl: ApiClient.getBaseUrl());
  return service.fetchPendingInvites(token: token);
});

/// Provides count of pending group invitations.
final pendingGroupInviteCountProvider = FutureProvider<int>((ref) async {
  final invites = await ref.watch(pendingGroupInvitesProvider.future);
  return invites.length;
});

/// Total pending invitations count (direct + group), used for global badge.
final totalPendingInviteCountProvider = Provider<int>((ref) {
  final directCount = ref.watch(pendingInvitesProvider).maybeWhen(
        data: (invites) => invites.length,
        orElse: () => 0,
      );
  final groupCount = ref.watch(pendingGroupInvitesProvider).maybeWhen(
        data: (invites) => invites.length,
        orElse: () => 0,
      );
  return directCount + groupCount;
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
      _ref.invalidate(pendingInviteCountProvider);
      _ref.invalidate(pendingGroupInvitesProvider);
      _ref.invalidate(pendingGroupInviteCountProvider);
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
      _ref.invalidate(pendingGroupInvitesProvider);
      _ref.invalidate(pendingGroupInviteCountProvider);

      // Also invalidate chat list - when invitation is accepted, a chat is created on backend
      try {
        final token = await _ref.read(authTokenProvider.future);
        if (token.isNotEmpty) {
          _ref.invalidate(activeChatListProvider(token));
          _ref.invalidate(chatsProvider(token));
        }
      } catch (e) {
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
      _ref.invalidate(pendingGroupInvitesProvider);
      _ref.invalidate(pendingGroupInviteCountProvider);
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

    final (:eventType) = event;


    // Invalidate appropriate caches based on event type
    switch (eventType) {
      case 'sent':
        // New invitation arrived/sent event; refresh badge-related caches.
        ref.invalidate(pendingInvitesProvider);
        ref.invalidate(pendingInviteCountProvider);
        ref.invalidate(pendingGroupInvitesProvider);
        ref.invalidate(pendingGroupInviteCountProvider);
        ref.invalidate(sentInvitesProvider);
        break;

      case 'accepted':
        // When an invitation is accepted (either by current user or sender sees acceptance)
        ref.invalidate(pendingInvitesProvider);
        ref.invalidate(sentInvitesProvider);
        ref.invalidate(pendingInviteCountProvider);
        ref.invalidate(pendingGroupInvitesProvider);
        ref.invalidate(pendingGroupInviteCountProvider);

        // Also refresh chat lists since a new chat was created
        // Note: Chat providers are invalidated through their own WebSocket message handlers
        break;

      case 'declined':
        // When an invitation is declined, refresh both lists
        ref.invalidate(pendingInvitesProvider);
        ref.invalidate(sentInvitesProvider);
        ref.invalidate(pendingInviteCountProvider);
        ref.invalidate(pendingGroupInvitesProvider);
        ref.invalidate(pendingGroupInviteCountProvider);
        break;

      case 'cancelled':
        // When an invitation is cancelled, refresh sent invitations
        ref.invalidate(sentInvitesProvider);
        ref.invalidate(pendingInvitesProvider);
        ref.invalidate(pendingInviteCountProvider);
        ref.invalidate(pendingGroupInvitesProvider);
        ref.invalidate(pendingGroupInviteCountProvider);
        break;

      default:
    }
  });
});
