import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as provider;

import '../models/chat_invite_model.dart';
import '../providers/invites_provider.dart';
import '../providers/network_provider.dart';
import '../services/invite_error_handler.dart';
import '../services/resilient_http_client.dart';
import '../services/group_invite_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../chats/widgets/user_avatar_widget.dart';
import 'send_invite_picker_screen.dart';

/// Main invitations screen - shows all invitations (pending and sent) in a single unified view
class InvitationsScreen extends ConsumerWidget {
  const InvitationsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    print('[InvitationsScreen] Building unified invitations screen');

    // Watch real-time updates from WebSocket to enable automatic refresh
    ref.watch(invitationRealtimeUpdatesProvider);

    // Watch network status
    final networkStatus = ref.watch(networkStatusProvider);
    final isOffline = networkStatus['isOffline'] as bool;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Invitations'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh Invitations',
              onPressed: () {
                print('[InvitationsScreen] Refreshing invitations...');
                ref.refresh(pendingInvitesProvider);
                ref.refresh(sentInvitesProvider);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Refreshing invitations...'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Send New Invite',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const SendInvitePickerScreen(),
                  ),
                );
              },
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.person), text: 'Direct'),
              Tab(icon: Icon(Icons.group), text: 'Groups'),
            ],
          ),
        ),
        body: Column(
          children: [
            // Network status warning
            if (isOffline) _buildOfflineWarning(networkStatus),
            // Tab content
            Expanded(
              child: TabBarView(
                children: [
                  // Tab 0: Direct invitations
                  provider.Consumer<AuthProvider>(
                    builder: (context, authProvider, child) {
                      return const _UnifiedInvitationsList();
                    },
                  ),
                  // Tab 1: Group invitations
                  provider.Consumer<AuthProvider>(
                    builder: (context, authProvider, child) {
                      final token = authProvider.token;
                      if (token == null) {
                        return const Center(child: Text('Not authenticated'));
                      }
                      return _GroupInvitationsList(token: token);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build offline/degraded connection warning banner
  Widget _buildOfflineWarning(Map<String, dynamic> networkStatus) {
    final state = networkStatus['state'] as NetworkState;
    final description = networkStatus['description'] as String;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: state == NetworkState.offline
          ? Colors.red[100]
          : Colors.orange[100],
      child: Row(
        children: [
          Icon(
            state == NetworkState.offline ? Icons.cloud_off : Icons.cloud_queue,
            color: state == NetworkState.offline
                ? Colors.red[700]
                : Colors.orange[700],
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$description - Please check your connection',
              style: TextStyle(
                fontSize: 12,
                color: state == NetworkState.offline
                    ? Colors.red[700]
                    : Colors.orange[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Unified list showing all invitations with conditional action buttons
class _UnifiedInvitationsList extends ConsumerWidget {
  const _UnifiedInvitationsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    print('[InvitationsList] Building unified invitations list');

    // Watch both pending and sent invites
    final pendingInvites = ref.watch(pendingInvitesProvider);
    final sentInvites = ref.watch(sentInvitesProvider);
    final acceptMutation = ref.watch(acceptInviteMutationProvider);
    final declineMutation = ref.watch(declineInviteMutationProvider);
    final cancelMutation = ref.watch(cancelInviteMutationProvider);

    // Combine both states
    return pendingInvites.when(
      data: (pending) {
        return sentInvites.when(
          data: (sent) {
            print(
              '[InvitationsList] ✅ Loaded ${pending.length} pending + ${sent.length} sent invites',
            );

            // Create unified list
            final allInvitations = [
              ...pending.map((i) => {'type': 'incoming', 'data': i}),
              ...sent.map((i) => {'type': 'outgoing', 'data': i}),
            ];

            if (allInvitations.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.mail_outline, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    const Text('No invitations yet'),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                const SendInvitePickerScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.person_add),
                      label: const Text('Send an Invitation'),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: allInvitations.length,
              itemBuilder: (context, index) {
                final item = allInvitations[index];
                final isIncoming = item['type'] == 'incoming';
                final invite = item['data'] as ChatInviteModel;
                final isProcessing =
                    acceptMutation.isLoading ||
                    declineMutation.isLoading ||
                    cancelMutation.isLoading;
                final avatarUrl = isIncoming
                  ? invite.senderAvatarUrl
                  : invite.recipientAvatarUrl;
                final avatarName = isIncoming
                  ? invite.senderName
                  : (invite.recipientName ?? 'Unknown');

                return Card(
                  margin: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 0,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            // Avatar
                            UserAvatarWidget(
                              imageUrl: avatarUrl,
                              radius: 24,
                              username: avatarName,
                            ),
                            const SizedBox(width: 12),
                            // Name and status
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          isIncoming
                                              ? invite.senderName
                                              : (invite.recipientName ??
                                                    'Unknown'),
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      // Status badge
                                      _buildStatusBadge(invite.status),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    isIncoming
                                        ? 'Sent you an invitation'
                                        : 'Invitation sent',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatDate(invite.createdAt),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        // Action buttons (only for incoming invites)
                        if (isIncoming) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: isProcessing
                                      ? null
                                      : () async {
                                          try {
                                            await ref
                                                .read(
                                                  acceptInviteMutationProvider
                                                      .notifier,
                                                )
                                                .acceptInvite(invite.id);
                                            if (context.mounted) {
                                              ref.refresh(
                                                pendingInvitesProvider,
                                              );
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Invitation accepted! Chat created.',
                                                  ),
                                                  duration: Duration(
                                                    seconds: 2,
                                                  ),
                                                  backgroundColor: Colors.green,
                                                ),
                                              );
                                            }
                                          } catch (e) {
                                            if (context.mounted) {
                                              final errorMessage =
                                                  InviteErrorHandler.getUserFriendlyMessage(
                                                    e,
                                                  );
                                              InviteErrorHandler.logError(
                                                'Accept Invite',
                                                e,
                                              );
                                              _showErrorDialog(
                                                context,
                                                'Accept Failed',
                                                errorMessage,
                                                error: e,
                                                onRetry: () async {
                                                  try {
                                                    await ref
                                                        .read(
                                                          acceptInviteMutationProvider
                                                              .notifier,
                                                        )
                                                        .acceptInvite(
                                                          invite.id,
                                                        );
                                                    if (context.mounted) {
                                                      ref.refresh(
                                                        pendingInvitesProvider,
                                                      );
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        const SnackBar(
                                                          content: Text(
                                                            'Invitation accepted! Chat created.',
                                                          ),
                                                          backgroundColor:
                                                              Colors.green,
                                                        ),
                                                      );
                                                    }
                                                  } catch (retryError) {
                                                    if (context.mounted) {
                                                      final retryMessage =
                                                          InviteErrorHandler.getUserFriendlyMessage(
                                                            retryError,
                                                          );
                                                      _showErrorDialog(
                                                        context,
                                                        'Accept Failed',
                                                        retryMessage,
                                                        error: retryError,
                                                      );
                                                    }
                                                  }
                                                },
                                              );
                                            }
                                          }
                                        },
                                  icon: const Icon(Icons.check),
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
                                  onPressed: isProcessing
                                      ? null
                                      : () async {
                                          try {
                                            await ref
                                                .read(
                                                  declineInviteMutationProvider
                                                      .notifier,
                                                )
                                                .declineInvite(invite.id);
                                            if (context.mounted) {
                                              ref.refresh(
                                                pendingInvitesProvider,
                                              );
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Invitation declined',
                                                  ),
                                                  duration: Duration(
                                                    seconds: 2,
                                                  ),
                                                  backgroundColor:
                                                      Colors.deepOrange,
                                                ),
                                              );
                                            }
                                          } catch (e) {
                                            if (context.mounted) {
                                              final errorMessage =
                                                  InviteErrorHandler.getUserFriendlyMessage(
                                                    e,
                                                  );
                                              InviteErrorHandler.logError(
                                                'Decline Invite',
                                                e,
                                              );
                                              _showErrorDialog(
                                                context,
                                                'Decline Failed',
                                                errorMessage,
                                                onRetry: () async {
                                                  try {
                                                    await ref
                                                        .read(
                                                          declineInviteMutationProvider
                                                              .notifier,
                                                        )
                                                        .declineInvite(
                                                          invite.id,
                                                        );
                                                    if (context.mounted) {
                                                      ref.refresh(
                                                        pendingInvitesProvider,
                                                      );
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        const SnackBar(
                                                          content: Text(
                                                            'Invitation declined',
                                                          ),
                                                          backgroundColor:
                                                              Colors.deepOrange,
                                                        ),
                                                      );
                                                    }
                                                  } catch (retryError) {
                                                    if (context.mounted) {
                                                      final retryMessage =
                                                          InviteErrorHandler.getUserFriendlyMessage(
                                                            retryError,
                                                          );
                                                      _showErrorDialog(
                                                        context,
                                                        'Decline Failed',
                                                        retryMessage,
                                                      );
                                                    }
                                                  }
                                                },
                                              );
                                            }
                                          }
                                        },
                                  icon: const Icon(Icons.close),
                                  label: const Text('Decline'),
                                ),
                              ),
                            ],
                          ),
                        ],
                        // Cancel button (only for outgoing pending invites)
                        if (!isIncoming && invite.status == 'pending') ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: isProcessing
                                  ? null
                                  : () async {
                                      try {
                                        await ref
                                            .read(
                                              cancelInviteMutationProvider
                                                  .notifier,
                                            )
                                            .cancelInvite(invite.id);
                                        if (context.mounted) {
                                          ref.refresh(sentInvitesProvider);
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Invitation canceled',
                                              ),
                                              duration: Duration(seconds: 2),
                                              backgroundColor: Colors.grey,
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          final errorMessage =
                                              InviteErrorHandler.getUserFriendlyMessage(
                                                e,
                                              );
                                          InviteErrorHandler.logError(
                                            'Cancel Invite',
                                            e,
                                          );
                                          _showErrorDialog(
                                            context,
                                            'Cancel Failed',
                                            errorMessage,
                                            onRetry: () async {
                                              try {
                                                await ref
                                                    .read(
                                                      cancelInviteMutationProvider
                                                          .notifier,
                                                    )
                                                    .cancelInvite(invite.id);
                                                if (context.mounted) {
                                                  ref.refresh(
                                                    sentInvitesProvider,
                                                  );
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Invitation canceled',
                                                      ),
                                                      backgroundColor:
                                                          Colors.grey,
                                                    ),
                                                  );
                                                }
                                              } catch (retryError) {
                                                if (context.mounted) {
                                                  final retryMessage =
                                                      InviteErrorHandler.getUserFriendlyMessage(
                                                        retryError,
                                                      );
                                                  _showErrorDialog(
                                                    context,
                                                    'Cancel Failed',
                                                    retryMessage,
                                                  );
                                                }
                                              }
                                            },
                                          );
                                        }
                                      }
                                    },
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Cancel Invitation'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.grey[700],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          },
          loading: () {
            print('[InvitationsList] Loading sent invites...');
            return const Center(child: CircularProgressIndicator());
          },
          error: (error, stack) {
            print('[InvitationsList] ❌ Error loading sent invites: $error');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: $error'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      print('[InvitationsList] Retrying...');
                      ref.refresh(sentInvitesProvider);
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () {
        print('[InvitationsList] Loading pending invites...');
        return const Center(child: CircularProgressIndicator());
      },
      error: (error, stack) {
        print('[InvitationsList] ❌ Error loading pending invites: $error');
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  print('[InvitationsList] Retrying...');
                  ref.refresh(pendingInvitesProvider);
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        );
      },
    );
  }
}

String _formatDate(DateTime dateTime) {
  final now = DateTime.now();
  final difference = now.difference(dateTime);

  if (difference.inSeconds < 60) {
    return 'just now';
  } else if (difference.inMinutes < 60) {
    return '${difference.inMinutes}m ago';
  } else if (difference.inHours < 24) {
    return '${difference.inHours}h ago';
  } else if (difference.inDays < 7) {
    return '${difference.inDays}d ago';
  } else {
    return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
  }
}

Widget _buildStatusBadge(String status) {
  Color backgroundColor;
  Color textColor;
  String displayText;
  IconData? icon;

  switch (status.toLowerCase()) {
    case 'pending':
      backgroundColor = Colors.amber.withValues(alpha: 0.2);
      textColor = Colors.amber[800]!;
      displayText = 'Pending';
      icon = Icons.schedule;
      break;
    case 'accepted':
      backgroundColor = Colors.green.withValues(alpha: 0.2);
      textColor = Colors.green[800]!;
      displayText = 'Accepted';
      icon = Icons.check_circle;
      break;
    case 'declined':
      backgroundColor = Colors.red.withValues(alpha: 0.2);
      textColor = Colors.red[800]!;
      displayText = 'Declined';
      icon = Icons.cancel;
      break;
    case 'canceled':
      backgroundColor = Colors.grey.withValues(alpha: 0.2);
      textColor = Colors.grey[800]!;
      displayText = 'Canceled';
      icon = Icons.block;
      break;
    default:
      backgroundColor = Colors.grey.withValues(alpha: 0.2);
      textColor = Colors.grey[800]!;
      displayText = status;
      icon = null;
  }

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
        ],
        Text(
          displayText,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ],
    ),
  );
}

void _showErrorDialog(
  BuildContext context,
  String title,
  String message, {
  VoidCallback? onRetry,
  dynamic error,
}) {
  final isOffline =
      InviteErrorHandler.indicatesOfflineState(error) ||
      (error?.toString().contains('Connection') ?? false);
  final isRecoverable = InviteErrorHandler.isRecoverableError(error);
  final suggestion = InviteErrorHandler.getRecoverySuggestion(error);
  final severity = InviteErrorHandler.getErrorSeverity(error);

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          Icon(
            severity == ErrorSeverity.critical ? Icons.error : Icons.warning,
            color: severity == ErrorSeverity.critical
                ? Colors.red
                : Colors.orange,
            size: 24,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(title)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            if (isOffline) ...[const SizedBox(height: 12), _buildOfflineHint()],
            if (isRecoverable && !isOffline) ...[
              const SizedBox(height: 12),
              _buildRecoveryHint(suggestion),
            ],
            if (suggestion.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildSuggestionChips(suggestion),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Dismiss'),
        ),
        if (isRecoverable && onRetry != null)
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              onRetry();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          )
        else if (isOffline && onRetry != null)
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              // Show Toast instead of immediate retry
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Waiting for connection... Please check your network.',
                  ),
                  duration: Duration(seconds: 3),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            icon: const Icon(Icons.cloud_off),
            label: const Text('Waiting...'),
          ),
      ],
    ),
  );
}

/// Build offline connection hint
Widget _buildOfflineHint() {
  return Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: Colors.red[50],
      border: Border.all(color: Colors.red[200]!),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Row(
      children: [
        Icon(Icons.cloud_off, color: Colors.red[700], size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'No internet connection detected. Please enable WiFi or mobile data.',
            style: TextStyle(color: Colors.red[700], fontSize: 12),
          ),
        ),
      ],
    ),
  );
}

/// Build recovery hint
Widget _buildRecoveryHint(String suggestion) {
  return Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: Colors.blue[50],
      border: Border.all(color: Colors.blue[200]!),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Row(
      children: [
        Icon(Icons.info, color: Colors.blue[700], size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Try: $suggestion',
            style: TextStyle(color: Colors.blue[700], fontSize: 12),
          ),
        ),
      ],
    ),
  );
}

/// Build suggestion action chips
Widget _buildSuggestionChips(String suggestionText) {
  final suggestions = suggestionText.split('•').map((s) => s.trim()).toList();

  return Wrap(
    spacing: 6,
    children: suggestions
        .where((s) => s.isNotEmpty)
        .map(
          (suggestion) => Chip(
            label: Text(suggestion, style: const TextStyle(fontSize: 11)),
            backgroundColor: Colors.grey[200],
            onDeleted: null,
          ),
        )
        .toList(),
  );
}

// ---------------------------------------------------------------------------
// Group Invitations Tab
// ---------------------------------------------------------------------------

/// Stateful widget that loads and displays pending group invitations.
class _GroupInvitationsList extends StatefulWidget {
  final String token;

  const _GroupInvitationsList({required this.token});

  @override
  State<_GroupInvitationsList> createState() => _GroupInvitationsListState();
}

class _GroupInvitationsListState extends State<_GroupInvitationsList> {
  static const String _baseUrl = 'http://localhost:8081';

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

