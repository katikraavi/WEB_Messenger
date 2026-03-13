import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/password_recovery_service.dart';

/// Provider for PasswordRecoveryService singleton
final passwordRecoveryServiceProvider = Provider((ref) {
  return PasswordRecoveryService();
});

/// State for password recovery flow
class PasswordRecoveryState {
  final PasswordRecoveryPhase phase;
  final String? userEmail;
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;
  final String? resetToken;
  final List<String> passwordErrors;
  final int? retryAfterSeconds;

  PasswordRecoveryState({
    this.phase = PasswordRecoveryPhase.initial,
    this.userEmail,
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
    this.resetToken,
    this.passwordErrors = const [],
    this.retryAfterSeconds,
  });

  /// Create a copy with optional field replacement
  PasswordRecoveryState copyWith({
    PasswordRecoveryPhase? phase,
    String? userEmail,
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
    String? resetToken,
    List<String>? passwordErrors,
    int? retryAfterSeconds,
  }) {
    return PasswordRecoveryState(
      phase: phase ?? this.phase,
      userEmail: userEmail ?? this.userEmail,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      successMessage: successMessage,
      resetToken: resetToken ?? this.resetToken,
      passwordErrors: passwordErrors ?? this.passwordErrors,
      retryAfterSeconds: retryAfterSeconds ?? this.retryAfterSeconds,
    );
  }

  /// Clear error messages
  PasswordRecoveryState clearErrors() {
    return copyWith(
      errorMessage: null,
      successMessage: null,
      passwordErrors: [],
    );
  }
}

enum PasswordRecoveryPhase {
  initial,
  requestingSent,
  resetting,
  success,
  error,
}

/// Notifier for password recovery state
class PasswordRecoveryNotifier extends StateNotifier<PasswordRecoveryState> {
  final PasswordRecoveryService recoveryService;

  PasswordRecoveryNotifier(this.recoveryService) : super(PasswordRecoveryState());

  /// Request password reset email
  Future<void> requestPasswordReset({
    required String email,
    required String userId,
  }) async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      successMessage: null,
    );

    try {
      final response = await recoveryService.requestPasswordReset(
        email: email,
        userId: userId,
      );

      if (response.success) {
        state = state.copyWith(
          phase: PasswordRecoveryPhase.requestingSent,
          userEmail: email,
          isLoading: false,
          successMessage: 'Password reset email sent to $email. Check your inbox.',
        );
      } else if (response.status == PasswordRecoveryStatus.rateLimited) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: response.message,
          retryAfterSeconds: response.retryAfterSeconds,
        );
      } else {
        state = state.copyWith(
          phase: PasswordRecoveryPhase.error,
          isLoading: false,
          errorMessage: response.message,
        );
      }
    } catch (e) {
      state = state.copyWith(
        phase: PasswordRecoveryPhase.error,
        isLoading: false,
        errorMessage: 'Failed to request password reset: ${e.toString()}',
      );
    }
  }

  /// Reset password with token
  Future<bool> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    state = state.copyWith(
      phase: PasswordRecoveryPhase.resetting,
      isLoading: true,
      errorMessage: null,
      passwordErrors: [],
    );

    try {
      final response = await recoveryService.resetPassword(
        token: token,
        newPassword: newPassword,
      );

      if (response.success) {
        state = state.copyWith(
          phase: PasswordRecoveryPhase.success,
          isLoading: false,
          successMessage: 'Password reset successfully! You can now log in.',
          resetToken: token,
        );
        return true;
      } else if (response.status == PasswordRecoveryStatus.tokenExpired) {
        state = state.copyWith(
          phase: PasswordRecoveryPhase.error,
          isLoading: false,
          errorMessage: response.message,
        );
        return false;
      } else if (response.status == PasswordRecoveryStatus.validationError) {
        state = state.copyWith(
          phase: PasswordRecoveryPhase.error,
          isLoading: false,
          errorMessage: response.message,
          passwordErrors: response.validationErrors,
        );
        return false;
      } else {
        state = state.copyWith(
          phase: PasswordRecoveryPhase.error,
          isLoading: false,
          errorMessage: response.message,
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        phase: PasswordRecoveryPhase.error,
        isLoading: false,
        errorMessage: 'Password reset failed: ${e.toString()}',
      );
      return false;
    }
  }

  /// Reset to initial state
  void reset() {
    state = PasswordRecoveryState();
  }

  /// Clear error messages
  void clearErrors() {
    state = state.clearErrors();
  }
}

/// Provider for the password recovery notifier
final passwordRecoveryProvider =
    StateNotifierProvider<PasswordRecoveryNotifier, PasswordRecoveryState>(
        (ref) {
  final service = ref.watch(passwordRecoveryServiceProvider);
  return PasswordRecoveryNotifier(service);
});
