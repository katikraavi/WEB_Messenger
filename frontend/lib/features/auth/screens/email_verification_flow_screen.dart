import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/auth_models.dart';
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

  const EmailVerificationFlowScreen({
    Key? key,
    required this.user,
    required this.email,
    required this.onVerificationComplete,
  }) : super(key: key);

  @override
  ConsumerState<EmailVerificationFlowScreen> createState() =>
      _EmailVerificationFlowScreenState();
}

class _EmailVerificationFlowScreenState
    extends ConsumerState<EmailVerificationFlowScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize verification and send email
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeVerification();
    });
  }

  Future<void> _initializeVerification() async {
    // Send verification email via notifier
    await ref.read(verificationProvider.notifier).sendVerificationEmail(
      email: widget.email,
      userId: widget.user.userId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final verificationState = ref.watch(verificationProvider);

        // Show success if verified
        if (verificationState.phase == VerificationPhase.verified) {
          return VerificationSuccessScreen(
            onContinue: widget.onVerificationComplete,
          );
        }

        // Show pending/loading/error
        return VerificationPendingScreen(
          email: widget.email,
          onAlternateEmail: null,
        );
      },
    );
  }
}
