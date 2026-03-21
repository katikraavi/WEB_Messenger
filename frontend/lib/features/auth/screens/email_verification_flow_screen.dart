import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart';
import '../models/auth_models.dart';
import '../providers/auth_provider.dart';
import '../../email_verification/providers/verification_provider.dart';
import '../../email_verification/pages/verification_pending_screen.dart';
import '../../email_verification/pages/verification_success_screen.dart';

/// Email verification flow screen
///
/// Shown after successful registration
/// Guides user through email verification process
class EmailVerificationFlowScreen extends ConsumerStatefulWidget {
  final User user;
  final String email;
  final VoidCallback onVerificationComplete;
  final VoidCallback? onBack;
  final String? devToken;
  final LoginRequest? autoLoginRequest;
  final VoidCallback? onAutoLoginFailed;

  const EmailVerificationFlowScreen({
    Key? key,
    required this.user,
    required this.email,
    required this.onVerificationComplete,
    this.onBack,
    this.devToken,
    this.autoLoginRequest,
    this.onAutoLoginFailed,
  }) : super(key: key);

  @override
  ConsumerState<EmailVerificationFlowScreen> createState() =>
      _EmailVerificationFlowScreenState();
}

class _EmailVerificationFlowScreenState
    extends ConsumerState<EmailVerificationFlowScreen> {
  late final VerificationNotifier _verificationNotifier;
  bool _autoLoginStarted = false;
  String? _autoLoginError;

  @override
  void initState() {
    super.initState();
    _verificationNotifier = ref.read(verificationProvider.notifier);
    // Always reset to pending for each registration flow.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _verificationNotifier.seedFromRegistration(
        email: widget.email,
        devToken: widget.devToken,
      );
    });
  }

  @override
  void dispose() {
    // Don't reset provider in dispose - it causes Riverpod errors during widget tree finalization
    // The provider will be cleaned up automatically when the widget is disposed
    super.dispose();
  }

  Future<void> _attemptAutoLogin() async {
    final loginRequest = widget.autoLoginRequest;
    if (loginRequest == null) {
      widget.onVerificationComplete();
      return;
    }

    try {
      await context.read<AuthProvider>().login(loginRequest);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _autoLoginError = 'Email verified, but automatic sign-in failed.';
      });
      widget.onAutoLoginFailed?.call();
      return;
    }

    if (!mounted) return;
    widget.onVerificationComplete();
  }

  @override
  Widget build(BuildContext context) {
    final verificationState = ref.watch(verificationProvider);

    // Show success if verified
    if (verificationState.phase == VerificationPhase.verified) {
      if (widget.autoLoginRequest != null && _autoLoginError == null) {
        if (!_autoLoginStarted) {
          _autoLoginStarted = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _attemptAutoLogin();
          });
        }

        return const Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 24),
                    Text(
                      'Email verified. Signing you in...',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      return VerificationSuccessScreen(
        onContinue: widget.onVerificationComplete,
      );
    }

    // Show pending/loading/error
    return VerificationPendingScreen(
      email: widget.email,
      onBack: widget.onBack,
      onAlternateEmail: null,
    );
  }
}
