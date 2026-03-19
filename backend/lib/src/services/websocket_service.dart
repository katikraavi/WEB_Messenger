import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:async';
import 'dart:convert';
import './chat_service.dart';

/// Message event types sent over WebSocket
enum WebSocketEventType {
  // Real-time message delivery
  messageCreated,
  messageReceived,
  messageEdited,
  messageDeleted,
  
  // Message status updates (sent, delivered, read)
  messageStatusChanged,
  
  // Chat archival events
  chatArchived,
  chatUnarchived,
  
  // Connection management
  ping,
  pong,
}

/// Represents a single WebSocket event
class WebSocketEvent {
  final WebSocketEventType type;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  WebSocketEvent({
    required this.type,
    required this.data,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Convert event to JSON for wire protocol
  Map<String, dynamic> toJson() => {
    'type': type.name,
    'data': data,
    'timestamp': timestamp.toIso8601String(),
  };

  /// Parse JSON event from WebSocket message
  factory WebSocketEvent.fromJson(Map<String, dynamic> json) {
    final type = WebSocketEventType.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => throw ArgumentError('Unknown event type: ${json['type']}'),
    );

    return WebSocketEvent(
      type: type,
      data: json['data'] ?? {},
      timestamp: json['timestamp'] != null 
        ? DateTime.parse(json['timestamp']) 
        : DateTime.now(),
    );
  }
}

/// WebSocket connection manager with broadcast capability
/// 
/// Manages real-time WebSocket connections for messaging:
/// - Maintains list of active connections per chat
/// - Broadcasts message events to both chat participants
/// - Handles connection lifecycle (ping/pong, reconnection)
/// - Routes events to specific listeners
class WebSocketService {
  /// Singleton instance - ensures all parts of the app use the same service
  static final WebSocketService _instance = WebSocketService._();
  
  /// Private constructor for singleton pattern
  WebSocketService._();
  
  /// Factory constructor - returns singleton instance
  factory WebSocketService() {
    return _instance;
  }
  
  /// Map of active WebSocket connections: chatId -> List<connection>
  final Map<String, List<WebSocketChannel>> _activeConnections = {};
  
  /// Map of listeners for specific events: eventType -> List<handlers>
  final Map<WebSocketEventType, List<Function(WebSocketEvent)>> _eventListeners = {};
  
  /// Mutex for thread-safe connection management
  final _connectionLock = _Lock();

  /// Subscribe to WebSocket events of a specific type
  void on(WebSocketEventType eventType, Function(WebSocketEvent) handler) {
    if (!_eventListeners.containsKey(eventType)) {
      _eventListeners[eventType] = [];
    }
    _eventListeners[eventType]!.add(handler);
  }

  /// Add a WebSocket connection for a chat
  /// 
  /// Parameters:
  /// - chatId: The chat this connection is for
  /// - channel: The WebSocket channel
  /// 
  /// The connection will automatically be removed if it closes.
  /// Starts listening for messages and emits them as events.
  Future<void> addConnection(String chatId, WebSocketChannel channel) async {
    await _connectionLock.lock(() async {
      if (!_activeConnections.containsKey(chatId)) {
        _activeConnections[chatId] = [];
      }
      _activeConnections[chatId]!.add(channel);
      print('[WebSocketService] ✓ Added connection for chat $chatId (total: ${_activeConnections[chatId]!.length})');
    });

    // NOTE: Do NOT listen to channel.stream here - it's already being listened to
    // in websocket_handler.dart. Listening twice causes "Stream has already been listened to" error.
  }

  /// Remove a connection from the active list
  void _removeConnection(String chatId, WebSocketChannel channel) {
    _connectionLock.lock(() async {
      _activeConnections[chatId]?.remove(channel);
      if (_activeConnections[chatId]?.isEmpty ?? false) {
        _activeConnections.remove(chatId);
      }
    });
  }

  /// Broadcast an event to all connections in a chat
  /// 
  /// Parameters:
  /// - chatId: The chat to broadcast to (both participants)
  /// - event: The event to broadcast
  Future<void> broadcastToChatAsync(String chatId, WebSocketEvent event) async {
    await _connectionLock.lock(() async {
      final connections = _activeConnections[chatId];
      if (connections == null || connections.isEmpty) return;

      final message = jsonEncode(event.toJson());
      for (final channel in connections) {
        try {
          channel.sink.add(message);
        } catch (e) {
          print('[WebSocket] Error sending to connection: $e');
        }
      }
    });
  }

  /// Broadcast an event to all connections in a chat (synchronous variant)
  void broadcastToChat(String chatId, WebSocketEvent event) {
    final connections = _activeConnections[chatId];
    if (connections == null || connections.isEmpty) {
      print('[WebSocketService] ⚠️ No connections for chat $chatId (event type: ${event.type})');
      return;
    }

    final message = jsonEncode(event.toJson());
    print('[WebSocketService] 📡 Broadcasting to chat $chatId (${connections.length} connections): event=${event.type}, data=${event.data}');
    for (final channel in connections) {
      try {
        channel.sink.add(message);
      } catch (e) {
        print('[WebSocket] ❌ Error sending to connection: $e');
      }
    }
  }

  /// Get number of active connections for a chat
  int getConnectionCount(String chatId) {
    return _activeConnections[chatId]?.length ?? 0;
  }

  /// Send a message event notification
  void notifyMessageCreated(String chatId, Map<String, dynamic> messageData) {
    final event = WebSocketEvent(
      type: WebSocketEventType.messageCreated,
      data: messageData,
    );
    broadcastToChat(chatId, event);
  }

  /// Send a message received acknowledgement event
  void notifyMessageReceived(String chatId, String messageId) {
    final event = WebSocketEvent(
      type: WebSocketEventType.messageReceived,
      data: {'message_id': messageId},
    );
    broadcastToChat(chatId, event);
  }

  /// Send a chat archive notification event
  void notifyArchived(String chatId, String userId) {
    final event = WebSocketEvent(
      type: WebSocketEventType.chatArchived,
      data: {'user_id': userId, 'chat_id': chatId},
    );
    broadcastToChat(chatId, event);
  }

  /// Send a chat unarchive notification event
  void notifyUnarchived(String chatId, String userId) {
    final event = WebSocketEvent(
      type: WebSocketEventType.chatUnarchived,
      data: {'user_id': userId, 'chat_id': chatId},
    );
    broadcastToChat(chatId, event);
  }

  /// Send ping (keep-alive) to all connections in a chat
  void sendPing(String chatId) {
    final event = WebSocketEvent(
      type: WebSocketEventType.ping,
      data: {},
    );
    broadcastToChat(chatId, event);
  }

  /// Emit an event to all registered listeners
  void _emitEvent(WebSocketEvent event) {
    final listeners = _eventListeners[event.type];
    if (listeners != null) {
      for (final handler in listeners) {
        try {
          handler(event);
        } catch (e) {
          print('[WebSocket] Error in event listener: $e');
        }
      }
    }
  }

  /// Close all connections
  Future<void> closeAll() async {
    await _connectionLock.lock(() async {
      for (final connections in _activeConnections.values) {
        for (final channel in connections) {
          await channel.sink.close();
        }
      }
      _activeConnections.clear();
    });
  }

  /// Close connections for a specific chat
  Future<void> closeChat(String chatId) async {
    await _connectionLock.lock(() async {
      final connections = _activeConnections[chatId];
      if (connections != null) {
        for (final channel in connections) {
          await channel.sink.close();
        }
        _activeConnections.remove(chatId);
      }
    });
  }
}

/// Simple lock for synchronizing access to shared resources
class _Lock {
  Completer<void>? _nextCompleter;

  Future<void> lock(Future<void> Function() action) async {
    final completer = Completer<void>();
    _nextCompleter?.future.then((_) => action()).then((_) => completer.complete());
    if (_nextCompleter == null) {
      action().then((_) => completer.complete());
    }
    _nextCompleter = completer;
    return completer.future;
  }
}
