import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Offline action queue for deferred operations
/// 
/// T059: Offline action queue
/// 
/// Stores actions performed while offline (accept, decline, send)
/// automatically retries when connection restored
class OfflineActionQueue {
  static const String _queueKey = 'offline_action_queue';
  
  final FlutterSecureStorage _secureStorage;
  
  OfflineActionQueue({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  /// Action types
  static const String actionSendInvite = 'send_invite';
  static const String actionAcceptInvite = 'accept_invite';
  static const String actionDeclineInvite = 'decline_invite';

  /// Queue an offline action
  /// 
  /// Stores action to be retried when online
  /// 
  /// Parameters:
  /// - type: Action type (send_invite, accept_invite, decline_invite)
  /// - data: Action payload (userId, inviteId, etc)
  /// - priority: Higher = execute first (1-10, default 5)
  /// 
  /// Returns: true if queued successfully
  Future<bool> queueAction({
    required String type,
    required Map<String, dynamic> data,
    int priority = 5,
  }) async {
    try {
      final action = {
        'id': DateTime.now().millisecondsSinceEpoch,
        'type': type,
        'data': data,
        'priority': priority,
        'timestamp': DateTime.now().toIso8601String(),
        'retries': 0,
      };
      
      final queue = await _getQueue();
      queue.add(action);
      
      // Sort by priority (higher first)
      queue.sort((a, b) => (b['priority'] as int).compareTo(a['priority'] as int));
      
      await _setQueue(queue);
      
      print('[OfflineQueue] Action queued: $type (ID: ${action['id']})');
      return true;
    } catch (e) {
      print('[OfflineQueue Error] Failed to queue action: $e');
      return false;
    }
  }

  /// Get all queued actions
  /// 
  /// Returns: List of pending actions sorted by priority
  Future<List<Map<String, dynamic>>> getQueuedActions() async {
    try {
      return await _getQueue();
    } catch (e) {
      print('[OfflineQueue Error] Failed to retrieve queue: $e');
      return [];
    }
  }

  /// Remove action from queue after successful execution
  /// 
  /// Parameters:
  /// - actionId: ID of action to remove
  /// 
  /// Returns: true if removed
  Future<bool> removeAction(int actionId) async {
    try {
      var queue = await _getQueue();
      queue.removeWhere((action) => action['id'] == actionId);
      await _setQueue(queue);
      
      print('[OfflineQueue] Action removed: $actionId');
      return true;
    } catch (e) {
      print('[OfflineQueue Error] Failed to remove action: $e');
      return false;
    }
  }

  /// Increment retry count for action
  /// 
  /// Used to track retry attempts
  /// If retries > maxRetries, can be discarded
  /// 
  /// Parameters:
  /// - actionId: ID of action
  /// - maxRetries: Max retry attempts (default 3)
  /// 
  /// Returns: New retry count, or -1 if failed/max retries reached
  Future<int> incrementRetry(int actionId, {int maxRetries = 3}) async {
    try {
      var queue = await _getQueue();
      
      for (var action in queue) {
        if (action['id'] == actionId) {
          action['retries'] = (action['retries'] as int) + 1;
          
          if (action['retries'] > maxRetries) {
            print('[OfflineQueue] Action ${action['id']} exceeded max retries');
            queue.removeWhere((a) => a['id'] == actionId);
            return -1;
          }
          
          await _setQueue(queue);
          return action['retries'];
        }
      }
      
      return -1; // Action not found
    } catch (e) {
      print('[OfflineQueue Error] Failed to increment retry: $e');
      return -1;
    }
  }

  /// Clear entire queue
  /// 
  /// Used on logout or manual reset
  /// 
  /// Returns: true if cleared
  Future<bool> clearQueue() async {
    try {
      await _secureStorage.delete(key: _queueKey);
      print('[OfflineQueue] Queue cleared');
      return true;
    } catch (e) {
      print('[OfflineQueue Error] Failed to clear queue: $e');
      return false;
    }
  }

  /// Get queue statistics
  /// 
  /// Returns: Map with queue size and action type counts
  Future<Map<String, dynamic>> getQueueStats() async {
    try {
      final queue = await _getQueue();
      
      final stats = <String, dynamic>{
        'totalActions': queue.length,
        'sendInvite': 0,
        'acceptInvite': 0,
        'declineInvite': 0,
        'oldestAction': null as DateTime?,
      };
      
      for (var action in queue) {
        final type = action['type'] as String;
        if (type == actionSendInvite) stats['sendInvite'] = (stats['sendInvite'] as int) + 1;
        if (type == actionAcceptInvite) stats['acceptInvite'] = (stats['acceptInvite'] as int) + 1;
        if (type == actionDeclineInvite) stats['declineInvite'] = (stats['declineInvite'] as int) + 1;
      }
      
      if (queue.isNotEmpty) {
        final oldest = queue.last['timestamp'] as String;
        stats['oldestAction'] = DateTime.parse(oldest);
      }
      
      return stats;
    } catch (e) {
      print('[OfflineQueue Error] Failed to get stats: $e');
      return {};
    }
  }

  /// Private: Get queue from storage
  Future<List<Map<String, dynamic>>> _getQueue() async {
    final data = await _secureStorage.read(key: _queueKey);
    if (data == null) return [];
    
    try {
      final list = jsonDecode(data) as List;
      return list.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    } catch (e) {
      print('[OfflineQueue Error] Failed to parse queue: $e');
      return [];
    }
  }

  /// Private: Save queue to storage
  Future<void> _setQueue(List<Map<String, dynamic>> queue) async {
    await _secureStorage.write(
      key: _queueKey,
      value: jsonEncode(queue),
    );
  }
}
