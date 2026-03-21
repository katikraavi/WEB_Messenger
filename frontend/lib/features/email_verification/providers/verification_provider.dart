import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/email_verification_service.dart';

/// Provider for EmailVerificationService singleton
final emailVerificationServiceProvider = Provider((ref) {
  return EmailVerificationService();
});

/// State for email verification flow
class VerificationState {
  final VerificationPhase phase;
  final String? userEmail;
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;
  final String? verificationToken;
  final String? devToken; // Development mode token for manual verification
  final int? retryAfterSeconds;

  VerificationState({
    this.phase = VerificationPhase.initial,
    this.userEmail,
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
    this.verificationToken,
    this.devToken,
    this.retryAfterSeconds,
  });

  /// Create a copy with optional field replacement
  VerificationState copyWith({
    VerificationPhase? phase,
    String? userEmail,
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
    String? verificationToken,
    String? devToken,
    int? retryAfterSeconds,
  }) {
    return VerificationState(
      phase: phase ?? this.phase,
      userEmail: userEmail ?? this.userEmail,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      successMessage: successMessage,
      verificationToken: verificationToken ?? this.verificationToken,
      devToken: devToken ?? this.devToken,
      retryAfterSeconds: retryAfterSeconds ?? this.retryAfterSeconds,
    );
  }

  /// Clear error messages
  VerificationState clearErrors() {
    return copyWith(
      errorMessage: null,
      successMessage: null,
    );
  }
}

enum VerificationPhase {
  initial,
  pending,
  verifying,
  verified,
  error,
}

/// Notifier for email verification state
class VerificationNotifier extends StateNotifier<VerificationState> {
  final EmailVerificationService verificationService;

  VerificationNotifier(this.verificationService)
      : super(VerificationState());

  /// Seed state from a registration response (email already sent by backend)
  ///
  /// This always resets phase to pending to avoid leaking stale verification
  /// state from previous auth attempts.
  void seedFromRegistration({required String email, String? devToken}) {
    state = state.copyWith(
      phase: VerificationPhase.pending,
      userEmail: email,
      isLoading: false,
      successMessage: 'Verification email sent to $email',
      devToken: devToken,
      verificationToken: null,
      errorMessage: null,
      retryAfterSeconds: null,
    );
  }

  /// Request verification email to be sent
  Future<void> sendVerificationEmail({
    required String email,
    String? userId,
    String? authToken,
  }) async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      successMessage: null,
    );

    try {
      final response = await verificationService.sendVerificationEmail(
        email: email,
        userId: userId ?? '',
        authToken: authToken,
      );

      if (response.success) {
        final message = response.devToken != null
          ? '${response.message}\n\n[DEV] Token: ${response.devToken!}\n\nOr copy this link:\n${response.devLink}'
          : response.message;
        
        state = state.copyWith(
          phase: VerificationPhase.pending,
          userEmail: email,
          isLoading: false,
          successMessage: message,
          devToken: response.devToken,
        );
      } else if (response.status == EmailVerificationStatus.rateLimited) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: response.message,
          retryAfterSeconds: response.resetTimeSeconds,
        );
      } else {
        state = state.copyWith(
          phase: VerificationPhase.error,
          isLoading: false,
          errorMessage: response.message,
        );
      }
    } catch (e) {
      state = state.copyWith(
        phase: VerificationPhase.error,
        isLoading: false,
        errorMessage: 'Failed to send verification email: ${e.toString()}',
      );
    }
  }

  /// Verify email with token (typically from deep link)
  Future<bool> verifyEmailToken({required String token}) async {
    state = state.copyWith(
      phase: VerificationPhase.verifying,
      isLoading: true,
      errorMessage: null,
    );

    try {
      final response = await verificationService.verifyEmail(token: token);

      if (response.success) {
        state = state.copyWith(
          phase: VerificationPhase.verified,
          isLoading: false,
          successMessage: 'Email verified successfully! You can now access the app.',
          verificationToken: token,
        );
        return true;
      } else if (response.status == EmailVerificationStatus.tokenExpired) {
        state = state.copyWith(
          phase: VerificationPhase.error,
          isLoading: false,
          errorMessage: response.message,
        );
        return false;
      } else {
        state = state.copyWith(
          phase: VerificationPhase.error,
          isLoading: false,
          errorMessage: response.message,
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        phase: VerificationPhase.error,
        isLoading: false,
        errorMessage: 'Verification failed: ${e.toString()}',
      );
      return false;
    }
  }

  /// Reset to initial state
  void reset() {
    state = VerificationState();
  }

  /// Clear error messages (for dismissing error banners)
  void clearErrors() {
    state = state.clearErrors();
  }

  /// Verify email with token (convenience method)
  /// This wraps verifyEmailToken for UI convenience
  Future<bool> verifyEmail({required String token}) async {
    return verifyEmailToken(token: token);
  }
}

/// Provider for the verification notifier
final verificationProvider =
    StateNotifierProvider<VerificationNotifier, VerificationState>((ref) {
  final service = ref.watch(emailVerificationServiceProvider);
  return VerificationNotifier(service);
});
