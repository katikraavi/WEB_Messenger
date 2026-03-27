import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/polls/widgets/poll_widget.dart';

void main() {
  group('PollWidget', () {
    const samplePoll = PollData(
      id: 'p1',
      question: 'Which day works best?',
      options: [
        PollOptionData(id: 'o1', text: 'Monday', voteCount: 3),
        PollOptionData(id: 'o2', text: 'Tuesday', voteCount: 1),
        PollOptionData(id: 'o3', text: 'Friday', voteCount: 5),
      ],
      isAnonymous: false,
      isClosed: false,
      totalVotes: 9,
      currentUserVotedOptionId: null,
    );

    testWidgets('renders poll question', (tester) async {
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

      expect(find.text('Which day works best?'), findsOneWidget);
    });

    testWidgets('renders all option texts', (tester) async {
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

      expect(find.text('Monday'), findsOneWidget);
      expect(find.text('Tuesday'), findsOneWidget);
      expect(find.text('Friday'), findsOneWidget);
    });

    testWidgets('calls onVote with correct option id on tap', (tester) async {
      String? votedOptionId;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PollWidget(
              poll: samplePoll,
              onVote: (optionId) async => votedOptionId = optionId,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Monday'));
      await tester.pump();

      expect(votedOptionId, equals('o1'));
    });

    testWidgets('shows vote percentages when votes exist', (tester) async {
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

      // 3 of 9 = 33%, 1 of 9 = 11%, 5 of 9 = 55%
      expect(find.textContaining('%'), findsWidgets);
    });

    testWidgets('shows closed badge when poll is closed', (tester) async {
      const closedPoll = PollData(
        id: 'p2',
        question: 'Closed poll?',
        options: [
          PollOptionData(id: 'o1', text: 'Yes', voteCount: 2),
        ],
        isAnonymous: false,
        isClosed: true,
        totalVotes: 2,
        currentUserVotedOptionId: null,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PollWidget(
              poll: closedPoll,
              onVote: (_) async {},
            ),
          ),
        ),
      );

      expect(find.text('Closed'), findsOneWidget);
    });

    testWidgets('highlights user\'s voted option', (tester) async {
      const votedPoll = PollData(
        id: 'p3',
        question: 'Already voted?',
        options: [
          PollOptionData(id: 'o1', text: 'Option A', voteCount: 4),
          PollOptionData(id: 'o2', text: 'Option B', voteCount: 1),
        ],
        isAnonymous: false,
        isClosed: false,
        totalVotes: 5,
        currentUserVotedOptionId: 'o1',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PollWidget(
              poll: votedPoll,
              onVote: (_) async {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });
  });
}
