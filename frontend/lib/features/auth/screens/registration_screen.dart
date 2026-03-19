import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../utils/copyable_error_widget.dart';
import '../models/auth_models.dart';
import '../services/auth_service.dart';
import '../providers/auth_provider.dart';

/// Registration screen for new users
class RegistrationScreen extends StatefulWidget {
  final Function(User, String, String?, LoginRequest)? onRegistrationSuccess;
  final VoidCallback? onBackToLogin;

  const RegistrationScreen({
    Key? key,
    this.onRegistrationSuccess,
    this.onBackToLogin,
  }) : super(key: key);

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();

  final Map<String, String?> _fieldErrors = {
    'email': null,
    'username': null,
    'password': null,
    'fullName': null,
  };

  List<String> _passwordStrengthErrors = [];
  bool _showPasswordStrength = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
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

  void _validateUsername(String value) {
    setState(() {
      if (value.isEmpty) {
        _fieldErrors['username'] = 'Username is required';
      } else if (!AuthService.validateUsername(value)) {
        _fieldErrors['username'] = 'Username must be 3-20 characters (alphanumeric + underscore)';
      } else {
        _fieldErrors['username'] = null;
      }
    });
  }

  void _validatePassword(String value) {
    setState(() {
      _passwordStrengthErrors = AuthService.validatePassword(value);
      if (value.isEmpty) {
        _fieldErrors['password'] = 'Password is required';
      } else if (_passwordStrengthErrors.isNotEmpty) {
        _fieldErrors['password'] = 'Password does not meet requirements';
      } else {
        _fieldErrors['password'] = null;
      }
    });
  }

  void _validateFullName(String value) {
    setState(() {
      if (value.isEmpty) {
        _fieldErrors['fullName'] = 'Full name is required';
      } else {
        _fieldErrors['fullName'] = null;
      }
    });
  }

  void _fillTestAccount(String email, String username, String name) {
    setState(() {
      _emailController.text = email;
      _usernameController.text = username;
      _passwordController.text = 'Test123!';
      _fullNameController.text = name;
      _fieldErrors['email'] = null;
      _fieldErrors['username'] = null;
      _fieldErrors['password'] = null;
      _fieldErrors['fullName'] = null;
      _passwordStrengthErrors = [];
    });
  }

  void _fillGeneratedTestAccount() {
    final suffix = DateTime.now().millisecondsSinceEpoch.toString();
    _fillTestAccount(
      'test.$suffix@example.com',
      'test_$suffix',
      'Test User $suffix',
    );
  }

  Future<void> _handleRegistration(AuthProvider authProvider) async {
    // Clear any previous form-level errors
    if (mounted) {
      authProvider.clearError();
    }

    // Validate all fields first
    _validateEmail(_emailController.text);
    _validateUsername(_usernameController.text);
    _validatePassword(_passwordController.text);
    _validateFullName(_fullNameController.text);

    // Check for any field errors
    if (_fieldErrors.values.any((error) => error != null)) {
      return;
    }

    try {
      final request = RegistrationRequest(
        email: _emailController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        fullName: _fullNameController.text.trim(),
      );

      try {
        // Only call authProvider.register() - it handles the API call internally
        await authProvider.register(request);

        if (mounted) {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account created successfully! Verify your email.'),
              duration: Duration(seconds: 8),
            ),
          );

          // Navigate to email verification screen with user and email
          if (authProvider.user != null) {
            widget.onRegistrationSuccess?.call(
              authProvider.user!,
              request.email,
              authProvider.devVerificationToken,
              LoginRequest(email: request.email, password: request.password),
            );
          }
        }
      } catch (e) {
        // Show backend error details
        if (mounted) {
          showCopyableErrorSnackBar(
            context,
            'Registration failed: ${e.toString()}',
          );
        }
      }
    } catch (e) {
      // Error is already set in provider
      if (mounted) {
        showCopyableErrorSnackBar(
          context, 
          'Registration failed: ${authProvider.error ?? 'Unknown error occurred'}',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        key: const PageStorageKey('registration_scroll'),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Consumer<AuthProvider>(
              builder: (context, authProvider, child) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Test accounts section - AT TOP FOR VISIBILITY
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
                          const SizedBox(height: 6),
                          Text(
                            'These presets may already exist. Use Generate Unique for a guaranteed new account.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.orange.shade900,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.person, size: 18),
                                  label: const Text('Alice'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    side: BorderSide(color: Colors.amber.shade400),
                                  ),
                                  onPressed: () {
                                    _fillTestAccount('alice@example.com', 'alice', 'Alice Johnson');
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.person, size: 18),
                                  label: const Text('Bob'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    side: BorderSide(color: Colors.amber.shade400),
                                  ),
                                  onPressed: () {
                                    _fillTestAccount('bob@example.com', 'bob', 'Bob Smith');
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.person, size: 18),
                                  label: const Text('Charlie'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    side: BorderSide(color: Colors.amber.shade400),
                                  ),
                                  onPressed: () {
                                    _fillTestAccount('charlie@example.com', 'charlie', 'Charlie Brown');
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.person, size: 18),
                                  label: const Text('Diane'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    side: BorderSide(color: Colors.amber.shade400),
                                  ),
                                  onPressed: () {
                                    _fillTestAccount('diane@test.org', 'diane', 'Diane Miller');
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.auto_fix_high, size: 18),
                                  label: const Text('Generate Unique'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    side: BorderSide(color: Colors.amber.shade400),
                                  ),
                                  onPressed: () {
                                    _fillGeneratedTestAccount();
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.person, size: 18),
                                  label: const Text('Reset Form'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    side: BorderSide(color: Colors.amber.shade400),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _emailController.clear();
                                      _usernameController.clear();
                                      _passwordController.clear();
                                      _fullNameController.clear();
                                      _showPasswordStrength = false;
                                      _fieldErrors.updateAll((_, value) => null);
                                      _passwordStrengthErrors = [];
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
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

                    // Username field
                    TextFormField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        labelText: 'Username',
                        hintText: 'your_username',
                        prefixIcon: const Icon(Icons.person_outlined),
                        errorText: _fieldErrors['username'],
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: _validateUsername,
                    ),
                    const SizedBox(height: 16),

                    // Password field
                    TextFormField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        hintText: 'Enter a strong password',
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
                      onChanged: (value) {
                        _validatePassword(value);
                        setState(() {
                          _showPasswordStrength = value.isNotEmpty;
                        });
                      },
                    ),

                    // Password strength indicator
                    if (_showPasswordStrength && _passwordStrengthErrors.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            border: Border.all(color: Colors.orange.shade200),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Password requirements:',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade900,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ..._passwordStrengthErrors.map(
                                (error) => Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.close,
                                        size: 16,
                                        color: Colors.red.shade400,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          error,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.orange.shade900,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (_showPasswordStrength && _passwordStrengthErrors.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            border: Border.all(color: Colors.green.shade200),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                size: 16,
                                color: Colors.green.shade600,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Password is strong',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green.shade800,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Full name field
                    TextFormField(
                      controller: _fullNameController,
                      decoration: InputDecoration(
                        labelText: 'Full Name',
                        hintText: 'Your Full Name',
                        prefixIcon: const Icon(Icons.badge_outlined),
                        errorText: _fieldErrors['fullName'],
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: _validateFullName,
                    ),
                    const SizedBox(height: 24),

                    // Sign up button
                    ElevatedButton(
                      onPressed: authProvider.isLoading
                          ? null
                          : () => _handleRegistration(authProvider),
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
                              'Create Account',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),

                    const SizedBox(height: 16),

                    // Login link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Already have an account? ',
                          style: TextStyle(fontSize: 14),
                        ),
                        GestureDetector(
                          onTap: () {
                            // Use callback to navigate back to login within PageView
                            widget.onBackToLogin?.call();
                          },
                          child: const Text(
                            'Login',
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
