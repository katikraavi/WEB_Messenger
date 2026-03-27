import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/polls/widgets/poll_widget.dart';

void main() {
  group('PollWidget Vote Retraction UI', () {
    const samplePoll = PollData(
      id: 'p1',
      question: 'Which option do you prefer?',
      options: [
        PollOptionData(id: 'o1', text: 'Option A', voteCount: 3),
        PollOptionData(id: 'o2', text: 'Option B', voteCount: 2),
      ],
      isAnonymous: false,
      isClosed: false,
      totalVotes: 5,
      currentUserVotedOptionId: null,
    );

    const votedPoll = PollData(
      id: 'p2',
      question: 'Did you vote?',
      options: [
        PollOptionData(id: 'o1', text: 'Yes', voteCount: 8),
        PollOptionData(id: 'o2', text: 'No', voteCount: 2),
      ],
      isAnonymous: false,
      isClosed: false,
      totalVotes: 10,
      currentUserVotedOptionId: 'o1',
    );

    const closedPoll = PollData(
      id: 'p3',
      question: 'Closed poll?',
      options: [
        PollOptionData(id: 'o1', text: 'Option A', voteCount: 5),
      ],
      isAnonymous: false,
      isClosed: true,
      totalVotes: 5,
      currentUserVotedOptionId: 'o1',
    );

    testWidgets('No retract button shown when user has not voted', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PollWidget(
              poll: samplePoll,
              onVote: (_) async {},
            ),
          ),
        ),
      );

      // Should not find retract button
      expect(find.byIcon(Icons.close), findsNothing);
      expect(find.text('Retract'), findsNothing);
    });

    testWidgets('Retract button shown when user has voted on open poll',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PollWidget(
              poll: votedPoll,
              onVote: (_) async {},
              onRetract: () async {},
            ),
          ),
        ),
      );

      // Should find retract button
      expect(find.text('Retract'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('No retract button shown on closed poll even if user voted',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PollWidget(
              poll: closedPoll,
              onVote: (_) async {},
              onRetract: () async {},
            ),
          ),
        ),
      );

      // Should not find retract button on closed poll
      expect(find.text('Retract'), findsNothing);
    });

    testWidgets('No retract button shown when onRetract callback is null',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PollWidget(
              poll: votedPoll,
              onVote: (_) async {},
              onRetract: null,
            ),
          ),
        ),
      );

      // Should not find retract button
      expect(find.text('Retract'), findsNothing);
    });

    testWidgets('Retract button calls onRetract callback when tapped',
        (tester) async {
      bool retractCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PollWidget(
              poll: votedPoll,
              onVote: (_) async {},
              onRetract: () async {
                retractCalled = true;
              },
            ),
          ),
        ),
      );

      // Find and tap retract button
      await tester.tap(find.text('Retract'));
      await tester.pumpAndSettle();

      expect(retractCalled, true);
    });

    testWidgets('Vote count displayed correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PollWidget(
              poll: votedPoll,
              onVote: (_) async {},
              onRetract: () async {},
            ),
          ),
        ),
      );

      // Find vote count text
      expect(find.text('10 votes'), findsOneWidget);
    });

    testWidgets(
        'Single vote display uses singular form',
        (tester) async {
      const singleVotePoll = PollData(
        id: 'p4',
        question: 'Question?',
        options: [
          PollOptionData(id: 'o1', text: 'Yes', voteCount: 1),
        ],
        isAnonymous: false,
        isClosed: false,
        totalVotes: 1,
        currentUserVotedOptionId: 'o1',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PollWidget(
              poll: singleVotePoll,
              onVote: (_) async {},
              onRetract: () async {},
            ),
          ),
        ),
      );

      expect(find.text('1 vote'), findsOneWidget);
    });

    testWidgets('User vote is highlighted with check icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PollWidget(
              poll: votedPoll,
              onVote: (_) async {},
              onRetract: () async {},
            ),
          ),
        ),
      );

      // Find check icon for voted option
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      
      // Find voted option text
      expect(find.text('Yes'), findsOneWidget);
    });

    testWidgets('Retract button is positioned on the right side', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PollWidget(
              poll: votedPoll,
              onVote: (_) async {},
              onRetract: () async {},
            ),
          ),
        ),
      );

      // The retract button should be in the footer row with vote count
      final retractButton = find.text('Retract');
      final voteCount = find.text('10 votes');

      expect(retractButton, findsOneWidget);
      expect(voteCount, findsOneWidget);

      // Both should be in footer area
      final retractButtonWidget = tester.getRect(retractButton);
      final voteCountWidget = tester.getRect(voteCount);

      // Retract button should be to the right of vote count
      expect(retractButtonWidget.left, greaterThan(voteCountWidget.right - 50));
    });

    testWidgets('Poll remains interactive after retract callback error',
        (tester) async {
      int voteAttempts = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PollWidget(
              poll: votedPoll,
              onVote: (_) async {
                voteAttempts++;
              },
              onRetract: () async {
                throw Exception('Retract failed');
              },
            ),
          ),
        ),
      );

      // Tap retract (will throw)
      await tester.tap(find.text('Retract'));
      await tester.pumpAndSettle();

      // Should still be able to tap options (vote still works)
      final optionBButton = find.text('No');
      await tester.tap(optionBButton);
      await tester.pumpAndSettle();

      expect(voteAttempts, 1);
    });
  });
}
