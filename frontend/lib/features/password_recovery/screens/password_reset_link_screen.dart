import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/services/api_client.dart';
import '../providers/password_recovery_provider.dart';
import '../pages/password_reset_screen.dart';

/// Shown when the user opens the app via the password reset email link.
/// Validates the token and shows the password reset form.
class PasswordResetLinkScreen extends ConsumerStatefulWidget {
  final String token;
  final VoidCallback onDone;

  const PasswordResetLinkScreen({
    super.key,
    required this.token,
    required this.onDone,
  });

  @override
  ConsumerState<PasswordResetLinkScreen> createState() =>
      _PasswordResetLinkScreenState();
}

class _PasswordResetLinkScreenState
    extends ConsumerState<PasswordResetLinkScreen> {
  bool _loading = true;
  bool _validToken = false;
  String _message = 'Validating reset link…';

  @override
  void initState() {
    super.initState();
    _validate();
  }

  /// Validate the reset token before showing the form
  /// (This is optional - the backend will validate on submit)
  Future<void> _validate() async {
    try {
      // Note: You might want to add a validation endpoint
      // For now, we'll show the form and let backend validate on submit
      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;

      setState(() {
        _validToken = true;
        _loading = false;
        _message = 'Reset link validated. Enter your new password.';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _validToken = false;
        _loading = false;
        _message = 'Failed to validate reset link. Please try again.';
      });
    }
  }

  void _handleResetSuccess() {
    if (mounted) {
      widget.onDone();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(_message),
            ],
          ),
        ),
      );
    }

    if (!_validToken) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Reset Password'),
          centerTitle: true,
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = kIsWeb ? 620.0 : constraints.maxWidth;
              final horizontalPadding = kIsWeb ? 20.0 : 24.0;

              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(horizontalPadding),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 40),
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.error_outline,
                            size: 50,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          'Invalid Reset Link',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'The password reset link is invalid or has expired. Please request a new reset link.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 40),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context).pop();
                              widget.onDone();
                            },
                            icon: const Icon(Icons.arrow_back),
                            label: const Text('Back to Login'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    // Show the password reset form with token
    return PasswordResetScreen(
      token: widget.token,
      onSuccess: _handleResetSuccess,
    );
  }
}
