part of 'chat_detail_screen.dart';

class _PollMessageWidget extends StatefulWidget {
  final Message message;
  final String token;
  final String currentUserId;

  const _PollMessageWidget({
    super.key,
    required this.message,
    required this.token,
    required this.currentUserId,
  });

  @override
  State<_PollMessageWidget> createState() => _PollMessageWidgetState();
}

class _PollMessageWidgetState extends State<_PollMessageWidget> {
  PollData? _pollData;
  String? _error;
  bool _loading = true;

  late final PollServiceClient _pollService;

  @override
  void initState() {
    super.initState();
    _pollService = PollServiceClient(baseUrl: _backendBaseUrl);
    _loadPoll();
  }

  Future<void> _loadPoll() async {
    final content = widget.message.decryptedContent;
    if (content == null) {
      setState(() {
        _loading = false;
        _error = 'No poll data';
      });
      return;
    }

    try {
      final jsonBody = jsonDecode(content) as Map<String, dynamic>;
      final pollId = jsonBody['pollId'] as String?;
      if (pollId == null) {
        setState(() {
          _loading = false;
          _error = 'Missing pollId in message';
        });
        return;
      }

      final data = await _pollService.getPoll(
        pollId: pollId,
        token: widget.token,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _pollData = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _handleVote(String optionId) async {
    final pollId = _pollData?.id;
    if (pollId == null) {
      return;
    }
    await _pollService.vote(
      token: widget.token,
      pollId: pollId,
      optionId: optionId,
    );
    await _loadPoll();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _pollData == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Text(
          '(Poll unavailable)',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }

    return PollWidget(
      poll: _pollData!,
      onVote: _handleVote,
    );
  }
}
