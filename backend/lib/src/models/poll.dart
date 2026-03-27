/// Poll entities for group chat polling features.
class Poll {
  final String id;
  final String groupId;
  final String createdBy;
  final String question;
  final bool isAnonymous;
  final bool isClosed;
  final DateTime createdAt;
  final DateTime? closesAt;

  Poll({
    required this.id,
    required this.groupId,
    required this.createdBy,
    required this.question,
    required this.isAnonymous,
    required this.isClosed,
    required this.createdAt,
    required this.closesAt,
  });

  factory Poll.fromMap(Map<String, dynamic> map) {
    return Poll(
      id: map['id'] as String,
      groupId: map['group_id'] as String,
      createdBy: map['created_by'] as String,
      question: map['question'] as String,
      isAnonymous: (map['is_anonymous'] as bool?) ?? false,
      isClosed: (map['is_closed'] as bool?) ?? false,
      createdAt: map['created_at'] as DateTime,
      closesAt: map['closes_at'] as DateTime?,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'group_id': groupId,
    'created_by': createdBy,
    'question': question,
    'is_anonymous': isAnonymous,
    'is_closed': isClosed,
    'created_at': createdAt,
    'closes_at': closesAt,
  };
}

class PollOption {
  final String id;
  final String pollId;
  final String text;
  final int position;

  PollOption({
    required this.id,
    required this.pollId,
    required this.text,
    required this.position,
  });

  factory PollOption.fromMap(Map<String, dynamic> map) {
    return PollOption(
      id: map['id'] as String,
      pollId: map['poll_id'] as String,
      text: map['text'] as String,
      position: map['position'] as int,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'poll_id': pollId,
    'text': text,
    'position': position,
  };
}

class PollVote {
  final String id;
  final String pollId;
  final String optionId;
  final String userId;
  final DateTime votedAt;

  PollVote({
    required this.id,
    required this.pollId,
    required this.optionId,
    required this.userId,
    required this.votedAt,
  });

  factory PollVote.fromMap(Map<String, dynamic> map) {
    return PollVote(
      id: map['id'] as String,
      pollId: map['poll_id'] as String,
      optionId: map['option_id'] as String,
      userId: map['user_id'] as String,
      votedAt: map['voted_at'] as DateTime,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'poll_id': pollId,
    'option_id': optionId,
    'user_id': userId,
    'voted_at': votedAt,
  };
}
