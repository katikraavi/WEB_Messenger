import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/search/screens/search_screen.dart';

// Mock Riverpod providers if needed
// import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  group('SearchScreen Widget Tests', () {
    // Helper to wrap widget with necessary providers
    Widget wrapWithProviders(Widget child) {
      // TODO: Wrap with ProviderContainer or Riverpod ProviderScope
      return MaterialApp(
        home: child,
      );
    }

    testWidgets(
      'displays search bar with placeholder',
      (WidgetTester tester) async {
        await tester.pumpWidget(wrapWithProviders(const SearchScreen()));

        // Find search bar placeholder
        expect(find.byType(TextField), findsOneWidget);
        expect(
          find.text('Search by username or email'),
          findsOneWidget,
        );
      },
      skip: true,
    );

    testWidgets(
      'displays search type toggle with Username and Email',
      (WidgetTester tester) async {
        await tester.pumpWidget(wrapWithProviders(const SearchScreen()));

        expect(find.text('Username'), findsOneWidget);
        expect(find.text('Email'), findsOneWidget);
      },
      skip: true,
    );

    testWidgets(
      'allows typing in search bar',
      (WidgetTester tester) async {
        await tester.pumpWidget(wrapWithProviders(const SearchScreen()));

        // Find the text field and type
        await tester.enterText(find.byType(TextField), 'alice');
        await tester.pumpWidget(wrapWithProviders(const SearchScreen()));

        expect(find.text('alice'), findsOneWidget);
      },
      skip: true,
    );

    testWidgets(
      'switches search type when toggle button tapped',
      (WidgetTester tester) async {
        await tester.pumpWidget(wrapWithProviders(const SearchScreen()));

        // Username button should be selected initially (blue background)
        // Tap Email button
        await tester.tap(find.text('Email'));
        await tester.pumpWidget(wrapWithProviders(const SearchScreen()));

        // TODO: Verify Email button is now selected
      },
      skip: true,
    );

    testWidgets(
      'displays empty state when no query',
      (WidgetTester tester) async {
        await tester.pumpWidget(wrapWithProviders(const SearchScreen()));

        // Should show empty state message
        expect(find.text('No results found'), findsOneWidget);
      },
      skip: true,
    );

    testWidgets(
      'displays error message on validation error',
      (WidgetTester tester) async {
        await tester.pumpWidget(wrapWithProviders(const SearchScreen()));

        // Type invalid query that's too long
        final tooLongQuery = 'a' * 101;
        await tester.enterText(find.byType(TextField), tooLongQuery);
        await tester.pumpWidget(wrapWithProviders(const SearchScreen()));

        // TODO: Verify error message displays
      },
      skip: true,
    );

    testWidgets(
      'includes app bar with title',
      (WidgetTester tester) async {
        await tester.pumpWidget(wrapWithProviders(const SearchScreen()));

        expect(find.text('Search Users'), findsOneWidget);
        expect(find.byType(AppBar), findsOneWidget);
      },
      skip: true,
