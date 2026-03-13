import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/search/widgets/search_result_list_widget.dart';
import 'package:frontend/features/search/services/search_service.dart';

void main() {
  group('SearchResultListWidget Tests', () {
    late List<UserSearchResult> mockResults;

    setUp(() {
      mockResults = [
        UserSearchResult(
          userId: '1',
          username: 'alice',
          email: 'alice@example.com',
          profilePictureUrl: null,
          isPrivateProfile: false,
        ),
        UserSearchResult(
          userId: '2',
          username: 'bob',
          email: 'bob@example.com',
          profilePictureUrl: null,
          isPrivateProfile: true,
        ),
      ];
    });

    testWidgets(
      'displays loading state',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SearchResultListWidget(
                results: [],
                isLoading: true,
                onTap: (result) {},
                onRetry: () {},
              ),
            ),
          ),
        );

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      },
    );

    testWidgets(
      'displays empty state',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SearchResultListWidget(
                results: [],
                isLoading: false,
                onTap: (result) {},
                onRetry: () {},
              ),
            ),
          ),
        );

        expect(find.text('No results found'), findsOneWidget);
      },
    );

    testWidgets(
      'displays error state',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SearchResultListWidget(
                results: [],
                isLoading: false,
                error: 'Search failed: connection timeout',
                onTap: (result) {},
                onRetry: () {},
              ),
            ),
          ),
        );

        expect(find.text('Search Error'), findsOneWidget);
        expect(find.text('Search failed: connection timeout'), findsOneWidget);
      },
    );

    testWidgets(
      'displays list of results',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SearchResultListWidget(
                results: mockResults,
                isLoading: false,
                onTap: (result) {},
                onRetry: () {},
              ),
            ),
          ),
        );

        // Should display both results
        expect(find.text('alice'), findsOneWidget);
        expect(find.text('bob'), findsOneWidget);
        expect(find.text('alice@example.com'), findsOneWidget);
        expect(find.text('bob@example.com'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping result triggers onTap callback',
      (WidgetTester tester) async {
        UserSearchResult? tappedResult;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SearchResultListWidget(
                results: mockResults,
                isLoading: false,
                onTap: (result) {
                  tappedResult = result;
                },
                onRetry: () {},
              ),
            ),
          ),
        );

        // Tap on first result (alice)
        await tester.tap(find.byType(InkWell).first);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SearchResultListWidget(
                results: mockResults,
                isLoading: false,
                onTap: (result) {
                  tappedResult = result;
                },
                onRetry: () {},
              ),
            ),
          ),
        );

        expect(tappedResult?.username, equals('alice'));
      },
    );

    testWidgets(
      'displays private profile lock icon',
      (WidgetTester tester) async {
        final privateUser = UserSearchResult(
          userId: '3',
          username: 'charlie',
          email: 'charlie@example.com',
          profilePictureUrl: null,
          isPrivateProfile: true,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SearchResultListWidget(
                results: [privateUser],
                isLoading: false,
                onTap: (result) {},
                onRetry: () {},
              ),
            ),
          ),
        );

        // Should display lock icon for private profile
        expect(find.byIcon(Icons.lock), findsOneWidget);
      },
    );

    testWidgets(
      'Retry button calls onRetry',
      (WidgetTester tester) async {
        bool retryPressed = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SearchResultListWidget(
                results: [],
                isLoading: false,
                error: 'Network error',
                onTap: (result) {},
                onRetry: () {
                  retryPressed = true;
                },
              ),
            ),
          ),
        );

        await tester.tap(find.text('Retry'));
        expect(retryPressed, isTrue);
      },
    );
  });
}
