import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../../../utils/copyable_error_widget.dart';
import '../models/auth_models.dart';
import '../services/auth_service.dart';
import '../providers/auth_provider.dart';

/// Login screen for existing users
class LoginScreen extends StatefulWidget {
  final VoidCallback? onLoginSuccess;
  final VoidCallback? onNavigateToRegistration;
  final VoidCallback? onNavigateToForgotPassword;
  final String? initialEmail;
  final String? initialPassword;

  const LoginScreen({
    super.key,
    this.onLoginSuccess,
    this.onNavigateToRegistration,
    this.onNavigateToForgotPassword,
    this.initialEmail,
    this.initialPassword,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final Map<String, String?> _fieldErrors = {'email': null, 'password': null};

  bool _obscurePassword = true;
  bool _rememberMe = false;

  static const List<({String label, String email, String password})>
  _testUsers = [
    (label: 'Alice', email: 'alice@example.com', password: 'alice123'),
    (label: 'Bob', email: 'bob@example.com', password: 'bob123'),
    (label: 'Charlie', email: 'charlie@example.com', password: 'charlie123'),
    (label: 'Diane', email: 'diane@test.org', password: 'diane123'),
    (
      label: 'TestUser1',
      email: 'testuser1@example.com',
      password: 'testuser1pass',
    ),
    (
      label: 'TestUser2',
      email: 'testuser2@example.com',
      password: 'testuser2pass',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _applyInitialCredentials();
  }

  @override
  void didUpdateWidget(covariant LoginScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialEmail != widget.initialEmail ||
        oldWidget.initialPassword != widget.initialPassword) {
      _applyInitialCredentials();
    }
  }

  void _applyInitialCredentials() {
    if (widget.initialEmail?.isNotEmpty == true) {
      _emailController.text = widget.initialEmail!;
    }
    if (widget.initialPassword?.isNotEmpty == true) {
      _passwordController.text = widget.initialPassword!;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _validateEmail(String value) {
    setState(() {
      if (value.isEmpty) {
        _fieldErrors['email'] = 'Email is required';
      } else if (!AuthService.validateEmail(value)) {
        _fieldErrors['email'] = 'Invalid email format';
      } else {
        _fieldErrors['email'] = null;
      }
    });
  }

  void _validatePassword(String value) {
    setState(() {
      if (value.isEmpty) {
        _fieldErrors['password'] = 'Password is required';
      } else if (value.length < 6) {
        _fieldErrors['password'] = 'Password must be at least 6 characters';
      } else {
        _fieldErrors['password'] = null;
      }
    });
  }

  Future<void> _handleLogin(AuthProvider authProvider) async {
    // Clear any previous form-level errors
    if (mounted) {
      authProvider.clearError();
    }

    // Validate fields
    _validateEmail(_emailController.text);
    _validatePassword(_passwordController.text);

    // Check for any field errors
    if (_fieldErrors.values.any((error) => error != null)) {
      return;
    }

    try {
      final request = LoginRequest(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      await authProvider.login(request);

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Login successful!'),
            duration: Duration(seconds: 2),
          ),
        );

        // Call success callback or navigate
        widget.onLoginSuccess?.call();
      }
    } catch (e) {
      // Error is already set in provider
      if (mounted) {
        final errorMessage = authProvider.error?.isNotEmpty == true
            ? authProvider.error
            : 'Login failed: Please check your email and password';

        showCopyableErrorSnackBar(context, errorMessage ?? 'Login failed');
      }
    }
  }

  void _fillTestAccount(String email, String password) {
    setState(() {
      _emailController.text = email;
      _passwordController.text = password;
      _fieldErrors['email'] = null;
      _fieldErrors['password'] = null;
    });
  }

  Widget _buildQuickTestSection() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        border: Border.all(color: const Color(0xFFCAD7F4)),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flash_on, color: Colors.blue.shade700, size: 16),
              const SizedBox(width: 6),
              Text(
                'Quick Test Login',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.blue.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _testUsers
                .map(
                  (user) => ActionChip(
                    avatar: const Icon(Icons.person_outline, size: 16),
                    label: Text(user.label),
                    onPressed: () =>
                        _fillTestAccount(user.email, user.password),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthHeader() {
    return Column(
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              colors: [Color(0xFF2563EB), Color(0xFF0EA5E9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withValues(alpha: 0.24),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.chat_bubble_rounded,
            color: Colors.white,
            size: 34,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Welcome Back',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          'Sign in to continue your conversations',
          style: TextStyle(color: Colors.grey.shade700),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login'), elevation: 0),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 860;
          final cardWidth = isWide ? 540.0 : 700.0;

          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFFE7F0FF),
                  Colors.white,
                  if (kIsWeb) const Color(0xFFF2F7FF),
                ],
              ),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: cardWidth),
                child: Card(
                  elevation: isWide ? 16 : 3,
                  shadowColor: Colors.blue.withValues(alpha: 0.15),
                  margin: const EdgeInsets.all(20),
                  child: SingleChildScrollView(
                    key: const PageStorageKey('login_scroll'),
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Consumer<AuthProvider>(
                        builder: (context, authProvider, child) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildAuthHeader(),
                              const SizedBox(height: 26),
                              _buildQuickTestSection(),
                              const SizedBox(height: 24),

                              // Email field
                              TextFormField(
                                controller: _emailController,
                                decoration: InputDecoration(
                                  labelText: 'Email',
                                  hintText: 'your.email@example.com',
                                  prefixIcon: const Icon(Icons.email_outlined),
                                  errorText: _fieldErrors['email'],
                                  border: const OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.emailAddress,
                                onChanged: _validateEmail,
                              ),
                              const SizedBox(height: 16),

                              // Password field
                              TextFormField(
                                controller: _passwordController,
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  hintText: 'Enter your password',
                                  prefixIcon: const Icon(Icons.lock_outlined),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                  errorText: _fieldErrors['password'],
                                  border: const OutlineInputBorder(),
                                ),
                                obscureText: _obscurePassword,
                                onChanged: _validatePassword,
                              ),
                              const SizedBox(height: 12),

                              // Remember me checkbox and Forgot password link
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Checkbox(
                                        value: _rememberMe,
                                        onChanged: (value) {
                                          setState(() {
                                            _rememberMe = value ?? false;
                                          });
                                        },
                                      ),
                                      const Text('Remember me'),
                                    ],
                                  ),
                                  TextButton(
                                    onPressed:
                                        widget.onNavigateToForgotPassword,
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text(
                                      'Forgot password?',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF1D4ED8),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),

                              // Login button
                              ElevatedButton(
                                onPressed: authProvider.isLoading
                                    ? null
                                    : () => _handleLogin(authProvider),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  backgroundColor: const Color(0xFF1D4ED8),
                                  disabledBackgroundColor: Colors.grey,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: authProvider.isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      )
                                    : const Text(
                                        'Login',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),

                              const SizedBox(height: 16),

                              // Divider
                              const Row(
                                children: [
                                  Expanded(child: Divider()),
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8.0,
                                    ),
                                    child: Text('OR'),
                                  ),
                                  Expanded(child: Divider()),
                                ],
                              ),

                              const SizedBox(height: 16),

                              // Sign up link
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    "Don't have an account? ",
                                    style: TextStyle(fontSize: 14),
                                  ),
                                  GestureDetector(
                                    onTap: widget.onNavigateToRegistration,
                                    child: const Text(
                                      'Create one',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF1D4ED8),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 24),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
