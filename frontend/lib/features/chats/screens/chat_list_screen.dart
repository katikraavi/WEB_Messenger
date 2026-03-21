import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as provider_pkg;
import '../providers/active_chats_provider.dart';
import '../providers/chats_provider.dart';
import '../services/chat_api_service.dart';
import '../widgets/chat_list_tile_consumer.dart';
import '../widgets/archived_chats_section.dart';
import '../providers/archived_chats_provider.dart';
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get current user ID and token using old provider package
    final authProvider = provider_pkg.Provider.of<auth.AuthProvider>(context);
    final currentUserId = authProvider.user?.userId ?? '';
    final token = authProvider.token ?? '';

    debugPrint(
      '[ChatListScreen] Building with token: ${token.isNotEmpty ? 'present' : 'EMPTY'}',
    );
    debugPrint('[ChatListScreen] Current user: ${authProvider.user?.username}');

    if (token.isEmpty) {
      debugPrint('[ChatListScreen] ❌ No token available');
      return Scaffold(
        appBar: AppBar(title: const Text('Chats')),
        body: const Center(child: Text('Not authenticated')),
      );
    }

    // Get active chats with token parameter
    debugPrint(
      '[ChatListScreen] 📡 Watching activeChatListProvider for token: ${token.substring(0, 20)}...',
    );
    final activeChatsStream = ref.watch(activeChatListProvider(token));

    const baseUrl = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://localhost:8081',
    );
    final chatApiService = ChatApiService(baseUrl: baseUrl);

    return RefreshIndicator(
      onRefresh: () async {
        // Refresh chats from backend
        ref.invalidate(chatsProvider(token));
        ref.invalidate(activeChatListProvider(token));
        ref.invalidate(archivedChatsProvider(token));
      },
      child: activeChatsStream.when(
        // Loading state
        loading: () => const Center(child: CircularProgressIndicator()),

        // Error state
        error: (error, stackTrace) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
              const SizedBox(height: 16),
              Text(
                'Failed to load chats',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
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

        // Success state
        data: (chats) {
          return ListView(
            children: [
              ArchivedChatsSection(token: token, currentUserId: currentUserId),
              if (chats.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 120),
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
                        Text(
                          'Archived chats stay in the archive section',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.grey[600]),
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
                            const SnackBar(content: Text('Deleted connection')),
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
    );
  }
}
