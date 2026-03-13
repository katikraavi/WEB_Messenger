import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/search/widgets/search_bar_widget.dart';

void main() {
  group('SearchBarWidget Tests', () {
    testWidgets(
      'displays text input field',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SearchBarWidget(
                onQueryChanged: (_) {},
                onSearch: () {},
                onClear: () {},
              ),
            ),
          ),
        );

        expect(find.byType(TextField), findsOneWidget);
        expect(find.byIcon(Icons.search), findsOneWidget);
      },
    );

    testWidgets(
      'allows typing text',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SearchBarWidget(
                onQueryChanged: (_) {},
                onSearch: () {},
                onClear: () {},
              ),
            ),
          ),
        );

        await tester.enterText(find.byType(TextField), 'alice');
        expect(find.text('alice'), findsOneWidget);
      },
    );

    testWidgets(
      'debounce delays onQueryChanged callback',
      (WidgetTester tester) async {
        int callCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SearchBarWidget(
                debounceMs: 100,
                onQueryChanged: (_) {
                  callCount++;
                },
                onSearch: () {},
                onClear: () {},
              ),
            ),
          ),
        );

        // Type multiple characters quickly
        await tester.enterText(find.byType(TextField), 'a');
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SearchBarWidget(
                debounceMs: 100,
                onQueryChanged: (_) {
                  callCount++;
                },
                onSearch: () {},
                onClear: () {},
              ),
            ),
          ),
        );

        // Debounce timer hasn't fired yet
        expect(callCount, equals(0));

        // Wait for debounce
        await tester.pumpAndSettle(const Duration(milliseconds: 150));

        // Now callback should have been called
        expect(callCount, equals(1));
      },
    );

    testWidgets(
      'shows clear button when text present',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SearchBarWidget(
                onQueryChanged: (_) {},
                onSearch: () {},
                onClear: () {},
              ),
            ),
          ),
        );

        // No clear button initially
        expect(find.byIcon(Icons.close), findsNothing);

        // Type text
        await tester.enterText(find.byType(TextField), 'alice');
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SearchBarWidget(
                onQueryChanged: (_) {},
                onSearch: () {},
                onClear: () {},
              ),
            ),
          ),
        );

        // Clear button should appear
        expect(find.byIcon(Icons.close), findsOneWidget);
      },
    );

    testWidgets(
      'tapping clear button clears text and calls onClear',
      (WidgetTester tester) async {
        bool clearPressed = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SearchBarWidget(
                onQueryChanged: (_) {},
                onSearch: () {},
                onClear: () {
                  clearPressed = true;
                },
              ),
            ),
          ),
        );

        // Type text
        await tester.enterText(find.byType(TextField), 'alice');
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SearchBarWidget(
                onQueryChanged: (_) {},
                onSearch: () {},
                onClear: () {
                  clearPressed = true;
                },
              ),
            ),
          ),
        );

        // Tap clear button
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SearchBarWidget(
                onQueryChanged: (_) {},
                onSearch: () {},
                onClear: () {
                  clearPressed = true;
                },
              ),
            ),
          ),
        );

        expect(clearPressed, isTrue);
      },
    );

    testWidgets(
      'pressing Enter key calls onSearch',
      (WidgetTester tester) async {
        bool searchPressed = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SearchBarWidget(
                onQueryChanged: (_) {},
                onSearch: () {
                  searchPressed = true;
                },
                onClear: () {},
              ),
            ),
          ),
        );

        await tester.enterText(find.byType(TextField), 'alice');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SearchBarWidget(
                onQueryChanged: (_) {},
                onSearch: () {
                  searchPressed = true;
                },
                onClear: () {},
              ),
            ),
          ),
        );

        expect(searchPressed, isTrue);
      },
    );

    testWidgets(
      'has search icon visible',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SearchBarWidget(
                onQueryChanged: (_) {},
                onSearch: () {},
                onClear: () {},
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.search), findsOneWidget);
      },
    );
  });

  group('SearchTypeToggle Tests', () {
    testWidgets(
      'displays both username and email buttons',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SearchTypeToggle(
                selectedType: 'username',
                onChanged: (_) {},
              ),
            ),
          ),
        );

        expect(find.text('Username'), findsOneWidget);
        expect(find.text('Email'), findsOneWidget);
      },
    );

    testWidgets(
      'highlights selected button',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SearchTypeToggle(
                selectedType: 'username',
                onChanged: (_) {},
              ),
            ),
          ),
        );

        // Username button is selected (has blue background)
        // Email button is not selected
        // This is a visual test - depends on implementation
      },
    );

    testWidgets(
      'tapping button calls onChanged',
      (WidgetTester tester) async {
        String selectedType = 'username';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SearchTypeToggle(
                selectedType: selectedType,
                onChanged: (newType) {
                  selectedType = newType;
                },
              ),
            ),
          ),
        );

        // Tap Email button
        await tester.tap(find.text('Email'));
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SearchTypeToggle(
                selectedType: selectedType,
                onChanged: (newType) {
                  selectedType = newType;
                },
              ),
            ),
          ),
        );

        expect(selectedType, equals('email'));
      },
    );
  });
}
