import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/auth_models.dart';
import '../services/auth_service.dart';
import '../providers/auth_provider.dart';

/// Login screen for existing users
class LoginScreen extends StatefulWidget {
  final VoidCallback? onLoginSuccess;
  final VoidCallback? onNavigateToRegistration;
  final VoidCallback? onNavigateToForgotPassword;

  const LoginScreen({
    Key? key,
    this.onLoginSuccess,
    this.onNavigateToRegistration,
    this.onNavigateToForgotPassword,
  }) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final Map<String, String?> _fieldErrors = {
    'email': null,
    'password': null,
  };

  bool _obscurePassword = true;
  bool _rememberMe = false;

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
    print('[LoginScreen] Login attempt started');
    
    // Clear any previous form-level errors
    if (mounted) {
      authProvider.clearError();
    }

    // Validate fields
    _validateEmail(_emailController.text);
    _validatePassword(_passwordController.text);

    // Check for any field errors
    if (_fieldErrors.values.any((error) => error != null)) {
      print('[LoginScreen] Validation errors found');
      return;
    }

    try {
      final request = LoginRequest(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      print('[LoginScreen] Calling authProvider.login()');
      await authProvider.login(request);
      print('[LoginScreen] Login successful');
      print('[LoginScreen] authProvider.user: ${authProvider.user?.username}');
      print('[LoginScreen] authProvider.token: ${authProvider.token != null ? 'present' : 'null'}');

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Login successful!'),
            duration: Duration(seconds: 2),
          ),
        );

        print('[LoginScreen] Calling onLoginSuccess callback');
        // Call success callback or navigate
        widget.onLoginSuccess?.call();
      }
    } catch (e, stackTrace) {
      print('[LoginScreen] Login error: $e');
      print('[LoginScreen] Stack trace: $stackTrace');
      
      // Error is already set in provider
      if (mounted) {
        final errorMessage = authProvider.error?.isNotEmpty == true 
          ? authProvider.error 
          : 'Login failed: Please check your email and password';
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage ?? 'Login failed'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        key: const PageStorageKey('login_scroll'),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Consumer<AuthProvider>(
              builder: (context, authProvider, child) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo or app name
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 24.0, bottom: 32.0),
                        child: Column(
                          children: [
                            Icon(
                              Icons.chat_bubble,
                              size: 64,
                              color: Colors.blue,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Mobile Messenger',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                          onPressed: widget.onNavigateToForgotPassword,
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Forgot password?',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue,
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
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: Colors.blue,
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
                                valueColor: AlwaysStoppedAnimation<Color>(
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
                          padding: EdgeInsets.symmetric(horizontal: 8.0),
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
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Test accounts section
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        border: Border.all(color: Colors.amber.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '🧪 Quick Test Accounts',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.person, size: 18),
                                  label: const Text('Person 1'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    side: BorderSide(color: Colors.amber.shade400),
                                  ),
                                  onPressed: () {
                                    _fillTestAccount('test1@example.com', 'Test123!');
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.person, size: 18),
                                  label: const Text('Person 2'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    side: BorderSide(color: Colors.amber.shade400),
                                  ),
                                  onPressed: () {
                                    _fillTestAccount('test2@example.com', 'Test123!');
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

