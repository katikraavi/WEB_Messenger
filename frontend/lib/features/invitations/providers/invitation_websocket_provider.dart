import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../chats/providers/websocket_provider.dart';
import '../../chats/services/message_websocket_service.dart';
import '../models/chat_invite_model.dart';

/// Stream of invitation events from WebSocket
/// Yields invitation events (sent, accepted, declined, cancelled)
final invitationEventStreamProvider =
    StreamProvider.autoDispose<({String eventType, ChatInviteModel invite})?>((
      ref,
    ) async* {
      // Watch WebSocket service to get access to event stream
      final webSocket = ref.watch(messageWebSocketProvider);

      // Listen to WebSocket events
      await for (final event in webSocket.eventStream) {
        switch (event.type) {
          case WebSocketEventType.invitationSent:
            final invite = _parseInviteFromEvent(event);
            if (invite != null) {
              yield (eventType: 'sent', invite: invite);
            }
            break;

          case WebSocketEventType.invitationAccepted:
            final invite = _parseInviteFromEvent(event);
            if (invite != null) {
              yield (eventType: 'accepted', invite: invite);
            }
            break;

          case WebSocketEventType.invitationDeclined:
            final invite = _parseInviteFromEvent(event);
            if (invite != null) {
              yield (eventType: 'declined', invite: invite);
            }
            break;

          case WebSocketEventType.invitationCancelled:
            final invite = _parseInviteFromEvent(event);
            if (invite != null) {
              yield (eventType: 'cancelled', invite: invite);
            }
            break;

          default:
            // Ignore other event types
            break;
        }
      }
    });

/// Parse ChatInviteModel from WebSocket event data
ChatInviteModel? _parseInviteFromEvent(WebSocketEvent event) {
  try {
    final data = event.data['invite'] as Map<String, dynamic>?;
    if (data == null) return null;

    return ChatInviteModel.fromJson(data);
  } catch (e) {
    print(
      '[InvitationEvents] ❌ Error parsing invitation from WebSocket event: $e',
    );
    return null;
  }
}
