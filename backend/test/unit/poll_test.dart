import 'package:test/test.dart';
import '../../lib/src/models/poll.dart';

void main() {
  group('Poll models (unit — no DB)', () {
    group('Poll', () {
      test('creates from map', () {
        final now = DateTime.now();
        final map = {
          'id': 'p1',
          'group_id': 'g1',
          'created_by': 'u1',
          'question': 'Which day works best?',
          'is_anonymous': true,
          'is_closed': false,
          'created_at': now,
          'closes_at': null,
        };
        final poll = Poll.fromMap(map);
        expect(poll.id, equals('p1'));
        expect(poll.question, equals('Which day works best?'));
        expect(poll.isAnonymous, isTrue);
        expect(poll.isClosed, isFalse);
        expect(poll.closesAt, isNull);
      });

      test('defaults is_anonymous to false when null', () {
        final now = DateTime.now();
        final map = {
          'id': 'p2',
          'group_id': 'g1',
          'created_by': 'u1',
          'question': 'Q?',
          'is_anonymous': null,
          'is_closed': null,
          'created_at': now,
          'closes_at': null,
        };
        final poll = Poll.fromMap(map);
        expect(poll.isAnonymous, isFalse);
        expect(poll.isClosed, isFalse);
      });

      test('toMap round-trips all fields', () {
        final now = DateTime.now();
        final poll = Poll(
          id: 'p1',
          groupId: 'g1',
          createdBy: 'u1',
          question: 'Q?',
          isAnonymous: false,
          isClosed: false,
          createdAt: now,
          closesAt: null,
        );
        final map = poll.toMap();
        expect(map['id'], equals('p1'));
        expect(map['group_id'], equals('g1'));
        expect(map['question'], equals('Q?'));
      });
    });

    group('PollOption', () {
      test('creates from map', () {
        final map = {
          'id': 'o1',
          'poll_id': 'p1',
          'text': 'Monday',
          'position': 0,
        };
        final option = PollOption.fromMap(map);
        expect(option.text, equals('Monday'));
        expect(option.position, equals(0));
      });

      test('toMap round-trips', () {
        final option = PollOption(
          id: 'o1',
          pollId: 'p1',
          text: 'Tuesday',
          position: 1,
        );
        final map = option.toMap();
        expect(map['text'], equals('Tuesday'));
        expect(map['position'], equals(1));
      });
    });

    group('PollVote', () {
      test('creates from map', () {
        final now = DateTime.now();
        final map = {
          'id': 'v1',
          'poll_id': 'p1',
          'option_id': 'o1',
          'user_id': 'u1',
          'voted_at': now,
        };
        final vote = PollVote.fromMap(map);
        expect(vote.pollId, equals('p1'));
        expect(vote.optionId, equals('o1'));
        expect(vote.userId, equals('u1'));
      });

      test('toMap round-trips', () {
        final now = DateTime.now();
        final vote = PollVote(
          id: 'v1',
          pollId: 'p1',
          optionId: 'o1',
          userId: 'u1',
          votedAt: now,
        );
        final map = vote.toMap();
        expect(map['poll_id'], equals('p1'));
        expect(map['option_id'], equals('o1'));
        expect(map['user_id'], equals('u1'));
      });
    });
  });
}
