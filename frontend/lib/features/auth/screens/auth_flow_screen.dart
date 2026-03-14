import 'package:flutter/material.dart';
import '../models/auth_models.dart';
import 'login_screen.dart';
import 'registration_screen.dart';
import 'email_verification_flow_screen.dart';
import '../../password_recovery/screens/password_recovery_flow_screen.dart';

/// Auth flow screen - Routes between login, registration, and email verification
/// 
/// Handles the complete authentication flow:
/// - Shows login by default
/// - Allows navigation to registration
/// - After successful registration, shows email verification
/// - After successful verification, returns to login
/// - After successful login, calls onAuthSuccess callback
class AuthFlowScreen extends StatefulWidget {
  final VoidCallback? onAuthSuccess;

  const AuthFlowScreen({
    Key? key,
    this.onAuthSuccess,
  }) : super(key: key);

  @override
  State<AuthFlowScreen> createState() => _AuthFlowScreenState();
}

class _AuthFlowScreenState extends State<AuthFlowScreen> {
  late PageController _pageController;
  int _currentPage = 0; // 0 = login, 1 = registration, 2 = email verification, 3 = password recovery
  User? _registeredUser;
  String? _registeredEmail;
  bool _showPasswordRecovery = false;
  User? _recoveryUser;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _navigateToRegistration() {
    _pageController.animateToPage(
      1,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _navigateToEmailVerification(User user, String email) {
    _registeredUser = user;
    _registeredEmail = email;
    _pageController.animateToPage(
      2,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _navigateToLogin() {
    setState(() {
      _showPasswordRecovery = false;
      _registeredUser = null;
      _registeredEmail = null;
    });
    _pageController.animateToPage(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _navigateToPasswordRecovery() {
    // Create a temporary user for the recovery flow
    _recoveryUser = User(
      userId: 'temp-recovery-user',
      username: 'temp',
      email: '',
    );
    setState(() {
      _showPasswordRecovery = true;
    });
    _pageController.animateToPage(
      3,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PageView(
      controller: _pageController,
      onPageChanged: (page) {
        setState(() => _currentPage = page);
      },
      children: [
        // Login screen
        LoginScreen(
          onLoginSuccess: widget.onAuthSuccess,
          onNavigateToRegistration: _navigateToRegistration,
          onNavigateToForgotPassword: _navigateToPasswordRecovery,
        ),
        // Registration screen
        RegistrationScreen(
          onRegistrationSuccess: (user, email) {
            _navigateToEmailVerification(user, email);
          },
          onBackToLogin: _navigateToLogin,
        ),
        // Email verification screen (only shown if _registeredUser is set)
        if (_registeredUser != null && _registeredEmail != null)
          EmailVerificationFlowScreen(
            user: _registeredUser!,
            email: _registeredEmail!,
            onVerificationComplete: () {
              // After verification, return to login
              _navigateToLogin();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Email verified! Please log in.'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 3),
                ),
              );
            },
          )
        else
          const SizedBox.shrink(), // Placeholder for verification screen
        // Password recovery screen
        if (_showPasswordRecovery && _recoveryUser != null)
          PasswordRecoveryFlowScreen(
            user: _recoveryUser!,
            onRecoveryComplete: () {
              // After recovery request, return to login
              _navigateToLogin();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Password reset email sent. Check your inbox!'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 3),
                ),
              );
            },
          )
        else
          const SizedBox.shrink(), // Placeholder for recovery screen
      ],
    );
  }
}
