part of 'invitations_screen.dart';

class _GroupInvitationsList extends ConsumerStatefulWidget {
  final String token;

  const _GroupInvitationsList({required this.token});

  @override
  ConsumerState<_GroupInvitationsList> createState() => _GroupInvitationsListState();
}

class _GroupInvitationsListState extends ConsumerState<_GroupInvitationsList> {
  static String get _baseUrl => ApiClient.getBaseUrl();

  late final GroupInviteService _service;
  late Future<List<GroupInviteModel>> _future;

  @override
  void initState() {
    super.initState();
    _service = GroupInviteService(baseUrl: _baseUrl);
    _load();
  }

  void _load() {
    _future = _service.fetchPendingInvites(token: widget.token);
  }

  Future<void> _refresh() async {
    setState(() => _load());
  }

  Future<void> _accept(String inviteId) async {
    try {
      await _service.acceptInvite(token: widget.token, inviteId: inviteId);
      if (mounted) {
        ref.invalidate(pendingGroupInvitesProvider);
        ref.invalidate(pendingGroupInviteCountProvider);
        ref.invalidate(pendingInvitesProvider);
        ref.invalidate(pendingInviteCountProvider);
        ref.invalidate(chatsProvider(widget.token));
        ref.invalidate(activeChatListProvider(widget.token));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Group invite accepted!'),
            backgroundColor: Colors.green,
          ),
        );
        _refresh();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to accept: $e')),
        );
      }
    }
  }

  Future<void> _decline(String inviteId) async {
    try {
      await _service.declineInvite(token: widget.token, inviteId: inviteId);
      if (mounted) {
        ref.invalidate(pendingGroupInvitesProvider);
        ref.invalidate(pendingGroupInviteCountProvider);
        ref.invalidate(pendingInvitesProvider);
        ref.invalidate(pendingInviteCountProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group invite declined')),
        );
        _refresh();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to decline: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<GroupInviteModel>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                const SizedBox(height: 12),
                Text('Failed to load group invites'),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final invites = snapshot.data ?? [];

        if (invites.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.group_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                const Text('No pending group invitations'),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: invites.length,
            itemBuilder: (context, index) {
              final invite = invites[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.group, size: 36, color: Colors.indigo),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  invite.groupName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Invited by ${invite.invitedByUsername}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _accept(invite.id),
                              icon: const Icon(Icons.check, size: 18),
                              label: const Text('Accept'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _decline(invite.id),
                              icon: const Icon(Icons.close, size: 18),
                              label: const Text('Decline'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

