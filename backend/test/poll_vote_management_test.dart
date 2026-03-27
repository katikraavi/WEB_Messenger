import 'package:test/test.dart';
import 'package:server/src/services/poll_service.dart';
import 'package:server/src/services/encryption_service.dart';
import 'package:uuid/uuid.dart';
import 'package:postgres/postgres.dart';

/// Integration tests for poll vote management.
///
/// Verifies that votes can be:
/// - Cast on new polls
/// - Changed to different options
/// - Retracted completely
/// - Properly restricted on closed polls
void main() {
  group('Poll Vote Management', () {
    late Connection connection;
    late PollService pollService;
    late EncryptionService encryptionService;
    
    final testUserId1 = const Uuid().v4();
    final testUserId2 = const Uuid().v4();
    final testGroupId = const Uuid().v4();

    setUpAll(() async {
      // Connection setup would happen here
      // For this test template, we document the expected behavior
    });

    tearDownAll(() async {
      // Cleanup would happen here
    });

    group('Vote Creation', () {
      test('User can cast a vote on an open poll', () async {
        // Setup: Create a poll
        final poll = await pollService.createPoll(
          groupId: testGroupId,
          creatorUserId: testUserId1,
          question: 'Test question?',
          optionTexts: ['Option A', 'Option B'],
          isAnonymous: false,
        );

        // Act: User votes
        await pollService.vote(
          pollId: poll.id,
          optionId: poll.id, // In real scenario, would be an option ID
          userId: testUserId2,
        );

        // Assert: Vote is recorded
        final result = await pollService.getPollWithResults(
          pollId: poll.id,
          requestingUserId: testUserId2,
        );
        
        expect(result['currentUserVotedOptionId'], isNotNull);
        expect(result['totalVotes'], 1);
      });

      test('Cannot vote on a closed poll', () async {
        // Setup: Create and close a poll
        final poll = await pollService.createPoll(
          groupId: testGroupId,
          creatorUserId: testUserId1,
          question: 'Closed poll?',
          optionTexts: ['Option A', 'Option B'],
          isAnonymous: false,
        );

        await pollService.closePoll(
          pollId: poll.id,
          requestingUserId: testUserId1,
        );

        // Act & Assert: Voting should throw
        expect(
          () => pollService.vote(
            pollId: poll.id,
            optionId: poll.id,
            userId: testUserId2,
          ),
          throwsA(isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Cannot vote on a closed poll'),
          )),
        );
      });
    });

    group('Vote Changes', () {
      test('User can change their vote to a different option', () async {
        // Setup: User votes for option A
        final poll = await pollService.createPoll(
          groupId: testGroupId,
          creatorUserId: testUserId1,
          question: 'Favorite color?',
          optionTexts: ['Red', 'Blue', 'Green'],
          isAnonymous: false,
        );

        // First vote
        await pollService.vote(
          pollId: poll.id,
          optionId: 'optionA',
          userId: testUserId2,
        );

        // Act: Change vote to option B
        await pollService.vote(
          pollId: poll.id,
          optionId: 'optionB',
          userId: testUserId2,
        );

        // Assert: Vote count stays at 1, reflecting the new option
        final result = await pollService.getPollWithResults(
          pollId: poll.id,
          requestingUserId: testUserId2,
        );
        
        expect(result['totalVotes'], 1, reason: 'Vote count should remain 1');
        expect(result['currentUserVotedOptionId'], 'optionB');
      });

      test('Vote change removes old vote and adds new one', () async {
        // Setup with multiple users
        final poll = await pollService.createPoll(
          groupId: testGroupId,
          creatorUserId: testUserId1,
          question: 'Coffee or tea?',
          optionTexts: ['Coffee', 'Tea'],
          isAnonymous: false,
        );

        // User 1 votes
        await pollService.vote(
          pollId: poll.id,
          optionId: 'optionCoffee',
          userId: testUserId1,
        );

        // User 2 votes  
        await pollService.vote(
          pollId: poll.id,
          optionId: 'optionCoffee',
          userId: testUserId2,
        );

        expect(
          (await pollService.getPollWithResults(
            pollId: poll.id,
            requestingUserId: testUserId1,
          ))['totalVotes'],
          2,
        );

        // Act: User 2 changes vote
        await pollService.vote(
          pollId: poll.id,
          optionId: 'optionTea',
          userId: testUserId2,
        );

        // Assert: Total stays 2, but distributed differently
        final result = await pollService.getPollWithResults(
          pollId: poll.id,
          requestingUserId: testUserId2,
        );
        
        expect(result['totalVotes'], 2);
        expect(result['currentUserVotedOptionId'], 'optionTea');
      });

      test('Cannot change vote on a closed poll', () async {
        final poll = await pollService.createPoll(
          groupId: testGroupId,
          creatorUserId: testUserId1,
          question: 'Closed question?',
          optionTexts: ['A', 'B'],
          isAnonymous: false,
        );

        // User votes
        await pollService.vote(
          pollId: poll.id,
          optionId: 'optionA',
          userId: testUserId2,
        );

        // Close poll
        await pollService.closePoll(
          pollId: poll.id,
          requestingUserId: testUserId1,
        );

        // Act & Assert: Cannot change vote
        expect(
          () => pollService.vote(
            pollId: poll.id,
            optionId: 'optionB',
            userId: testUserId2,
          ),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('Vote Retraction', () {
      test('User can retract their vote', () async {
        // Setup: Create poll and vote
        final poll = await pollService.createPoll(
          groupId: testGroupId,
          creatorUserId: testUserId1,
          question: 'Retract test?',
          optionTexts: ['Yes', 'No'],
          isAnonymous: false,
        );

        await pollService.vote(
          pollId: poll.id,
          optionId: 'optionYes',
          userId: testUserId2,
        );

        expect(
          (await pollService.getPollWithResults(
            pollId: poll.id,
            requestingUserId: testUserId2,
          ))['totalVotes'],
          1,
        );

        // Act: Retract vote
        await pollService.retractVote(
          pollId: poll.id,
          userId: testUserId2,
        );

        // Assert: Vote is removed
        final result = await pollService.getPollWithResults(
          pollId: poll.id,
          requestingUserId: testUserId2,
        );
        
        expect(result['totalVotes'], 0);
        expect(result['currentUserVotedOptionId'], isNull);
      });

      test('Cannot retract vote on a closed poll', () async {
        final poll = await pollService.createPoll(
          groupId: testGroupId,
          creatorUserId: testUserId1,
          question: 'Closed for retract?',
          optionTexts: ['A', 'B'],
          isAnonymous: false,
        );

        await pollService.vote(
          pollId: poll.id,
          optionId: 'optionA',
          userId: testUserId2,
        );

        await pollService.closePoll(
          pollId: poll.id,
          requestingUserId: testUserId1,
        );

        // Act & Assert: Cannot retract
        expect(
          () => pollService.retractVote(
            pollId: poll.id,
            userId: testUserId2,
          ),
          throwsA(isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Cannot retract votes on a closed poll'),
          )),
        );
      });

      test('Error when retracting non-existent vote', () async {
        final poll = await pollService.createPoll(
          groupId: testGroupId,
          creatorUserId: testUserId1,
          question: 'No vote test?',
          optionTexts: ['A', 'B'],
          isAnonymous: false,
        );

        // Act & Assert: User who never voted cannot retract
        expect(
          () => pollService.retractVote(
            pollId: poll.id,
            userId: testUserId2,
          ),
          throwsA(isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('No vote found to retract'),
          )),
        );
      });

      test('Vote retraction affects other users\' vote totals', () async {
        final poll = await pollService.createPoll(
          groupId: testGroupId,
          creatorUserId: testUserId1,
          question: 'Multi-user retract?',
          optionTexts: ['Option A', 'Option B'],
          isAnonymous: false,
        );

        // Both users vote same option
        await pollService.vote(
          pollId: poll.id,
          optionId: 'optionA',
          userId: testUserId1,
        );

        await pollService.vote(
          pollId: poll.id,
          optionId: 'optionA',
          userId: testUserId2,
        );

        var result = await pollService.getPollWithResults(
          pollId: poll.id,
          requestingUserId: testUserId1,
        );
        expect(result['totalVotes'], 2);

        // Act: User 2 retracts
        await pollService.retractVote(
          pollId: poll.id,
          userId: testUserId2,
        );

        // Assert: Total decreases
        result = await pollService.getPollWithResults(
          pollId: poll.id,
          requestingUserId: testUserId1,
        );
        
        expect(result['totalVotes'], 1);
        expect(result['currentUserVotedOptionId'], 'optionA');
      });

      test('Can vote again after retracting', () async {
        final poll = await pollService.createPoll(
          groupId: testGroupId,
          creatorUserId: testUserId1,
          question: 'Revote test?',
          optionTexts: ['A', 'B', 'C'],
          isAnonymous: false,
        );

        // Vote
        await pollService.vote(
          pollId: poll.id,
          optionId: 'optionA',
          userId: testUserId2,
        );

        // Retract
        await pollService.retractVote(
          pollId: poll.id,
          userId: testUserId2,
        );

        // Act: Vote again for different option
        await pollService.vote(
          pollId: poll.id,
          optionId: 'optionB',
          userId: testUserId2,
        );

        // Assert: New vote is recorded
        final result = await pollService.getPollWithResults(
          pollId: poll.id,
          requestingUserId: testUserId2,
        );
        
        expect(result['totalVotes'], 1);
        expect(result['currentUserVotedOptionId'], 'optionB');
      });
    });

    group('Anonymous Polls', () {
      test('Vote changes work with anonymous polls', () async {
        final poll = await pollService.createPoll(
          groupId: testGroupId,
          creatorUserId: testUserId1,
          question: 'Anonymous vote test?',
          optionTexts: ['Option 1', 'Option 2'],
          isAnonymous: true,
        );

        // Vote
        await pollService.vote(
          pollId: poll.id,
          optionId: 'optionA',
          userId: testUserId2,
        );

        // Change vote
        await pollService.vote(
          pollId: poll.id,
          optionId: 'optionB',
          userId: testUserId2,
        );

        final result = await pollService.getPollWithResults(
          pollId: poll.id,
          requestingUserId: testUserId2,
        );
        
        expect(result['isAnonymous'], true);
        expect(result['totalVotes'], 1);
      });

      test('Vote retraction works with anonymous polls', () async {
        final poll = await pollService.createPoll(
          groupId: testGroupId,
          creatorUserId: testUserId1,
          question: 'Anonymous retract test?',
          optionTexts: ['Yes', 'No'],
          isAnonymous: true,
        );

        await pollService.vote(
          pollId: poll.id,
          optionId: 'optionYes',
          userId: testUserId2,
        );

        await pollService.retractVote(
          pollId: poll.id,
          userId: testUserId2,
        );

        final result = await pollService.getPollWithResults(
          pollId: poll.id,
          requestingUserId: testUserId2,
        );
        
        expect(result['totalVotes'], 0);
        expect(result['currentUserVotedOptionId'], isNull);
      });
    });
  });
}
