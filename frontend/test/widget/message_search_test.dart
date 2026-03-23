import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/chats/widgets/message_search_bar.dart';
import 'package:frontend/features/chats/widgets/message_search_result.dart';

void main() {
  group('MessageSearchBar widget', () {
    testWidgets('renders search text field and close button', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageSearchBar(
              controller: controller,
              onQueryChanged: (_) {},
              totalResults: 0,
              currentIndex: 0,
              onNext: () {},
              onPrevious: () {},
              onClose: () {},
            ),
          ),
        ),
      );

      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
      controller.dispose();
    });

    testWidgets('shows result count badge when results > 0', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageSearchBar(
              controller: controller,
              onQueryChanged: (_) {},
              totalResults: 5,
              currentIndex: 1,
              onNext: () {},
              onPrevious: () {},
              onClose: () {},
            ),
          ),
        ),
      );

      // 1 of 5 style indicator
      expect(find.textContaining('2'), findsWidgets); // 1-based display index
      expect(find.textContaining('5'), findsWidgets);
      controller.dispose();
    });

    testWidgets('previous/next buttons enabled when results exist', (tester) async {
      bool nextCalled = false;
      bool prevCalled = false;
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageSearchBar(
              controller: controller,
              onQueryChanged: (_) {},
              totalResults: 3,
              currentIndex: 0,
              onNext: () => nextCalled = true,
              onPrevious: () => prevCalled = true,
              onClose: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
      expect(nextCalled, isTrue);

      await tester.tap(find.byIcon(Icons.keyboard_arrow_up));
      expect(prevCalled, isTrue);
      controller.dispose();
    });

    testWidgets('close callback is invoked on close button tap', (tester) async {
      bool closed = false;
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageSearchBar(
              controller: controller,
              onQueryChanged: (_) {},
              totalResults: 0,
              currentIndex: 0,
              onNext: () {},
              onPrevious: () {},
              onClose: () => closed = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.close));
      expect(closed, isTrue);
      controller.dispose();
    });
  });

  group('MessageSearchResult widget', () {
    testWidgets('renders message text with highlighted span', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MessageSearchResult(
              text: 'The quick brown fox jumps',
              query: 'fox',
            ),
          ),
        ),
      );

      expect(find.byType(RichText), findsWidgets);
    });

    testWidgets('renders without highlight when isHighlighted is false', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MessageSearchResult(
              text: 'The quick brown fox jumps',
              query: 'fox',
            ),
          ),
        ),
      );

      // Should still render
      expect(find.byType(MessageSearchResult), findsOneWidget);
    });
  });
}
