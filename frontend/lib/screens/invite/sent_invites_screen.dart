import 'package:flutter/material.dart';
import 'invite_service.dart';
import '../../features/chats/widgets/user_avatar_widget.dart';

class SentInvitesScreen extends StatefulWidget {
  final String userId;

  const SentInvitesScreen({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  State<SentInvitesScreen> createState() => _SentInvitesScreenState();
}

class _SentInvitesScreenState extends State<SentInvitesScreen> {
  late InviteService _inviteService;
  List<Invite> _invites = [];
  bool _isLoading = true;
  String? _errorMessage;
  Set<String> _cancelingInvites = {};

  @override
  void initState() {
    super.initState();
    _inviteService = InviteService();
    _loadSentInvites();
  }

  @override
  void dispose() {
    _inviteService.dispose();
    super.dispose();
  }

  void _loadSentInvites() async {
    try {
      final invites = await _inviteService.getSentInvites(widget.userId);
      setState(() {
        _invites = invites.where((invite) => invite.status == 'pending').toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load sent invites: $e';
        _isLoading = false;
      });
    }
  }

  void _cancelInvite(String inviteId) async {
    setState(() {
      _cancelingInvites.add(inviteId);
    });

    try {
      await _inviteService.cancelInvite(inviteId);
      setState(() {
        _invites.removeWhere((invite) => invite.id == inviteId);
        _cancelingInvites.remove(inviteId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invite canceled')),
        );
      }
    } catch (e) {
      setState(() {
        _cancelingInvites.remove(inviteId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to cancel invite: $e')),
        );
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'accepted':
        return Colors.green;
      case 'declined':
        return Colors.red;
      case 'pending':
      default:
        return Colors.orange;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'accepted':
        return 'Accepted';
      case 'declined':
        return 'Declined';
      case 'pending':
      default:
        return 'Pending';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sent Invites'),
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
                          _loadSentInvites();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _invites.isEmpty
                  ? const Center(
                      child: Text('No sent invites'),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: _invites.length,
                      itemBuilder: (context, index) {
                        final invite = _invites[index];
                        final isCanceling = _cancelingInvites.contains(invite.id);
                        final statusColor = _getStatusColor(invite.status);
                        final statusLabel = _getStatusLabel(invite.status);

                        return Card(
                          margin: const EdgeInsets.all(8),
                          child: ListTile(
                            leading: UserAvatarWidget(
                              imageUrl: invite.senderAvatar,
                              radius: 20,
                              username: invite.senderName,
                            ),
                            title: Text(
                              invite.senderName,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Sent ${_formatDate(invite.createdAt)}',
                                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    statusLabel,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            trailing: invite.status == 'pending' && !isCanceling
                                ? IconButton(
                                    icon: isCanceling
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.close, color: Colors.red),
                                    onPressed: isCanceling
                                        ? null
                                        : () {
                                            showDialog(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: const Text('Cancel Invite'),
                                                content: const Text('Are you sure you want to cancel this invite?'),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(context),
                                                    child: const Text('No'),
                                                  ),
                                                  TextButton(
                                                    onPressed: () {
                                                      Navigator.pop(context);
                                                      _cancelInvite(invite.id);
                                                    },
                                                    child: const Text('Yes', style: TextStyle(color: Colors.red)),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                    tooltip: 'Cancel',
                                  )
                                : const SizedBox.shrink(),
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
