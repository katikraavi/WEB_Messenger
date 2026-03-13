import 'dart:async';

/// EmailService handles sending transactional emails
/// 
/// Responsibilities:
/// - Build email templates (verification, password reset)
/// - Send emails via configured provider
/// - Handle email failures gracefully
class EmailService {
  // Email configuration (would come from environment in production)
  final String? smtpHost;
  final int? smtpPort;
  final String? senderEmail;
  final String? senderName;

  EmailService({
    this.smtpHost,
    this.smtpPort,
    this.senderEmail,
    this.senderName,
  });

  /// Build a verification email
  /// 
  /// Parameters:
  /// - recipientEmail: Email address to send to
  /// - recipientName: Name of recipient (for personalization)
  /// - verificationLink: Complete verification URL with token
  /// - expiresIn: How long the link is valid (e.g., "24 hours")
  /// 
  /// Returns: EmailMessage with HTML and plain text versions
  EmailMessage buildVerificationEmail({
    required String recipientEmail,
    required String recipientName,
    required String verificationLink,
    required String expiresIn,
  }) {
    final subject = 'Verify Your Email Address';
    
    final htmlBody = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
    .header { text-align: center; margin-bottom: 30px; }
    .content { background: #f7f7f7; padding: 20px; border-radius: 5px; margin-bottom: 20px; }
    .button { display: inline-block; background: #007bff; color: white; padding: 12px 30px; text-decoration: none; border-radius: 5px; margin: 20px 0; }
    .footer { font-size: 12px; color: #999; text-align: center; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>Verify Your Email</h1>
    </div>
    
    <div class="content">
      <p>Hi $recipientName,</p>
      
      <p>Welcome! Please verify your email address to complete your account setup.</p>
      
      <p>
        <a href="$verificationLink" class="button">Verify Email</a>
      </p>
      
      <p>Or copy and paste this link in your browser:</p>
      <p style="word-break: break-all; color: #666;">$verificationLink</p>
      
      <p style="color: #999; font-size: 12px;">
        This link expires in $expiresIn. If you didn't create this account, please ignore this email.
      </p>
    </div>
    
    <div class="footer">
      <p>© ${DateTime.now().year} Mobile Messenger. All rights reserved.</p>
    </div>
  </div>
</body>
</html>
''';

    final plainTextBody = '''
Verify Your Email

Hi $recipientName,

Welcome! Please verify your email address to complete your account setup.

Verification Link:
$verificationLink

This link expires in $expiresIn. If you didn't create this account, please ignore this email.

© ${DateTime.now().year} Mobile Messenger
''';

    return EmailMessage(
      to: recipientEmail,
      subject: subject,
      htmlBody: htmlBody,
      plainTextBody: plainTextBody,
    );
  }

  /// Build a password reset email
  /// 
  /// Parameters:
  /// - recipientEmail: Email address to send to
  /// - recipientName: Name of recipient
  /// - resetLink: Complete password reset URL with token
  /// - expiresIn: How long the link is valid (e.g., "2 hours")
  /// 
  /// Returns: EmailMessage with HTML and plain text versions
  EmailMessage buildPasswordResetEmail({
    required String recipientEmail,
    required String recipientName,
    required String resetLink,
    required String expiresIn,
  }) {
    final subject = 'Reset Your Password';
    
    final htmlBody = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
    .header { text-align: center; margin-bottom: 30px; }
    .alert { background: #fff3cd; padding: 15px; border-radius: 5px; margin-bottom: 20px; color: #856404; }
    .content { background: #f7f7f7; padding: 20px; border-radius: 5px; margin-bottom: 20px; }
    .button { display: inline-block; background: #007bff; color: white; padding: 12px 30px; text-decoration: none; border-radius: 5px; margin: 20px 0; }
    .footer { font-size: 12px; color: #999; text-align: center; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>Reset Your Password</h1>
    </div>
    
    <div class="alert">
      <strong>Security Alert:</strong> We received a request to reset your password. If you didn't make this request, please ignore this email.
    </div>
    
    <div class="content">
      <p>Hi $recipientName,</p>
      
      <p>Click the button below to reset your password:</p>
      
      <p>
        <a href="$resetLink" class="button">Reset Password</a>
      </p>
      
      <p>Or copy and paste this link in your browser:</p>
      <p style="word-break: break-all; color: #666;">$resetLink</p>
      
      <p style="color: #999; font-size: 12px;">
        This link expires in $expiresIn. For security reasons, you can only use this link once.
      </p>
    </div>
    
    <div class="footer">
      <p>© ${DateTime.now().year} Mobile Messenger. All rights reserved.</p>
    </div>
  </div>
</body>
</html>
''';

    final plainTextBody = '''
Reset Your Password

SECURITY ALERT: We received a request to reset your password. If you didn't make this request, please ignore this email.

Hi $recipientName,

Click the link below to reset your password:

$resetLink

This link expires in $expiresIn. For security reasons, you can only use this link once.

© ${DateTime.now().year} Mobile Messenger
''';

    return EmailMessage(
      to: recipientEmail,
      subject: subject,
      htmlBody: htmlBody,
      plainTextBody: plainTextBody,
    );
  }

  /// Send an email
  /// 
  /// Parameters:
  /// - message: EmailMessage to send
  /// 
  /// Throws:
  /// - EmailSendException: If email sending fails
  /// 
  /// Returns: True if email was sent successfully
  Future<bool> sendEmail(EmailMessage message) async {
    // Allow sending in development mode even if SMTP not configured
    // In production, require proper configuration
    bool isProduction = bool.fromEnvironment('dart.vm.product');
    if (isProduction && _isNotConfigured()) {
      throw EmailSendException('Email service not configured');
    }

    try {
      // Development mode: Log email to console
      if (_isNotConfigured()) {
        print('═══════════════════════════════════════════════════════════');
        print('[EMAIL] Development Mode - Email would be sent:');
        print('[EMAIL] To: ${message.to}');
        print('[EMAIL] Subject: ${message.subject}');
        print('[EMAIL] ═══════════════════════════════════════════════════════════');
        return true;
      }

      // TODO: Implement actual SMTP or SendGrid integration
      // In production, use package:mailer or SendGrid API client
      
      // Example with mailer package:
      // final email = Email(
      //   from: '$senderName <$senderEmail>',
      //   recipients: [message.to],
      //   subject: message.subject,
      //   html: message.htmlBody,
      //   textAltContent: message.plainTextBody,
      // );
      // await send(email, smtpServer);
      
      return true;
    } on Exception catch (e) {
      throw EmailSendException('Failed to send email: ${e.toString()}');
    }
  }

  /// Check if email service is properly configured
  bool _isNotConfigured() {
    return smtpHost == null || 
           smtpPort == null || 
           senderEmail == null;
  }
}

/// Represents an email message to send
class EmailMessage {
  final String to;
  final String subject;
  final String htmlBody;
  final String plainTextBody;
  final List<String> cc;
  final List<String> bcc;

  EmailMessage({
    required this.to,
    required this.subject,
    required this.htmlBody,
    required this.plainTextBody,
    this.cc = const [],
    this.bcc = const [],
  });

  @override
  String toString() => 'EmailMessage(to: $to, subject: $subject)';
}

/// Exception thrown when email sending fails
class EmailSendException implements Exception {
  final String message;

  EmailSendException(this.message);

  @override
  String toString() => 'EmailSendException: $message';
}
