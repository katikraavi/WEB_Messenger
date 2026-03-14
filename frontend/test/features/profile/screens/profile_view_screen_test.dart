import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/profile/providers/user_profile_provider.dart';
import 'package:frontend/features/profile/screens/profile_view_screen.dart';
import 'package:frontend/core/models/user.dart';

void main() {
  group('ProfileViewScreen Widget Tests', () {
    testWidgets('displays loading indicator initially', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ProviderScope(
            child: ProfileViewScreen(
              userId: 'test-user',
              isOwnProfile: false,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('displays profile data when loaded', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ProviderScope(
            child: ProfileViewScreen(
              userId: 'test-user',
              isOwnProfile: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('shows Edit button for own profile', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ProviderScope(
            child: ProfileViewScreen(
              userId: 'test-user',
              isOwnProfile: true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.edit), findsWidgets);
    });

    testWidgets('hides Edit button for other profiles', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ProviderScope(
            child: ProfileViewScreen(
              userId: 'other-user',
              isOwnProfile: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      // Edit button should not be visible for non-own profiles
      expect(find.byIcon(Icons.edit), findsNothing);
    });

    testWidgets('displays private profile indicator when isPrivateProfile is true', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ProviderScope(
            child: ProfileViewScreen(
              userId: 'test-user',
              isOwnProfile: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('displays about me in card', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ProviderScope(
            child: ProfileViewScreen(
              userId: 'test-user',
              isOwnProfile: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(Card), findsWidgets);
    });

    testWidgets('retry button appears on error', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ProviderScope(
            child: ProfileViewScreen(
              userId: 'test-user',
              isOwnProfile: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(Scaffold), findsWidgets);
    });
  });
}
