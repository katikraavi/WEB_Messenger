import 'package:postgres/postgres.dart';
import 'package:uuid/uuid.dart';

import '../models/poll.dart';
import 'encryption_service.dart';

/// Service for creating and managing polls within group chats.
///
/// Poll questions and option text are stored AES-256-GCM encrypted following
/// the same pattern used for messages (see [EncryptionService]).
class PollService {
  final Connection connection;
  final EncryptionService encryptionService;
  final Uuid _uuid = const Uuid();

  PollService({
    required this.connection,
    required this.encryptionService,
  });

  /// Create a new poll in a group chat.
  ///
  /// [creatorUserId] is used as the encryption key context so that only users
  /// who share the group can decrypt the question and options.
  Future<Poll> createPoll({
    required String groupId,
    required String creatorUserId,
    required String question,
    required List<String> optionTexts,
    bool isAnonymous = false,
    DateTime? closesAt,
  }) async {
    if (question.trim().isEmpty) {
      throw ArgumentError('Poll question must not be empty.');
    }
    if (optionTexts.length < 2) {
      throw ArgumentError('A poll must have at least 2 options.');
    }
    if (optionTexts.length > 20) {
      throw ArgumentError('A poll must have at most 20 options.');
    }

    final pollId = _uuid.v4();
    final now = DateTime.now().toUtc();
    final encryptedQuestion =
        await encryptionService.encrypt(question.trim(), creatorUserId);

    await connection.execute(
      Sql.named('''
        INSERT INTO polls (id, group_id, created_by, question, is_anonymous,
                           is_closed, created_at, closes_at)
        VALUES (@id, @group_id, @created_by, @question, @is_anonymous,
                false, @created_at, @closes_at)
      '''),
      parameters: {
        'id': pollId,
        'group_id': groupId,
        'created_by': creatorUserId,
        'question': encryptedQuestion,
        'is_anonymous': isAnonymous,
        'created_at': now,
        'closes_at': closesAt,
      },
    );

    for (var i = 0; i < optionTexts.length; i++) {
      final encryptedText =
          await encryptionService.encrypt(optionTexts[i].trim(), creatorUserId);
      await connection.execute(
        Sql.named('''
          INSERT INTO poll_options (id, poll_id, text, position)
          VALUES (@id, @poll_id, @text, @position)
        '''),
        parameters: {
          'id': _uuid.v4(),
          'poll_id': pollId,
          'text': encryptedText,
          'position': i,
        },
      );
    }

    return Poll(
      id: pollId,
      groupId: groupId,
      createdBy: creatorUserId,
      question: question.trim(),
      isAnonymous: isAnonymous,
      isClosed: false,
      createdAt: now,
      closesAt: closesAt,
    );
  }

  /// Cast or change a vote on a poll option.
  ///
  /// Enforces one vote per user (UPSERT strategy).
  Future<void> vote({
    required String pollId,
    required String optionId,
    required String userId,
  }) async {
    // Ensure the poll exists and is open
    final pollResult = await connection.execute(
      Sql.named('SELECT is_closed FROM polls WHERE id = @id LIMIT 1'),
      parameters: {'id': pollId},
    );
    if (pollResult.isEmpty) {
      throw StateError('Poll not found: $pollId');
    }
    final isClosed = pollResult.first.toColumnMap()['is_closed'] as bool;
    if (isClosed) {
      throw StateError('Cannot vote on a closed poll.');
    }

    final voteId = _uuid.v4();
    final now = DateTime.now().toUtc();

    // Remove previous vote from this user on this poll, then insert new one.
    await connection.execute(
      Sql.named(
          'DELETE FROM poll_votes WHERE poll_id = @poll_id AND user_id = @user_id'),
      parameters: {'poll_id': pollId, 'user_id': userId},
    );

    await connection.execute(
      Sql.named('''
        INSERT INTO poll_votes (id, poll_id, option_id, user_id, voted_at)
        VALUES (@id, @poll_id, @option_id, @user_id, @voted_at)
      '''),
      parameters: {
        'id': voteId,
        'poll_id': pollId,
        'option_id': optionId,
        'user_id': userId,
        'voted_at': now,
      },
    );
  }

  /// Close a poll so no new votes can be cast.
  Future<void> closePoll({
    required String pollId,
    required String requestingUserId,
  }) async {
    final result = await connection.execute(
      Sql.named(
          'SELECT created_by FROM polls WHERE id = @id LIMIT 1'),
      parameters: {'id': pollId},
    );
    if (result.isEmpty) throw StateError('Poll not found.');
    final creator = result.first.toColumnMap()['created_by'] as String;
    if (creator != requestingUserId) {
      throw StateError('Only the poll creator can close it.');
    }

    await connection.execute(
      Sql.named('UPDATE polls SET is_closed = true WHERE id = @id'),
      parameters: {'id': pollId},
    );
  }

  /// Retract a user's vote on a poll.
  ///
  /// Removes the user's vote entirely from the poll (unlike vote() which
  /// changes to a new option).
  Future<void> retractVote({
    required String pollId,
    required String userId,
  }) async {
    // Ensure the poll exists and is open
    final pollResult = await connection.execute(
      Sql.named('SELECT is_closed FROM polls WHERE id = @id LIMIT 1'),
      parameters: {'id': pollId},
    );
    if (pollResult.isEmpty) {
      throw StateError('Poll not found: $pollId');
    }
    final isClosed = pollResult.first.toColumnMap()['is_closed'] as bool;
    if (isClosed) {
      throw StateError('Cannot retract votes on a closed poll.');
    }

    // Check if user has a vote to retract
    final voteResult = await connection.execute(
      Sql.named(
          'SELECT id FROM poll_votes WHERE poll_id = @poll_id AND user_id = @user_id LIMIT 1'),
      parameters: {'poll_id': pollId, 'user_id': userId},
    );

    if (voteResult.isEmpty) {
      throw StateError('No vote found to retract.');
    }

    // Delete the vote
    await connection.execute(
      Sql.named(
          'DELETE FROM poll_votes WHERE poll_id = @poll_id AND user_id = @user_id'),
      parameters: {'poll_id': pollId, 'user_id': userId},
    );
  }

  /// Fetch a poll with its options and per-option vote counts.
  Future<Map<String, dynamic>> getPollWithResults({
    required String pollId,
    required String requestingUserId,
  }) async {
    final pollResult = await connection.execute(
      Sql.named(
          'SELECT id, group_id, created_by, question, is_anonymous, is_closed, '
          'created_at, closes_at FROM polls WHERE id = @id LIMIT 1'),
      parameters: {'id': pollId},
    );
    if (pollResult.isEmpty) throw StateError('Poll not found.');
    final pollMap = pollResult.first.toColumnMap();

    // Decrypt question
    final encryptedQ = pollMap['question'] as String;
    final question =
        await encryptionService.decrypt(encryptedQ, pollMap['created_by'] as String);

    final optionsResult = await connection.execute(
      Sql.named(
          'SELECT id, text, position FROM poll_options WHERE poll_id = @poll_id ORDER BY position'),
      parameters: {'poll_id': pollId},
    );

    final voteCounts = await connection.execute(
      Sql.named(
          'SELECT option_id, COUNT(*) AS cnt FROM poll_votes WHERE poll_id = @poll_id GROUP BY option_id'),
      parameters: {'poll_id': pollId},
    );
    final countByOption = <String, int>{
      for (final r in voteCounts)
        r.toColumnMap()['option_id'] as String:
            (r.toColumnMap()['cnt'] as int?) ?? 0
    };

    final userVoteResult = await connection.execute(
      Sql.named(
          'SELECT option_id FROM poll_votes WHERE poll_id = @poll_id AND user_id = @user_id LIMIT 1'),
      parameters: {'poll_id': pollId, 'user_id': requestingUserId},
    );
    final userVotedOptionId = userVoteResult.isEmpty
        ? null
        : userVoteResult.first.toColumnMap()['option_id'] as String?;

    final options = <Map<String, dynamic>>[];
    for (final row in optionsResult) {
      final m = row.toColumnMap();
      final optId = m['id'] as String;
      final decryptedText = await encryptionService.decrypt(
          m['text'] as String, pollMap['created_by'] as String);
      options.add({
        'id': optId,
        'text': decryptedText,
        'position': m['position'],
        'voteCount': countByOption[optId] ?? 0,
      });
    }

    final totalVotes = countByOption.values.fold<int>(0, (a, b) => a + b);

    return {
      'id': pollId,
      'groupId': pollMap['group_id'],
      'createdBy': pollMap['created_by'],
      'question': question,
      'isAnonymous': pollMap['is_anonymous'],
      'isClosed': pollMap['is_closed'],
      'createdAt': (pollMap['created_at'] as DateTime).toIso8601String(),
      'closesAt': (pollMap['closes_at'] as DateTime?)?.toIso8601String(),
      'options': options,
      'totalVotes': totalVotes,
      'currentUserVotedOptionId': userVotedOptionId,
    };
  }
}
