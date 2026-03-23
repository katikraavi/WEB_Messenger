import 'package:flutter/material.dart';
import 'invite_service.dart';
import '../../core/notifications/local_notification_service.dart';
import '../../features/chats/widgets/user_avatar_widget.dart';

class PendingInvitesScreen extends StatefulWidget {
  final String userId;

  const PendingInvitesScreen({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  State<PendingInvitesScreen> createState() => _PendingInvitesScreenState();
}

class _PendingInvitesScreenState extends State<PendingInvitesScreen> {
  late InviteService _inviteService;
  List<Invite> _invites = [];
  bool _isLoading = true;
  String? _errorMessage;
  Set<String> _acceptingInvites = {};
  Set<String> _decliningInvites = {};

  @override
  void initState() {
    super.initState();
    _inviteService = InviteService();
    _loadInvites();
  }

  @override
  void dispose() {
    _inviteService.dispose();
    super.dispose();
  }

  void _loadInvites() async {
    try {
      final invites = await _inviteService.getPendingInvites(widget.userId);
      setState(() {
        _invites = invites;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load invites: $e';
        _isLoading = false;
      });
    }
  }

  void _acceptInvite(String inviteId) async {
    setState(() {
      _acceptingInvites.add(inviteId);
    });

    try {
      await _inviteService.acceptInvite(inviteId);
      await LocalNotificationService.instance.dismissInviteNotification(
        inviteId,
      );
      setState(() {
        _invites.removeWhere((invite) => invite.id == inviteId);
        _acceptingInvites.remove(inviteId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invite accepted!')),
        );
      }
    } catch (e) {
      setState(() {
        _acceptingInvites.remove(inviteId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to accept invite: $e')),
        );
      }
    }
  }

  void _declineInvite(String inviteId) async {
    setState(() {
      _decliningInvites.add(inviteId);
    });

    try {
      await _inviteService.declineInvite(inviteId);
      await LocalNotificationService.instance.dismissInviteNotification(
        inviteId,
      );
      setState(() {
        _invites.removeWhere((invite) => invite.id == inviteId);
        _decliningInvites.remove(inviteId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invite declined')),
        );
      }
    } catch (e) {
      setState(() {
        _decliningInvites.remove(inviteId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to decline invite: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Invites'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_errorMessage!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _isLoading = true;
                            _errorMessage = null;
                          });
                          _loadInvites();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _invites.isEmpty
                  ? const Center(
                      child: Text('No pending invites'),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: _invites.length,
                      itemBuilder: (context, index) {
                        final invite = _invites[index];
                        final isAccepting = _acceptingInvites.contains(invite.id);
                        final isDeclining = _decliningInvites.contains(invite.id);

                        return Card(
                          margin: const EdgeInsets.all(8),
                          child: ListTile(
                            leading: UserAvatarWidget(
                              imageUrl: invite.senderAvatar,
                              radius: 20,
                              username: invite.senderName,
                            ),
                            title: Text(
                              '${invite.senderName} wants to chat',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              'Sent ${_formatDate(invite.createdAt)}',
                              style: const TextStyle(color: Colors.grey),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: isAccepting
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.check, color: Colors.green),
                                  onPressed: isAccepting || isDeclining
                                      ? null
                                      : () => _acceptInvite(invite.id),
                                  tooltip: 'Accept',
                                ),
                                IconButton(
                                  icon: isDeclining
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.close, color: Colors.red),
                                  onPressed: isDeclining || isAccepting
                                      ? null
                                      : () => _declineInvite(invite.id),
                                  tooltip: 'Decline',
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }
}
