class MessageSearchResult {
  final String messageId;
  final String snippet;
  final DateTime sentAt;

  MessageSearchResult({
    required this.messageId,
    required this.snippet,
    required this.sentAt,
  });

  factory MessageSearchResult.fromMap(Map<String, dynamic> map) {
    return MessageSearchResult(
      messageId: map['message_id'] as String,
      snippet: map['snippet'] as String,
      sentAt: map['sent_at'] as DateTime,
    );
  }

  Map<String, dynamic> toMap() => {
        'message_id': messageId,
        'snippet': snippet,
        'sent_at': sentAt,
      };
}