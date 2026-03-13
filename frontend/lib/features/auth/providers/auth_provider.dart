import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
  User? _user;
  String? _token;
  bool _isLoading = false;
  String? _error;
  
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // Getters
  User? get user => _user;
  String? get token => _token;
  bool get isLoading => _isLoading;
  String? get error => _error;
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
      print('Error initializing auth: $e');
    }
    
    _isLoading = false;
    notifyListeners();
  }

  /// Register new user
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
      print('[AuthProvider] Login attempt for email: ${request.email}');
      final authResponse = await AuthService.login(request);
      print('[AuthProvider] Login response received');
      print('[AuthProvider] User ID: ${authResponse.userId}');
      print('[AuthProvider] Token: ${authResponse.token != null ? 'present' : 'null'}');
      
      // Store token securely
      _token = authResponse.token;
      if (_token != null) {
        print('[AuthProvider] Storing token in secure storage');
        try {
          await _secureStorage.write(key: 'auth_token', value: _token!);
          await _secureStorage.write(key: 'user_id', value: authResponse.userId);
          print('[AuthProvider] Token stored successfully');
        } catch (storageError) {
          print('[AuthProvider] Error storing token: $storageError');
          // Continue anyway - token is in memory
        }
      }
      
      // Set user
      _user = User(
        userId: authResponse.userId,
        email: authResponse.email,
        username: authResponse.username,
      );
      
      print('[AuthProvider] User set: ${_user?.username}');
      print('[AuthProvider] isAuthenticated: $isAuthenticated');
      
      _isLoading = false;
      notifyListeners();
      print('[AuthProvider] notifyListeners() called');
    } catch (e) {
      print('[AuthProvider] Login error: $e');
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
      print('Logout error: $e');
    }

    // Clear local state
    _user = null;
    _token = null;
    
    // Clear secure storage
    await _secureStorage.delete(key: 'auth_token');
    await _secureStorage.delete(key: 'user_id');

    _isLoading = false;
    notifyListeners();
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
