/// Result of password validation
class ValidationResult {
  /// Whether password meets all strength requirements
  final bool isValid;

  /// List of specific validation failure messages
  /// Empty if password is valid
  final List<String> errors;

  /// Creates a [ValidationResult] with validation status and error messages
  ValidationResult({required this.isValid, required this.errors});

  /// Convenience constructor for valid password (no errors)
  ValidationResult.valid() : this(isValid: true, errors: []);

  /// Convenience constructor for invalid password with error message
  ValidationResult.invalid(String error) : this(isValid: false, errors: [error]);
}

/// Validates password strength requirements
class PasswordValidator {
  /// Minimum password length required
  static const int minLength = 8;

  /// Special characters allowed in password
  static const String specialChars = r'@$!%*?&';

  /// Validates password against strength requirements
  ///
  /// Returns [ValidationResult] with isValid=true if password meets ALL criteria:
  /// - At least 8 characters
  /// - At least one lowercase letter
  /// - At least one uppercase letter
  /// - At least one digit
  /// - At least one special character from [@$!%*?&]
  ///
  /// Returns [ValidationResult] with specific error messages for each failure
  static ValidationResult validate(String password) {
    final errors = <String>[];

    if (password.isEmpty) {
      errors.add('Password cannot be empty');
      return ValidationResult(isValid: false, errors: errors);
    }

    if (password.length < minLength) {
      errors.add('Password must be at least $minLength characters long');
    }

    if (!password.contains(RegExp(r'[a-z]'))) {
      errors.add('Password must contain at least one lowercase letter');
    }

    if (!password.contains(RegExp(r'[A-Z]'))) {
      errors.add('Password must contain at least one uppercase letter');
    }

    if (!password.contains(RegExp(r'[0-9]'))) {
      errors.add('Password must contain at least one digit (0-9)');
    }

    if (!password.contains(RegExp('[$specialChars]'))) {
      errors.add('Password must contain at least one special character (@\$!%*?&)');
    }

    return ValidationResult(isValid: errors.isEmpty, errors: errors);
  }
}
