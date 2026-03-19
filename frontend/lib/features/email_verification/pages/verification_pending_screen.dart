import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../../../utils/copyable_error_widget.dart';
import '../providers/verification_provider.dart';

/// Screen shown while email verification is pending
/// User can resend verification email with countdown timer
class VerificationPendingScreen extends ConsumerStatefulWidget {
  final String email;
  final String? authToken;
  final VoidCallback? onAlternateEmail;
  final VoidCallback? onBack;

  const VerificationPendingScreen({
    Key? key,
    required this.email,
    this.authToken,
    this.onAlternateEmail,
    this.onBack,
  }) : super(key: key);

  @override
  ConsumerState<VerificationPendingScreen> createState() =>
      _VerificationPendingScreenState();
}

class _VerificationPendingScreenState
    extends ConsumerState<VerificationPendingScreen> {
  late Timer _resendTimer;
  int _resendCountdown = 60;
  bool _canResend = false;
  final TextEditingController _tokenController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _startResendCountdown();
  }

  void _startResendCountdown() {
    _resendCountdown = 60;
    _canResend = false;
    _resendTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _resendCountdown--;
        if (_resendCountdown <= 0) {
          _canResend = true;
          timer.cancel();
        }
      });
    });
  }

  /// Copy token to clipboard
  void _copyTokenToClipboard(String token) {
    Clipboard.setData(ClipboardData(text: token));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Token copied to clipboard!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// Auto-fill token field with dev token
  void _autoFillToken(String token) {
    _tokenController.text = token;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Token auto-filled - Click "Verify Email" to continue'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _resendTimer.cancel();
    _tokenController.dispose();
    super.dispose();
  }

  void _handleResendEmail() {
    ref
        .read(verificationProvider.notifier)
        .sendVerificationEmail(
          email: widget.email,
          authToken: widget.authToken,
        )
        .then((_) {
      if (mounted) _startResendCountdown();
    });
  }

  void _handleVerifyEmail() {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a verification token')),
      );
      return;
    }

    ref
        .read(verificationProvider.notifier)
        .verifyEmail(token: token)
        .then((_) {
      if (mounted) _tokenController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final verificationState = ref.watch(verificationProvider);

    return Scaffold(
      appBar: AppBar(
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              )
            : null,
        title: const Text('Verify Email'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Illustration/Icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.mail_outline,
                  size: 60,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 32),

              // Title
              Text(
                'Verification Email Sent',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Description
              Text(
                'We sent a verification link to\n${widget.email}',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Success/Error messages
              if (verificationState.successMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          verificationState.successMessage!,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.green),
                        ),
                      ),
                    ],
                  ),
                ),
              if (verificationState.errorMessage != null)
                CopyableErrorBanner(error: verificationState.errorMessage!),
              const SizedBox(height: 24),

              // Development Token Display (if available)
              if (verificationState.devToken != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.08),
                    border: Border.all(
                      color: Colors.blue.withOpacity(0.5),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.key,
                            color: Colors.blue[700],
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Verification Token (Dev Mode)',
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: Colors.blue[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.blue[200]!,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                verificationState.devToken!,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _copyTokenToClipboard(verificationState.devToken!),
                              icon: const Icon(Icons.copy, size: 18),
                              label: const Text('Copy Token'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _autoFillToken(verificationState.devToken!),
                              icon: const Icon(Icons.check, size: 18),
                              label: const Text('Auto-Fill'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Token input for testing/development
              Text(
                'Enter Verification Token (for testing)',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _tokenController,
                decoration: InputDecoration(
                  hintText: 'Paste verification token from email',
                  labelText: 'Verification Token',
                  prefixIcon: const Icon(Icons.key),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  suffixIcon: _tokenController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _tokenController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                ),
                maxLines: 2,
                minLines: 1,
                onChanged: (value) {
                  setState(() {}); // Update UI to show/hide clear button
                },
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: verificationState.isLoading
                      ? null
                      : _handleVerifyEmail,
                  icon: verificationState.isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).primaryColor,
                            ),
                          ),
                        )
                      : const Icon(Icons.check_circle),
                  label: Text(
                    verificationState.isLoading
                        ? 'Verifying...'
                        : 'Verify Email',
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Instructions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How to verify:',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 12),
                    ...[
                      '• Option 1: Paste the token above and click Verify',
                      '• Option 2: Open your email inbox',
                      '• Option 3: Find the email from Messenger',
                      '• Option 4: Click the verification link',
                    ].map((step) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        step,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    )),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Resend button
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    onPressed: _canResend && !verificationState.isLoading
                        ? _handleResendEmail
                        : null,
                    icon: const Icon(Icons.mail_outline),
                    label: Text(
                      _canResend
                          ? 'Resend Verification Email'
                          : 'Resend in $_resendCountdown seconds',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Loading indicator if verifying
              if (verificationState.isLoading)
                const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}
