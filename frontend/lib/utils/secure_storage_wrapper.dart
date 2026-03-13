import 'dart:io' show Platform;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Wrapper around secure storage with fallback to in-memory storage
/// Handles Linux keyring issues gracefully
class SecureStorageWrapper {
  static final SecureStorageWrapper _instance = SecureStorageWrapper._internal();
  
  final _secureStorage = const FlutterSecureStorage();
  final Map<String, String> _memoryCache = {};
  bool _useMemoryFallback = false;

  SecureStorageWrapper._internal();

  factory SecureStorageWrapper() {
    return _instance;
  }

  /// Read a value from storage
  /// Tries secure storage first, falls back to memory on Linux keyring errors
  Future<String?> read({required String key}) async {
    // Check memory cache first if using fallback
    if (_useMemoryFallback && _memoryCache.containsKey(key)) {
      print('[SecureStorage] Reading from memory cache: $key');
      return _memoryCache[key];
    }

    try {
      final value = await _secureStorage.read(key: key).timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          print('[SecureStorage] Timeout reading from secure storage - using memory fallback');
          _useMemoryFallback = true;
          return null;
        },
      );

      if (value != null) {
        // Cache it in memory for future use
        _memoryCache[key] = value;
        print('[SecureStorage] Successfully read from secure storage: $key');
      }

      return value;
    } catch (e) {
      print('[SecureStorage] Error reading from secure storage: $e');

      // On Linux, keyring might fail - use memory fallback
      if (Platform.isLinux &&
          (e.toString().contains('Libsecret') ||
              e.toString().contains('keyring') ||
              e.toString().contains('DBus'))) {
        print('[SecureStorage] Linux keyring error detected - switching to memory storage');
        _useMemoryFallback = true;

        // Return cached value if available
        if (_memoryCache.containsKey(key)) {
          print('[SecureStorage] Returning from memory cache: $key');
          return _memoryCache[key];
        }
      }

      // Rethrow other errors
      rethrow;
    }
  }

  /// Write a value to storage
  /// Writes to secure storage and keeps in-memory backup
  Future<void> write({required String key, required String value}) async {
    try {
      // Always cache in memory
      _memoryCache[key] = value;
      print('[SecureStorage] Cached in memory: $key');

      // Try to write to secure storage
      if (!_useMemoryFallback) {
        try {
          await _secureStorage.write(key: key, value: value).timeout(
            const Duration(seconds: 3),
            onTimeout: () {
              print('[SecureStorage] Write timeout - using memory fallback');
              _useMemoryFallback = true;
            },
          );
          print('[SecureStorage] Successfully wrote to secure storage: $key');
        } catch (e) {
          print('[SecureStorage] Error writing to secure storage: $e');
          if (Platform.isLinux &&
              (e.toString().contains('Libsecret') ||
                  e.toString().contains('keyring'))) {
            print('[SecureStorage] Linux keyring error - using memory fallback');
            _useMemoryFallback = true;
          } else {
            rethrow;
          }
        }
      }
    } catch (e) {
      print('[SecureStorage] Failed to write value: $e');
      rethrow;
    }
  }

  /// Delete a value from storage
  Future<void> delete({required String key}) async {
    try {
      // Remove from memory cache
      _memoryCache.remove(key);
      print('[SecureStorage] Removed from memory: $key');

      // Try to delete from secure storage
      if (!_useMemoryFallback) {
        try {
          await _secureStorage.delete(key: key).timeout(
            const Duration(seconds: 3),
          );
          print('[SecureStorage] Successfully deleted from secure storage: $key');
        } catch (e) {
          print('[SecureStorage] Error deleting from secure storage: $e');
          if (Platform.isLinux &&
              (e.toString().contains('Libsecret') ||
                  e.toString().contains('keyring'))) {
            print('[SecureStorage] Linux keyring error - memory deletion only');
            // Not critical if delete fails
          } else {
            rethrow;
          }
        }
      }
    } catch (e) {
      print('[SecureStorage] Failed to delete value: $e');
      // Don't rethrow for delete operations
    }
  }

  /// Clear all values
  Future<void> deleteAll() async {
    try {
      _memoryCache.clear();
      print('[SecureStorage] Cleared memory storage');

      if (!_useMemoryFallback) {
        try {
          await _secureStorage.deleteAll().timeout(
            const Duration(seconds: 3),
          );
          print('[SecureStorage] Cleared secure storage');
        } catch (e) {
          print('[SecureStorage] Error clearing secure storage: $e');
          if (Platform.isLinux &&
              (e.toString().contains('Libsecret') ||
                  e.toString().contains('keyring'))) {
            print('[SecureStorage] Linux keyring error - memory cleared only');
          } else {
            rethrow;
          }
        }
      }
    } catch (e) {
      print('[SecureStorage] Failed to clear storage: $e');
    }
  }

  /// Check if using memory fallback (for diagnostics)
  bool isUsingMemoryFallback() => _useMemoryFallback;

  /// Force use of memory storage (for testing or manual override)
  void forceMemoryMode() {
    _useMemoryFallback = true;
    print('[SecureStorage] Forced to memory-only mode');
  }
}
