import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../chats/providers/websocket_provider.dart';
import '../../chats/services/message_websocket_service.dart';

/// Stream of invitation events from WebSocket
/// Yields invitation events (sent, accepted, declined, cancelled)
final invitationEventStreamProvider =
    StreamProvider.autoDispose<({String eventType})?>(
  (ref,
    ) async* {
      // Watch WebSocket service to get access to event stream
      final webSocket = ref.watch(messageWebSocketProvider);

      // Listen to WebSocket events
      await for (final event in webSocket.eventStream) {
        switch (event.type) {
          case WebSocketEventType.invitationSent:
            yield (eventType: 'sent');
            break;

          case WebSocketEventType.invitationAccepted:
            yield (eventType: 'accepted');
            break;

          case WebSocketEventType.invitationDeclined:
            yield (eventType: 'declined');
            break;

          case WebSocketEventType.invitationCancelled:
            yield (eventType: 'cancelled');
            break;

          default:
            // Ignore other event types
            break;
        }
      }
    });
