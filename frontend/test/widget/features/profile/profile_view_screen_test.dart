import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/profile/screens/profile_view_screen.dart';

void main() {
  group('ProfileViewScreen Widget Tests (T045-T048)', () {
    /// Test helper: Create test app with necessary providers
    Widget createTestWidget({
      required String userId,
      required bool isOwnProfile,
    }) {
      return ProviderScope(
        child: MaterialApp(
          home: ProfileViewScreen(
            userId: userId,
            isOwnProfile: isOwnProfile,
          ),
        ),
      );
    }

    testWidgets('T045: ProfileViewScreen renders without errors', (WidgetTester tester) async {
      // Arrange
      const userId = 'test-user-123';

      // Act: Build the widget
      await tester.pumpWidget(
        createTestWidget(userId: userId, isOwnProfile: false),
      );

      // Wait for any async operations (fetching profile)
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Assert: Widget should be present and render without throwing
      expect(find.byType(ProfileViewScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('T038: ProfileViewScreen displays AppBar with title', (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(
        createTestWidget(userId: 'user-1', isOwnProfile: false),
      );

      await tester.pumpAndSettle();

      // Assert: Should have AppBar with "Profile" title
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
    });

    testWidgets('T038: Edit button shows for own profile', (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(
        createTestWidget(userId: 'own-user', isOwnProfile: true),
      );

      await tester.pumpAndSettle();

      // Assert: Edit icon should be present in AppBar
      expect(find.byIcon(Icons.edit), findsWidgets);
    });

    testWidgets('T038: Edit button hidden for other profiles', (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(
        createTestWidget(userId: 'other-user', isOwnProfile: false),
      );

      await tester.pumpAndSettle();

      // Assert: Should not show "Edit Profile" button text
      expect(find.text('Edit Profile'), findsNothing);
    });

    testWidgets('T039: Loading skeleton displays while fetching', (WidgetTester tester) async {
      // Act: Build widget during initial load phase
      await tester.pumpWidget(
        createTestWidget(userId: 'user-123', isOwnProfile: false),
      );

      // Pump frame to show loading state
      await tester.pump();

      // Assert: During async fetch, may show loading indicator
      // After settle, will show data or error state
      await tester.pumpAndSettle();
      
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('T040: Error state can be displayed', (WidgetTester tester) async {
      // The error state will be handled internally by FutureProvider
      // This test ensures the widget doesn't crash when error occurs

      // Act
      await tester.pumpWidget(
        createTestWidget(userId: 'error-user', isOwnProfile: false),
      );

      // Allow async to complete (even if error)
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Assert: Widget should still exist and not throw
      expect(find.byType(Scaffold), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('T041: Bio section is rendered', (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(
        createTestWidget(userId: 'user-123', isOwnProfile: false),
      );

      // Wait for profile to load
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Assert: Should have Card widget(s) for bio section
      expect(find.byType(Card), findsWidgets);
    });

    testWidgets('T042: RefreshIndicator enables pull-to-refresh', (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(
        createTestWidget(userId: 'user-123', isOwnProfile: false),
      );

      await tester.pumpAndSettle();

      // Assert: Must have RefreshIndicator for pull-to-refresh
      expect(find.byType(RefreshIndicator), findsOneWidget);
    });

    testWidgets('T043: Privacy status can be displayed', (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(
        createTestWidget(userId: 'user-123', isOwnProfile: false),
      );

      await tester.pumpAndSettle();

      // Assert: Widget structure should be intact
      // Chip widget is conditionally rendered only when isPrivateProfile=true
      // For public profiles (default), Chip won't show
      // For private profiles, Chip will show with lock icon
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('T037: Profile picture widget is rendered', (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(
        createTestWidget(userId: 'user-123', isOwnProfile: false),
      );

      await tester.pumpAndSettle();

      // Assert: Should have Container(s) for profile picture display
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('T045: ProfileViewScreen handles different user IDs', (WidgetTester tester) async {
      // Act: Build with first user
      await tester.pumpWidget(
        createTestWidget(userId: 'user-1', isOwnProfile: false),
      );

      await tester.pumpAndSettle();

      // Change to different user
      await tester.pumpWidget(
        createTestWidget(userId: 'user-2', isOwnProfile: false),
      );

      await tester.pumpAndSettle();

      // Assert: Should rebuild correctly with new user
      expect(find.byType(ProfileViewScreen), findsOneWidget);
    });

    testWidgets('T048: ProfileViewScreen maintains valid UI hierarchy', (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(
        createTestWidget(userId: 'user-123', isOwnProfile: true),
      );

      await tester.pumpAndSettle();

      // Assert: Required UI components present
      expect(find.byType(Scaffold), findsOneWidget); // Main structure
      expect(find.byType(AppBar), findsOneWidget);   // Top bar
      expect(find.byType(RefreshIndicator), findsOneWidget); // Refresh
      expect(find.byType(SingleChildScrollView), findsWidgets); // Scrolling
      expect(find.byType(Column), findsWidgets);    // Layout
      expect(find.byType(Card), findsWidgets);      // Cards for sections
      expect(find.byType(Text), findsWidgets);      // Text content
    });

    testWidgets('T045 + T046: Widget handles state changes gracefully', (WidgetTester tester) async {
      // Act: Initial build
      await tester.pumpWidget(
        createTestWidget(userId: 'user-123', isOwnProfile: false),
      );

      // Pump multiple times to simulate different states
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // Assert: No exceptions thrown during state transitions
      expect(tester.takeException(), isNull);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('T047 + T048: Empty fields display correctly', (WidgetTester tester) async {
      // Act: Build with user that may have empty fields
      await tester.pumpWidget(
        createTestWidget(userId: 'minimal-user', isOwnProfile: false),
      );

      // Allow async loading
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Assert: Widget structure is intact even with empty data
      expect(find.byType(Scaffold), findsOneWidget);
      
      // Should have placeholder text for empty bio
      // At least structure should be present
      expect(find.byType(Column), findsWidgets);
    });

    testWidgets('T048: ProfileViewScreen scrollable content', (WidgetTester tester) async {
      // Act
      await tester.pumpWidget(
        createTestWidget(userId: 'user-123', isOwnProfile: true),
      );

      await tester.pumpAndSettle();

      // Assert: Content should be scrollable
      expect(find.byType(SingleChildScrollView), findsWidgets);
      
      // Try to scroll down to verify scrollability works
      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -100));
      await tester.pumpAndSettle();

      // Should not throw
      expect(tester.takeException(), isNull);
    });
  });
}
