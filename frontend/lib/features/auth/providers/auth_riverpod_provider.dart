import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as provider_pkg;
import 'package:flutter/material.dart';
import 'auth_provider.dart';

/// Riverpod provider for accessing the AuthProvider from the old provider package
/// 
/// This bridges the old provider package with Riverpod by providing access to
/// the AuthProvider instance managed by the old system.
/// 
/// Usage:
/// ```dart
/// final authState = ref.watch(authRiverpodProvider);
/// authState.whenData((authProvider) {
///   print('Current user: ${authProvider.user?.username}');
/// });
/// ```
final authRiverpodProvider = Provider<AuthProvider>((ref) {
  // This will be called in a context where we can't access the provider directly
  // Instead, we'll create a dummy provider that users should override
  throw UnimplementedError(
    'authRiverpodProvider must be accessed from a context with the old provider package MultiProvider'
  );
});

/// Simple wrapper for auth state
class AuthState {
  final AuthProvider? provider;
  
  AuthState({this.provider});
  
  bool get isAuthenticated => provider?.isAuthenticated ?? false;
  String? get token => provider?.token;
  String? get userId => provider?.user?.userId;
  String? get username => provider?.user?.username;
  String? get email => provider?.user?.email;
}

/// Riverpod provider that wraps auth state for better Riverpod integration
/// 
/// This is a workaround because AuthProvider is managed by the old provider package.
/// Better approach would be to migrate fully to Riverpod.
final authStateProvider = StateProvider<AuthState>((ref) {
  return AuthState();
});
