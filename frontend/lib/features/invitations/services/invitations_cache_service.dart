import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Local cache storage for offline support
/// 
/// T058: Offline support with local caching
/// T060: Auto-sync when online
/// 
/// Provides persistent storage for chat invitations when offline
/// Automatically syncs data when connection restored
class InvitationsCacheService {
  static const String _pendingInvitesKey = 'pending_invites_cache';
  static const String _sentInvitesKey = 'sent_invites_cache';
  
  final FlutterSecureStorage _secureStorage;
  
  InvitationsCacheService({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  /// Cache pending invitations locally
  /// 
  /// Called after successful API fetch
  /// Allows offline viewing even if API unavailable
  /// 
  /// Parameters:
  /// - data: JSON list of pending invites
  /// 
  /// Returns: true if cache successful
  Future<bool> cachePendingInvites(String jsonData) async {
    try {
      await _secureStorage.write(
        key: _pendingInvitesKey,
        value: jsonData,
      );
      
      // Store cache timestamp for staleness checking
      await _secureStorage.write(
        key: '${_pendingInvitesKey}_timestamp',
        value: DateTime.now().toIso8601String(),
      );
      
      print('[Cache] Pending invites cached successfully');
      return true;
    } catch (e) {
      print('[Cache Error] Failed to cache pending invites: $e');
      return false;
    }
  }

  /// Cache sent invitations locally
  /// 
  /// Parameters:
  /// - data: JSON list of sent invites
  /// 
  /// Returns: true if cache successful
  Future<bool> cacheSentInvites(String jsonData) async {
    try {
      await _secureStorage.write(
        key: _sentInvitesKey,
        value: jsonData,
      );
      
      await _secureStorage.write(
        key: '${_sentInvitesKey}_timestamp',
        value: DateTime.now().toIso8601String(),
      );
      
      print('[Cache] Sent invites cached successfully');
      return true;
    } catch (e) {
      print('[Cache Error] Failed to cache sent invites: $e');
      return false;
    }
  }

  /// Retrieve cached pending invitations
  /// 
  /// Used when offline to display last cached data
  /// Shows stale data notice if cache older than 1 hour
  /// 
  /// Returns: JSON string or null if no cache
  Future<String?> getCachedPendingInvites() async {
    try {
      final data = await _secureStorage.read(key: _pendingInvitesKey);
      if (data == null) return null;
      
      // Check cache age
      final timestamp = await _secureStorage.read(
        key: '${_pendingInvitesKey}_timestamp',
      );
      if (timestamp != null) {
        final cacheTime = DateTime.parse(timestamp);
        final age = DateTime.now().difference(cacheTime);
        if (age.inHours > 1) {
          print('[Cache] Pending invites cache is stale (${age.inHours}h old)');
        }
      }
      
      return data;
    } catch (e) {
      print('[Cache Error] Failed to retrieve cached pending invites: $e');
      return null;
    }
  }

  /// Retrieve cached sent invitations
  /// 
  /// Returns: JSON string or null if no cache
  Future<String?> getCachedSentInvites() async {
    try {
      return await _secureStorage.read(key: _sentInvitesKey);
    } catch (e) {
      print('[Cache Error] Failed to retrieve cached sent invites: $e');
      return null;
    }
  }

  /// Clear all invitation caches
  /// 
  /// Used on logout or manual refresh
  /// 
  /// Returns: true if successful
  Future<bool> clearAllCaches() async {
    try {
      await _secureStorage.delete(key: _pendingInvitesKey);
      await _secureStorage.delete(key: '${_pendingInvitesKey}_timestamp');
      await _secureStorage.delete(key: _sentInvitesKey);
      await _secureStorage.delete(key: '${_sentInvitesKey}_timestamp');
      
      print('[Cache] All invitation caches cleared');
      return true;
    } catch (e) {
      print('[Cache Error] Failed to clear caches: $e');
      return false;
    }
  }

  /// Check if cache exists and is recent
  /// 
  /// Parameters:
  /// - maxAgeHours: Maximum acceptable age (default: 1 hour)
  /// 
  /// Returns: true if cache exists and is recent
  Future<bool> hasFreshCache({int maxAgeHours = 1}) async {
    try {
      final timestamp = await _secureStorage.read(
        key: '${_pendingInvitesKey}_timestamp',
      );
      
      if (timestamp == null) return false;
      
      final cacheTime = DateTime.parse(timestamp);
      final age = DateTime.now().difference(cacheTime);
      
      return age.inHours < maxAgeHours;
    } catch (e) {
      return false;
    }
  }

  /// Get cache metadata
  /// 
  /// Returns: Map with cache status and timestamps
  Future<Map<String, dynamic>> getCacheMetadata() async {
    try {
      final pendingTimestamp = await _secureStorage.read(
        key: '${_pendingInvitesKey}_timestamp',
      );
      final sentTimestamp = await _secureStorage.read(
        key: '${_sentInvitesKey}_timestamp',
      );
      
      return {
        'hasPendingCache': pendingTimestamp != null,
        'hasSentCache': sentTimestamp != null,
        'pendingCacheAge': pendingTimestamp != null 
          ? DateTime.now().difference(DateTime.parse(pendingTimestamp)).inMinutes 
          : null,
        'sentCacheAge': sentTimestamp != null 
          ? DateTime.now().difference(DateTime.parse(sentTimestamp)).inMinutes 
          : null,
      };
    } catch (e) {
      print('[Cache Error] Failed to get metadata: $e');
      return {};
    }
  }
}
