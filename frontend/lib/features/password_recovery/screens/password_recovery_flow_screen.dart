import 'package:flutter/material.dart';
import '../../auth/models/auth_models.dart';
import '../pages/forgot_password_screen.dart';

/// Password recovery flow screen
/// 
/// Entry point for password recovery initiated from auth flow
/// Displays ForgotPasswordScreen to request password reset
class PasswordRecoveryFlowScreen extends StatefulWidget {
  final User user;
  final VoidCallback onRecoveryComplete;

  const PasswordRecoveryFlowScreen({
    Key? key,
    required this.user,
    required this.onRecoveryComplete,
  }) : super(key: key);

  @override
  State<PasswordRecoveryFlowScreen> createState() =>
      _PasswordRecoveryFlowScreenState();
}

class _PasswordRecoveryFlowScreenState extends State<PasswordRecoveryFlowScreen> {
  @override
  Widget build(BuildContext context) {
    return ForgotPasswordScreen(
      onBackToLogin: widget.onRecoveryComplete,
    );
  }
}
