import 'dart:io' show Platform;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Wrapper around secure storage with fallback to in-memory storage
/// Handles Linux keyring issues gracefully
class SecureStorageWrapper {
  static final SecureStorageWrapper _instance = SecureStorageWrapper._internal();
  
  final _secureStorage = const FlutterSecureStorage();
  final Map<String, String> _memoryCache = {};
  bool _useMemoryFallback = false;

  bool _isLinuxKeyringError(Object error) {
    if (!Platform.isLinux) return false;
    final errorText = error.toString().toLowerCase();
    return errorText.contains('libsecret') ||
        errorText.contains('keyring') ||
        errorText.contains('dbus');
  }

  SecureStorageWrapper._internal();

  factory SecureStorageWrapper() {
    return _instance;
  }

  /// Read a value from storage
  /// Tries secure storage first, falls back to memory on Linux keyring errors
  Future<String?> read({required String key}) async {
    // Check memory cache first if using fallback
    if (_useMemoryFallback && _memoryCache.containsKey(key)) {
      return _memoryCache[key];
    }

    try {
      final value = await _secureStorage.read(key: key).timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          _useMemoryFallback = true;
          return null;
        },
      );

      if (value != null) {
        // Cache it in memory for future use
        _memoryCache[key] = value;
      }

      return value;
    } catch (e) {
      // On Linux, keyring might fail - use memory fallback
      if (_isLinuxKeyringError(e)) {
        _useMemoryFallback = true;

        // Return cached value if available
        if (_memoryCache.containsKey(key)) {
          return _memoryCache[key];
        }

        // No cached value is still a valid fallback result.
        return null;
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

      // Try to write to secure storage
      if (!_useMemoryFallback) {
        try {
          await _secureStorage.write(key: key, value: value).timeout(
            const Duration(seconds: 3),
            onTimeout: () {
              _useMemoryFallback = true;
            },
          );
        } catch (e) {
          if (_isLinuxKeyringError(e)) {
            _useMemoryFallback = true;
          } else {
            rethrow;
          }
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Delete a value from storage
  Future<void> delete({required String key}) async {
    try {
      // Remove from memory cache
      _memoryCache.remove(key);

      // Try to delete from secure storage
      if (!_useMemoryFallback) {
        try {
          await _secureStorage.delete(key: key).timeout(
            const Duration(seconds: 3),
          );
        } catch (e) {
          if (_isLinuxKeyringError(e)) {
            // Not critical if delete fails
          } else {
            rethrow;
          }
        }
      }
    } catch (_) {
      // Don't rethrow for delete operations
    }
  }

  /// Clear all values
  Future<void> deleteAll() async {
    try {
      _memoryCache.clear();

      if (!_useMemoryFallback) {
        try {
          await _secureStorage.deleteAll().timeout(
            const Duration(seconds: 3),
          );
        } catch (e) {
          if (_isLinuxKeyringError(e)) {
          } else {
            rethrow;
          }
        }
      }
    } catch (_) {
    }
  }

  /// Check if using memory fallback (for diagnostics)
  bool isUsingMemoryFallback() => _useMemoryFallback;

  /// Force use of memory storage (for testing or manual override)
  void forceMemoryMode() {
    _useMemoryFallback = true;
  }
}
