import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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

  static const List<
    ({String label, String email, String username, String name})
  >
  _testUsers = [
    (
      label: 'Alice',
      email: 'alice@example.com',
      username: 'alice',
      name: 'Alice Johnson',
    ),
    (
      label: 'Bob',
      email: 'bob@example.com',
      username: 'bob',
      name: 'Bob Smith',
    ),
    (
      label: 'Charlie',
      email: 'charlie@example.com',
      username: 'charlie',
      name: 'Charlie Brown',
    ),
    (
      label: 'Diane',
      email: 'diane@test.org',
      username: 'diane',
      name: 'Diane Miller',
    ),
    (
      label: 'TestUser1',
      email: 'testuser1@example.com',
      username: 'testuser1',
      name: 'Test User 1',
    ),
    (
      label: 'TestUser2',
      email: 'testuser2@example.com',
      username: 'testuser2',
      name: 'Test User 2',
    ),
  ];

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
        _fieldErrors['username'] =
            'Username must be 3-20 characters (alphanumeric + underscore)';
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
              Icon(
                Icons.science_outlined,
                color: Colors.blue.shade700,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                'Quick Test Accounts',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.blue.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Preset users for fast QA. Generate Unique always creates a fresh account.',
            style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade700),
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
                        _fillTestAccount(user.email, user.username, user.name),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.auto_fix_high, size: 16),
                  label: const Text('Generate Unique'),
                  onPressed: _fillGeneratedTestAccount,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Reset Form'),
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
      appBar: AppBar(title: const Text('Create Account'), elevation: 0),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 860;
          final cardWidth = kIsWeb ? 620.0 : (isWide ? 620.0 : 760.0);

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
                    key: const PageStorageKey('registration_scroll'),
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Consumer<AuthProvider>(
                        builder: (context, authProvider, child) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Create Your Account',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Set up profile details and start messaging',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                              const SizedBox(height: 20),
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
                              if (_showPasswordStrength &&
                                  _passwordStrengthErrors.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12.0),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade50,
                                      border: Border.all(
                                        color: Colors.orange.shade200,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                            padding: const EdgeInsets.only(
                                              top: 4.0,
                                            ),
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
                                                      color: Colors
                                                          .orange
                                                          .shade900,
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
                              else if (_showPasswordStrength &&
                                  _passwordStrengthErrors.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12.0),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      border: Border.all(
                                        color: Colors.green.shade200,
                                      ),
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
