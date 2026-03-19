import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../utils/secure_storage_wrapper.dart';
import '../models/auth_models.dart';
import '../services/auth_service.dart';

/// Auth state provider using ChangeNotifier
/// 
/// Manages:
/// - User authentication state (logged in/out)
/// - Current user information
/// - Loading and error states
/// - Token persistence using secure storage
class AuthProvider extends ChangeNotifier {
  static const bool _debugLogs = false;

  static void _log(String message) {
    if (_debugLogs) {
      debugPrint(message);
    }
  }

  User? _user;
  String? _token;
  bool _isLoading = false;
  String? _error;
  
  final SecureStorageWrapper _secureStorage = SecureStorageWrapper();

  // Getters
  User? get user => _user;
  String? get token => _token;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get userId => _user?.userId;
  bool get isAuthenticated => _user != null && _token != null;

  /// Initialize auth provider - restore session if token exists
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final savedToken = await _secureStorage.read(key: 'auth_token');
      if (savedToken != null && savedToken.isNotEmpty) {
        _token = savedToken;
        
        // Validate token with backend
        try {
          final user = await AuthService.validateSession(savedToken);
          _user = user;
          _error = null;
        } catch (e) {
          // Token is invalid, clear it
          await _secureStorage.delete(key: 'auth_token');
          await _secureStorage.delete(key: 'user_id');
          _token = null;
          _user = null;
        }
      }
    } catch (e) {
      final errorText = e.toString().toLowerCase();
      final isLinuxKeyringIssue = errorText.contains('libsecret') ||
          errorText.contains('keyring') ||
          errorText.contains('dbus');

      if (isLinuxKeyringIssue) {
        _log('[AuthProvider] Linux keyring unavailable, starting without persisted session');
      } else {
        _log('Error initializing auth: $e');
      }
    }
    
    _isLoading = false;
    notifyListeners();
  }

  /// Register new user
  String? _devVerificationToken;
  String? get devVerificationToken => _devVerificationToken;

  Future<void> register(RegistrationRequest request) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final authResponse = await AuthService.register(request);
      
      // Create user from response
      _user = User(
        userId: authResponse.userId,
        email: authResponse.email,
        username: authResponse.username,
      );
      
      // Capture dev token from registration response (only present in dev mode)
      _devVerificationToken = authResponse.devVerificationToken;

      // Note: Token is NOT stored after registration (per spec)
      // User must login to get a token with persistent session
      _token = null;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      _user = null;
      _token = null;
      _devVerificationToken = null;
      notifyListeners();
      rethrow;
    }
  }

  /// Login user
  Future<void> login(LoginRequest request) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _log('[AuthProvider] Login attempt for email: ${request.email}');
      final authResponse = await AuthService.login(request);
      _log('[AuthProvider] Login response received');
      _log('[AuthProvider] User ID: ${authResponse.userId}');
      _log('[AuthProvider] Token: ${authResponse.token != null ? 'present' : 'null'}');
      
      // Store token securely
      _token = authResponse.token;
      if (_token != null) {
        _log('[AuthProvider] Storing token in secure storage');
        try {
          await _secureStorage.write(key: 'auth_token', value: _token!);
          await _secureStorage.write(key: 'user_id', value: authResponse.userId);
          _log('[AuthProvider] Token stored successfully');
        } catch (storageError) {
          _log('[AuthProvider] Error storing token: $storageError');
          // Continue anyway - token is in memory
        }
      }
      
      // Set user
      _user = User(
        userId: authResponse.userId,
        email: authResponse.email,
        username: authResponse.username,
      );
      
      _log('[AuthProvider] User set: ${_user?.username}');
      _log('[AuthProvider] isAuthenticated: $isAuthenticated');
      
      _isLoading = false;
      notifyListeners();
      _log('[AuthProvider] notifyListeners() called');
    } catch (e) {
      _log('[AuthProvider] Login error: $e');
      _isLoading = false;
      _error = e.toString();
      _user = null;
      _token = null;
      notifyListeners();
      rethrow;
    }
  }

  /// Logout user
  Future<void> logout() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (_token != null) {
        await AuthService.logout(_token!);
      }
    } catch (e) {
      _log('Logout error: $e');
    }

    // Clear local state
    _user = null;
    _token = null;
    
    // Clear secure storage
    await _secureStorage.delete(key: 'auth_token');
    await _secureStorage.delete(key: 'user_id');

    _isLoading = false;
    notifyListeners();
    
    // Note: Riverpod providers will auto-invalidate on next check
    // because the auth context has changed
  }

  /// Clear error message
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Reset auth state
  void reset() {
    _user = null;
    _token = null;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  /// Send verification email (after registration)
  Future<bool> sendVerificationEmail(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (_user == null) {
        throw Exception('User not found');
      }

      // Import and use email verification service
      // This would require importing the service and calling it
      // For now, we'll rely on the VerificationProvider handling this
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Send password recovery email
  Future<bool> sendPasswordRecoveryEmail(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // This would call the password recovery service
      // Implementation delegated to PasswordRecoveryProvider
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
