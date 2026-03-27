import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as provider_pkg;
import 'package:frontend/core/services/api_client.dart';
import '../providers/active_chats_provider.dart';
import '../providers/chats_provider.dart';
import '../providers/user_profile_provider.dart';
import '../models/chat_model.dart';
import '../services/chat_api_service.dart';
import '../widgets/chat_list_tile_consumer.dart';
import '../widgets/archived_chats_section.dart';
import '../providers/archived_chats_provider.dart';
import 'dual_chat_screen.dart';
import '../../../core/config/web_layout_config.dart';
import '../../auth/providers/auth_provider.dart' as auth;

/// Screen for displaying the list of active chats
///
/// Features:
/// - Displays active (unarchived) chats sorted by recency
/// - Shows last message preview for each chat
/// - Tap to open chat detail screen
/// - Pull-to-refresh to reload chats
/// - Empty state UI when no chats
class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  Widget _buildShell(BuildContext context, Widget child) {
    if (!kIsWeb) {
      return child;
    }

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1040),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
          child: child,
        ),
      ),
    );
  }

  Widget _buildIntroCard(BuildContext context, List<Chat> chats) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1D4ED8), Color(0xFF0EA5E9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.16),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.forum_outlined, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Conversations',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  chats.isEmpty
                      ? 'Start a conversation by sending an invitation.'
                      : '${chats.length} active chat${chats.length == 1 ? '' : 's'} ready to open.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.92)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openSideBySidePicker(
    BuildContext context,
    WidgetRef ref,
    String token,
    String currentUserId,
    List<Chat> chats,
  ) async {
    final directChats = chats.where((chat) => !chat.isGroup).toList();

    if (directChats.length < 2) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Need at least two chats to split view'),
          ),
        );
      }
      return;
    }

    String? leftChatId;
    String? rightChatId;

    // Pre-fetch usernames for all chats to display in dropdown
    final chatUsernames = <String, String>{};
    for (final chat in directChats) {
      final otherUserId = chat.getOtherId(currentUserId);
      try {
        final profile = await ref.read(
          userProfileProvider((otherUserId, token)).future,
        );
        chatUsernames[chat.id] = profile.username;
      } catch (_) {
        chatUsernames[chat.id] = 'Unknown User';
      }
    }

    final selected = await showDialog<(String, String)>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Open side by side'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: leftChatId,
                    decoration: const InputDecoration(labelText: 'Left pane'),
                    items: directChats
                        .map(
                          (chat) => DropdownMenuItem<String>(
                            value: chat.id,
                            child: Text(chatUsernames[chat.id] ?? 'Loading...'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setDialogState(() => leftChatId = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: rightChatId,
                    decoration: const InputDecoration(labelText: 'Right pane'),
                    items: directChats
                        .map(
                          (chat) => DropdownMenuItem<String>(
                            value: chat.id,
                            child: Text(chatUsernames[chat.id] ?? 'Loading...'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setDialogState(() => rightChatId = value);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed:
                      (leftChatId == null ||
                          rightChatId == null ||
                          leftChatId == rightChatId)
                      ? null
                      : () => Navigator.of(
                          dialogContext,
                        ).pop((leftChatId!, rightChatId!)),
                  child: const Text('Open'),
                ),
              ],
            );
          },
        );
      },
    );

    if (selected == null || !context.mounted) return;

    final left = directChats.firstWhere((c) => c.id == selected.$1);
    final right = directChats.firstWhere((c) => c.id == selected.$2);
    final leftOtherUserId = left.getOtherId(currentUserId);
    final rightOtherUserId = right.getOtherId(currentUserId);

    final leftProfile = await ref.read(
      userProfileProvider((leftOtherUserId, token)).future,
    );
    final rightProfile = await ref.read(
      userProfileProvider((rightOtherUserId, token)).future,
    );

    if (!context.mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DualChatScreen(
          leftPane: ChatPaneArgs(
            chatId: left.id,
            otherUserId: leftOtherUserId,
            otherUserName: leftProfile.username,
            otherUserAvatarUrl: leftProfile.profilePictureUrl,
          ),
          rightPane: ChatPaneArgs(
            chatId: right.id,
            otherUserId: rightOtherUserId,
            otherUserName: rightProfile.username,
            otherUserAvatarUrl: rightProfile.profilePictureUrl,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get current user ID and token using old provider package
    final authProvider = provider_pkg.Provider.of<auth.AuthProvider>(context);
    final currentUserId = authProvider.user?.userId ?? '';
    final token = authProvider.token ?? '';

    if (token.isEmpty) {
      return _buildShell(
        context,
        const Center(child: Text('Not authenticated')),
      );
    }

    // Get active chats with token parameter
    final activeChatsStream = ref.watch(activeChatListProvider(token));

    final baseUrl = ApiClient.getBaseUrl();
    final chatApiService = ChatApiService(baseUrl: baseUrl);

    return _buildShell(
      context,
      RefreshIndicator(
        onRefresh: () async {
          // Refresh chats from backend
          ref.invalidate(chatsProvider(token));
          ref.invalidate(activeChatListProvider(token));
          ref.invalidate(archivedChatsProvider(token));
        },
        child: activeChatsStream.when(
          // Loading state
          loading: () => ListView(
            children: [
              _buildIntroCard(context, const []),
              const Padding(
                padding: EdgeInsets.only(top: 120),
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
          ),

          // Error state
          error: (error, stackTrace) => ListView(
            children: [
              _buildIntroCard(context, const []),
              Padding(
                padding: const EdgeInsets.only(top: 56),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to load chats',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          error.toString(),
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          ref.invalidate(activeChatListProvider(token));
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Success state
          data: (chats) {
            final showDualPaneEntry =
                kIsWeb &&
                MediaQuery.of(context).size.width >=
                    WebLayoutConfig.kDualPaneBreakpoint;

            return ListView(
              children: [
                _buildIntroCard(context, chats),
                if (showDualPaneEntry)
                  Container(
                    margin: const EdgeInsets.fromLTRB(12, 2, 12, 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFD8E4FF)),
                    ),
                    child: ListTile(
                      leading: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF2FF),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.splitscreen_outlined),
                      ),
                      title: const Text('Open side by side'),
                      subtitle: const Text(
                        'Compare two chats in a dual-pane layout',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openSideBySidePicker(
                        context,
                        ref,
                        token,
                        currentUserId,
                        chats,
                      ),
                    ),
                  ),
                ArchivedChatsSection(
                  token: token,
                  currentUserId: currentUserId,
                ),
                if (chats.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 100),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No active chats',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              'Archived chats stay in the archive section. Start by inviting someone from search or use your existing test accounts.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: Colors.grey[600]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...chats.map((chat) {
                    final otherUserId = chat.getOtherId(currentUserId);
                    return ChatListTileConsumer(
                      key: ValueKey('chat-tile-${chat.id}'),
                      chat: chat,
                      otherUserId: otherUserId,
                      currentUserId: currentUserId,
                      token: token,
                      lastMessage: chat.lastMessagePreview,
                      onArchive: () async {
                        try {
                          await chatApiService.archiveChat(
                            token: token,
                            chatId: chat.id,
                          );
                          ref.invalidate(chatsProvider(token));
                          ref.invalidate(activeChatListProvider(token));
                          ref.invalidate(archivedChatsProvider(token));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Archived selected chat'),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to archive chat: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      onDelete: () async {
                        // Show confirmation dialog
                        if (!context.mounted) return;
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Delete Connection?'),
                            content: const Text(
                              'This will permanently delete this connection. You will need to send a new invite to reconnect.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text(
                                  'Delete',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        );

                        if (confirmed != true || !context.mounted) return;

                        try {
                          await chatApiService.deleteChat(
                            token: token,
                            chatId: chat.id,
                          );
                          ref.invalidate(chatsProvider(token));
                          ref.invalidate(activeChatListProvider(token));
                          ref.invalidate(archivedChatsProvider(token));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Deleted connection'),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to delete chat: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                    );
                  }),
              ],
            );
          },
        ),
      ),
    );
  }
}
