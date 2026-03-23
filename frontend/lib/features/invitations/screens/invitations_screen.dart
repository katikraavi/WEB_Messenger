import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as provider;

import '../models/chat_invite_model.dart';
import '../providers/invites_provider.dart';
import '../providers/network_provider.dart';
import '../services/invite_error_handler.dart';
import '../services/resilient_http_client.dart';
import '../services/group_invite_service.dart';
import '../../../core/notifications/local_notification_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../chats/widgets/user_avatar_widget.dart';
import '../../chats/screens/create_group_screen.dart';
import '../../chats/providers/active_chats_provider.dart';
import '../../chats/providers/chats_provider.dart';
import 'send_invite_picker_screen.dart';

part 'invitations_helpers.dart';
part 'invitations_group_list.dart';

/// Main invitations screen - shows all invitations (pending and sent) in a single unified view
class InvitationsScreen extends ConsumerWidget {
  const InvitationsScreen({Key? key}) : super(key: key);

  String _badgeLabel(int count) {
    if (count > 99) {
      return '99+';
    }
    return count.toString();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    // Watch real-time updates from WebSocket to enable automatic refresh
    ref.watch(invitationRealtimeUpdatesProvider);

    final directPendingCount = ref.watch(pendingInvitesProvider).maybeWhen(
      data: (invites) => invites.length,
      orElse: () => 0,
    );
    final groupPendingCount = ref.watch(pendingGroupInvitesProvider).maybeWhen(
      data: (invites) => invites.length,
      orElse: () => 0,
    );

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
                ref.refresh(pendingInvitesProvider);
                ref.refresh(sentInvitesProvider);
                ref.invalidate(pendingGroupInvitesProvider);
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
              tooltip: 'Create or Invite',
              onPressed: () async {
                final action = await showModalBottomSheet<String>(
                  context: context,
                  builder: (sheetContext) {
                    return SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: const Icon(Icons.person_add_alt_1),
                            title: const Text('Send Direct Invite'),
                            subtitle: const Text('Invite a user to a 1:1 chat'),
                            onTap: () => Navigator.of(sheetContext).pop('invite'),
                          ),
                          ListTile(
                            leading: const Icon(Icons.group_add),
                            title: const Text('Create Group Chat'),
                            subtitle: const Text('Start a new group conversation'),
                            onTap: () => Navigator.of(sheetContext).pop('group'),
                          ),
                        ],
                      ),
                    );
                  },
                );

                if (!context.mounted || action == null) {
                  return;
                }

                if (action == 'invite') {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const SendInvitePickerScreen(),
                    ),
                  );
                  return;
                }

                final createdGroupId = await Navigator.of(context).push<String>(
                  MaterialPageRoute(
                    builder: (context) => const CreateGroupScreen(),
                  ),
                );

                if (!context.mounted || createdGroupId == null) {
                  return;
                }

                final authProvider = provider.Provider.of<AuthProvider>(
                  context,
                  listen: false,
                );
                final token = authProvider.token;
                if (token != null && token.isNotEmpty) {
                  ref.invalidate(chatsProvider(token));
                  ref.invalidate(activeChatListProvider(token));
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Group created: $createdGroupId'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(
                icon: Badge(
                  isLabelVisible: directPendingCount > 0,
                  label: Text(_badgeLabel(directPendingCount)),
                  child: const Icon(Icons.person),
                ),
                text: 'Direct',
              ),
              Tab(
                icon: Badge(
                  isLabelVisible: groupPendingCount > 0,
                  label: Text(_badgeLabel(groupPendingCount)),
                  child: const Icon(Icons.group),
                ),
                text: 'Groups',
              ),
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
            final pendingSent = sent.where((invite) => invite.status == 'pending');

            // Create unified list
            final allInvitations = [
              ...pending.map((i) => {'type': 'incoming', 'data': i}),
              ...pendingSent.map((i) => {'type': 'outgoing', 'data': i}),
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
                                            await LocalNotificationService
                                                .instance
                                                .dismissInviteNotification(
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
                                                    await LocalNotificationService
                                                        .instance
                                                        .dismissInviteNotification(
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
                                            await LocalNotificationService
                                                .instance
                                                .dismissInviteNotification(
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
                                                    await LocalNotificationService
                                                        .instance
                                                        .dismissInviteNotification(
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
            return const Center(child: CircularProgressIndicator());
          },
          error: (error, stack) {
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
        return const Center(child: CircularProgressIndicator());
      },
      error: (error, stack) {
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

