import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_profile.dart';

/// Profile Cache Service for Offline Support [T131-T132]
///
/// Provides local caching of profile data using flutter_secure_storage
/// Enables offline access when network unavailable
///
/// Cache keys:
/// - 'profile_{userId}': User profile data (JSON)
/// - 'profile_{userId}_timestamp': Cache timestamp (ISO string)
/// - 'profile_cache_ttl': Time-to-live in hours (default: 24)

class ProfileCacheService {
  static const String _cacheKeyPrefix = 'profile_';
  static const String _timestampKeySuffix = '_timestamp';
  static const int _cacheTTLHours = 24; // Cache valid for 24 hours
  
  late final FlutterSecureStorage _storage;

  ProfileCacheService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  /// Save profile to local cache [T131]
  /// 
  /// Arguments:
  ///   - userId: User ID for cache key
  ///   - profile: UserProfile data to cache
  /// 
  /// Returns: true if successful, false otherwise
  Future<bool> cacheProfile(String userId, UserProfile profile) async {
    try {
      final cacheKey = '${_cacheKeyPrefix}${userId}';
      final timestampKey = '${_cacheKeyPrefix}${userId}${_timestampKeySuffix}';
      
      // Serialize profile to JSON
      final jsonString = jsonEncode(profile.toJson());
      
      // Save profile and timestamp
      await Future.wait([
        _storage.write(key: cacheKey, value: jsonString),
        _storage.write(
          key: timestampKey,
          value: DateTime.now().toIso8601String(),
        ),
      ]);
      
      return true;
    } catch (e) {
      print('[ProfileCacheService] Error caching profile: $e');
      return false;
    }
  }

  /// Retrieve profile from cache [T132]
  /// 
  /// Arguments:
  ///   - userId: User ID to fetch cache for
  /// 
  /// Returns: 
  ///   - UserProfile if found and not expired (TTL < 24h)
  ///   - null if not found or expired
  Future<UserProfile?> getCachedProfile(String userId) async {
    try {
      final cacheKey = '${_cacheKeyPrefix}${userId}';
      final timestampKey = '${_cacheKeyPrefix}${userId}${_timestampKeySuffix}';
      
      // Retrieve profile JSON
      final jsonString = await _storage.read(key: cacheKey);
      if (jsonString == null) {
        return null; // Not in cache
      }
      
      // Check cache expiration
      final timestampStr = await _storage.read(key: timestampKey);
      if (timestampStr != null) {
        final cacheTime = DateTime.parse(timestampStr);
        final now = DateTime.now();
        final ageHours = now.difference(cacheTime).inHours;
        
        if (ageHours > _cacheTTLHours) {
          // Cache expired, remove it
          await clearCache(userId);
          return null;
        }
      }
      
      // Deserialize and return
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return UserProfile.fromJson(json);
    } catch (e) {
      print('[ProfileCacheService] Error retrieving cached profile: $e');
      return null;
    }
  }

  /// Clear cache for specific user
  Future<void> clearCache(String userId) async {
    try {
      final cacheKey = '${_cacheKeyPrefix}${userId}';
      final timestampKey = '${_cacheKeyPrefix}${userId}${_timestampKeySuffix}';
      
      await Future.wait([
        _storage.delete(key: cacheKey),
        _storage.delete(key: timestampKey),
      ]);
    } catch (e) {
      print('[ProfileCacheService] Error clearing cache: $e');
    }
  }

  /// Clear all profile caches
  Future<void> clearAllCache() async {
    try {
      await _storage.deleteAll();
    } catch (e) {
      print('[ProfileCacheService] Error clearing all cache: $e');
    }
  }

  /// Check if cache is valid and not expired
  Future<bool> isCacheValid(String userId) async {
    try {
      final cacheKey = '${_cacheKeyPrefix}${userId}';
      final timestampKey = '${_cacheKeyPrefix}${userId}${_timestampKeySuffix}';
      
      // Check if profile exists
      final json = await _storage.read(key: cacheKey);
      if (json == null) {
        return false;
      }
      
      // Check expiration
      final timestampStr = await _storage.read(key: timestampKey);
      if (timestampStr == null) {
        return false;
      }
      
      final cacheTime = DateTime.parse(timestampStr);
      final ageHours = DateTime.now().difference(cacheTime).inHours;
      
      return ageHours <= _cacheTTLHours;
    } catch (e) {
      return false;
    }
  }
}
