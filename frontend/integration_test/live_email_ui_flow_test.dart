import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/auth/models/auth_models.dart';
import 'package:frontend/features/auth/providers/auth_provider.dart';
import 'package:frontend/features/auth/screens/registration_screen.dart';
import 'package:frontend/features/password_recovery/pages/forgot_password_screen.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart' as provider;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final shouldRunLiveTests =
      Platform.environment['RUN_LIVE_EMAIL_UI_TESTS'] == 'true';

  group('Live Email UI Flow', () {
    testWidgets(
      'registers through the UI and requests password reset through the UI',
      (tester) async {
        final suffix = DateTime.now().millisecondsSinceEpoch.toString();
        final email = 'ui.live.$suffix@example.com';
        final username = 'uilive_$suffix';
        const password = 'Test123!';
        final fullName = 'UI Live Test $suffix';

        User? registeredUser;
        String? callbackEmail;
        String? callbackToken;
        LoginRequest? callbackLogin;

        await tester.pumpWidget(
          MaterialApp(
            home: provider.ChangeNotifierProvider(
              create: (_) => AuthProvider(),
              child: RegistrationScreen(
                onRegistrationSuccess: (user, registrationEmail, devToken, loginRequest) {
                  registeredUser = user;
                  callbackEmail = registrationEmail;
                  callbackToken = devToken;
                  callbackLogin = loginRequest;
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(_findTextFormField('Email'), email);
        await tester.enterText(_findTextFormField('Username'), username);
        await tester.enterText(_findTextFormField('Password'), password);
        await tester.enterText(_findTextFormField('Full Name'), fullName);
        await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Create Account'));
        await tester.tap(find.widgetWithText(ElevatedButton, 'Create Account'));
        await tester.pump();

        await _pumpUntil(
          tester,
          () => registeredUser != null,
          timeout: const Duration(seconds: 20),
        );

        expect(registeredUser, isNotNull);
        expect(registeredUser!.email, email);
        expect(registeredUser!.username, username);
        expect(callbackEmail, email);
        expect(callbackLogin, isNotNull);
        expect(callbackLogin!.email, email);
        expect(callbackLogin!.password, password);
        expect(callbackToken, anyOf(isNull, isA<String>()));
        final hasSuccessMessage = find
            .text('Account created successfully! Verify your email.')
            .evaluate()
            .isNotEmpty;
        final hasDeliveryWarning = find
            .textContaining(
              'verification email failed to send',
              findRichText: true,
            )
            .evaluate()
            .isNotEmpty;
        expect(hasSuccessMessage || hasDeliveryWarning, isTrue);

        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: ForgotPasswordScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(_findEmailTextField(), email);
        await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Send Reset Email'));
        await tester.tap(find.widgetWithText(ElevatedButton, 'Send Reset Email'));
        await tester.pump();

        await _pumpUntil(
          tester,
          () =>
              find.textContaining('Password reset email sent to')
                  .evaluate()
                  .isNotEmpty,
          timeout: const Duration(seconds: 60),
        );

        expect(
          find.textContaining('Password reset email sent to'),
          findsOneWidget,
        );
      },
      skip: !shouldRunLiveTests,
    );
  });
}

Finder _findTextFormField(String labelText) {
  switch (labelText) {
    case 'Email':
      return find.byType(TextFormField).at(0);
    case 'Username':
      return find.byType(TextFormField).at(1);
    case 'Password':
      return find.byType(TextFormField).at(2);
    case 'Full Name':
      return find.byType(TextFormField).at(3);
    default:
      throw ArgumentError('Unsupported registration field: $labelText');
  }
}

Finder _findEmailTextField() {
  return find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == 'Email Address',
    description: 'TextField with label Email Address',
  );
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  required Duration timeout,
}) async {
  final deadline = DateTime.now().add(timeout);

  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('Condition not met within $timeout');
    }

    await tester.pump(const Duration(milliseconds: 200));
  }
}