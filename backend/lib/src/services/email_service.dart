import 'dart:async';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

/// EmailService handles sending transactional emails.
///
/// Configuration comes from environment variables (see docker-compose.yml):
///   SMTP_HOST, SMTP_PORT, SMTP_FROM_EMAIL, SMTP_FROM_NAME,
///   SMTP_USER, SMTP_PASSWORD, SMTP_SECURE
///
/// Dev: point at Mailhog (mailhog:1025) — web UI at http://localhost:8025
/// Prod: point at any real SMTP provider (SendGrid, Mailgun, Gmail, etc.)
class EmailService {
  final String? smtpHost;
  final int? smtpPort;
  final String? senderEmail;
  final String? senderName;
  final String? smtpUser;
  final String? smtpPassword;
  final bool smtpSecure;

  EmailService({
    this.smtpHost,
    this.smtpPort,
    this.senderEmail,
    this.senderName,
    this.smtpUser,
    this.smtpPassword,
    this.smtpSecure = false,
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
    String? registeredAt,
  }) {
    // Extract token from verification link (format: ?token=TOKEN)
    final tokenMatch = RegExp(r'token=([^&]+)').firstMatch(verificationLink);
    final token = tokenMatch?.group(1) ?? '';
    final registrationTime = registeredAt ?? DateTime.now().toUtc().toString().substring(0, 19).replaceAll('T', ' ') + ' UTC';
    
    final subject = '🔐 Your Email Verification Code: $token';
    
    final htmlBody = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #f5f5f5; color: #333; }
    .container { max-width: 500px; margin: 20px auto; background: white; border-radius: 12px; box-shadow: 0 2px 8px rgba(0,0,0,0.1); overflow: hidden; }
    .header { background: linear-gradient(135deg, #007bff 0%, #0056b3 100%); color: white; padding: 30px 20px; text-align: center; }
    .header h1 { font-size: 24px; margin-bottom: 5px; }
    .header p { font-size: 14px; opacity: 0.9; }
    .content { padding: 30px 20px; }
    .greeting { font-size: 16px; margin-bottom: 20px; }
    .code-section { background: #f8f9fa; border-left: 4px solid #007bff; padding: 20px; border-radius: 8px; margin: 25px 0; text-align: center; }
    .code-label { font-size: 12px; color: #666; margin-bottom: 12px; font-weight: 600; text-transform: uppercase; letter-spacing: 1px; }
    .code-box { background: white; border: 2px solid #e9ecef; border-radius: 8px; padding: 20px; margin: 10px 0; }
    .code-value { font-family: 'Courier New', 'Monaco', monospace; font-size: 32px; font-weight: bold; color: #007bff; letter-spacing: 4px; word-break: break-all; line-height: 1.4; }
    .copy-hint { font-size: 12px; color: #999; margin-top: 12px; }
    .account-info { background: #f0f4ff; border: 1px solid #d0deff; border-radius: 8px; padding: 16px; margin: 20px 0; }
    .account-info-title { font-size: 12px; font-weight: 700; color: #0056b3; text-transform: uppercase; letter-spacing: 1px; margin-bottom: 12px; }
    .account-row { display: flex; justify-content: space-between; padding: 6px 0; border-bottom: 1px solid #e0e8ff; font-size: 13px; }
    .account-row:last-child { border-bottom: none; }
    .account-key { color: #666; font-weight: 500; }
    .account-val { color: #222; font-weight: 600; font-family: 'Courier New', monospace; word-break: break-all; max-width: 60%; text-align: right; }
    .instructions { background: #e7f3ff; border-left: 4px solid #0056b3; padding: 15px; border-radius: 6px; margin: 20px 0; font-size: 14px; }
    .instructions-title { font-weight: 600; color: #0056b3; margin-bottom: 8px; }
    .instructions p { margin: 6px 0; color: #333; }
    .step { display: flex; align-items: flex-start; margin: 10px 0; }
    .step-number { background: #0056b3; color: white; width: 24px; height: 24px; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-weight: bold; font-size: 12px; flex-shrink: 0; margin-right: 10px; margin-top: 2px; }
    .button { display: inline-block; background: #007bff; color: white; padding: 14px 40px; text-decoration: none; border-radius: 6px; font-weight: 600; margin: 20px 0; }
    .divider { border: 0; border-top: 1px solid #e9ecef; margin: 25px 0; }
    .expires { font-size: 12px; color: #999; text-align: center; margin: 15px 0; }
    .footer { background: #f8f9fa; padding: 20px; text-align: center; font-size: 11px; color: #999; border-top: 1px solid #e9ecef; }
    .warning { background: #fff3cd; border-left: 4px solid #ffc107; padding: 12px; border-radius: 4px; font-size: 12px; color: #856404; margin-top: 15px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>Email Verification</h1>
      <p>Mobile Messenger</p>
    </div>
    
    <div class="content">
      <p class="greeting">Hi $recipientName! 👋</p>
      <p>Welcome to Mobile Messenger! To complete your account setup, please verify your email address.</p>

      <div class="account-info">
        <div class="account-info-title">📋 Your Account Details</div>
        <div class="account-row">
          <span class="account-key">Username</span>
          <span class="account-val">$recipientName</span>
        </div>
        <div class="account-row">
          <span class="account-key">Email</span>
          <span class="account-val">$recipientEmail</span>
        </div>
        <div class="account-row">
          <span class="account-key">Registered</span>
          <span class="account-val">$registrationTime</span>
        </div>
        <div class="account-row">
          <span class="account-key">Status</span>
          <span class="account-val" style="color:#e67e00;">⏳ Pending Verification</span>
        </div>
      </div>
      
      <div class="code-section">
        <div class="code-label">Your Verification Code</div>
        <div class="code-box">
          <div class="code-value">$token</div>
        </div>
        <div class="copy-hint">📋 Click to select and copy this code</div>
      </div>
      
      <div class="instructions">
        <div class="instructions-title">📱 How to verify:</div>
        <div class="step">
          <div class="step-number">1</div>
          <div>Open the Mobile Messenger app</div>
        </div>
        <div class="step">
          <div class="step-number">2</div>
          <div>Go to the verification screen</div>
        </div>
        <div class="step">
          <div class="step-number">3</div>
          <div>Paste the code above into the input field</div>
        </div>
        <div class="step">
          <div class="step-number">4</div>
          <div>Tap <strong>Verify</strong></div>
        </div>
      </div>
      
      <center>
        <a href="$verificationLink" class="button">Or Click Here to Verify</a>
      </center>
      
      <div class="divider"></div>
      
      <p style="font-size: 13px; line-height: 1.6;">
        <strong>Can't see the input field?</strong> Make sure you're logged out first. This verification link is only for web browsers.
      </p>
      
      <div class="expires">
        ⏰ This code expires in <strong>$expiresIn</strong>
      </div>
      
      <div class="warning">
        ⚠️ Never share this code with anyone. Mobile Messenger staff will never ask for it.
      </div>
    </div>
    
    <div class="footer">
      <p>© ${DateTime.now().year} Mobile Messenger. All rights reserved.</p>
      <p style="margin-top: 8px;">If you didn't create this account, you can safely ignore this email.</p>
    </div>
  </div>
</body>
</html>
''';

    final plainTextBody = '''
╔═══════════════════════════════════════════╗
║     EMAIL VERIFICATION - MOBILE MESSENGER   ║
╚═══════════════════════════════════════════╝

Hi $recipientName!

Welcome to Mobile Messenger! To complete your account setup, 
please verify your email address.

┌─────────────────────────────────────┐
│        YOUR ACCOUNT DETAILS         │
├─────────────────────────────────────┤
│ Username  : $recipientName
│ Email     : $recipientEmail
│ Registered: $registrationTime
│ Status    : Pending Verification
└─────────────────────────────────────┘

YOUR VERIFICATION CODE:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
$token
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📱 HOW TO VERIFY:
  1. Open the Mobile Messenger app
  2. Go to the verification screen
  3. Paste the code above into the input field
  4. Tap Verify

VERIFICATION LINK (for web):
$verificationLink

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

⏰ This code expires in $expiresIn

⚠️ SECURITY WARNING:
   Never share this code with anyone.
   Mobile Messenger staff will never ask for it.

If you didn't create this account, you can safely ignore this email.

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
    if (_isNotConfigured()) {
      // No SMTP configured — log and skip.
      // In dev mode the verification handler returns the token directly
      // in the API response, so testing still works without a mail server.
      print('[EMAIL] No SMTP configured — email NOT sent to ${message.to}');
      print('[EMAIL] Set SMTP_HOST env var (or use Mailhog in docker-compose) to send real emails.');
      if (bool.fromEnvironment('dart.vm.product')) {
        throw EmailSendException('Email service not configured for production');
      }
      return true;
    }

    try {
      final smtpServer = SmtpServer(
        smtpHost!,
        port: smtpPort!,
        username: (smtpUser?.isNotEmpty == true) ? smtpUser : null,
        password: (smtpPassword?.isNotEmpty == true) ? smtpPassword : null,
        ssl: smtpSecure,
        ignoreBadCertificate: !smtpSecure,
        allowInsecure: !smtpSecure,
      );

      final msg = Message()
        ..from = Address(senderEmail!, senderName ?? 'Mobile Messenger')
        ..recipients.add(message.to)
        ..subject = message.subject
        ..html = message.htmlBody
        ..text = message.plainTextBody;

      for (final cc in message.cc) msg.ccRecipients.add(cc);
      for (final bcc in message.bcc) msg.bccRecipients.add(bcc);

      await send(msg, smtpServer).timeout(
        const Duration(seconds: 45),
        onTimeout: () => throw TimeoutException(
          'SMTP send timed out after 45 seconds',
        ),
      );
      print('[✓] Email sent to ${message.to}: ${message.subject}');
      return true;
    } on TimeoutException catch (e) {
      throw EmailSendException('SMTP timeout: ${e.message}');
    } on MailerException catch (e) {
      throw EmailSendException(
          'SMTP error: ${e.message} — ${e.problems.map((p) => p.msg).join(', ')}');
    } on Exception catch (e) {
      throw EmailSendException('Failed to send email: $e');
    }
  }

  bool _isNotConfigured() =>
      smtpHost == null || smtpPort == null || senderEmail == null;
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
