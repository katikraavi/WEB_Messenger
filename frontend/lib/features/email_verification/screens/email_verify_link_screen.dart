import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:frontend/features/email_verification/services/email_verification_service.dart';
import 'package:frontend/core/services/api_client.dart';

/// Shown when the user opens the app via the email verification link.
/// Automatically POSTs the token to the backend, then calls [onDone]
/// so the app resumes its normal auth flow.
class EmailVerifyLinkScreen extends StatefulWidget {
  final String token;
  final VoidCallback onDone;

  const EmailVerifyLinkScreen({
    super.key,
    required this.token,
    required this.onDone,
  });

  @override
  State<EmailVerifyLinkScreen> createState() => _EmailVerifyLinkScreenState();
}

class _EmailVerifyLinkScreenState extends State<EmailVerifyLinkScreen> {
  bool _loading = true;
  bool _success = false;
  String _message = 'Verifying your email…';

  @override
  void initState() {
    super.initState();
    _verify();
  }

  Future<void> _verify() async {
    final service = EmailVerificationService(baseUrl: ApiClient.getBaseUrl());
    final result = await service.verifyEmail(token: widget.token);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _success = result.success;
      _message = result.success
          ? 'Your email has been verified! Redirecting to login…'
          : result.message;
    });
    if (result.success) {
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) widget.onDone();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = kIsWeb ? 520.0 : constraints.maxWidth;
            final horizontalPadding = kIsWeb ? 20.0 : 32.0;

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_loading) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
                Text(
                  _message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ] else if (_success) ...[
                const Icon(Icons.check_circle, color: Colors.green, size: 72),
                const SizedBox(height: 24),
                Text(
                  _message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ] else ...[
                const Icon(Icons.error_outline, color: Colors.red, size: 72),
                const SizedBox(height: 24),
                Text(
                  _message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: widget.onDone,
                  child: const Text('Go to Login'),
                ),
              ],
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
}
