import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:frontend/core/config/web_layout_config.dart';
import 'chat_detail_screen.dart';

/// Holds the arguments needed to open a single chat pane.
class ChatPaneArgs {
  final String chatId;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserAvatarUrl;
  final bool isGroup;

  const ChatPaneArgs({
    required this.chatId,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserAvatarUrl,
    this.isGroup = false,
  });
}

/// Side-by-side multi-chat layout for wide web screens.
///
/// Only rendered on web (`kIsWeb`) when the screen width meets the
/// [WebLayoutConfig.kDualPaneBreakpoint].  On narrow screens or non-web
/// platforms [SizedBox.shrink] is returned instead.
///
/// Each pane runs its own independent [ChatDetailScreen], which means panes
/// maintain separate WebSocket subscriptions and message lists.
class DualChatScreen extends StatelessWidget {
  final List<ChatPaneArgs> panes;

  const DualChatScreen({
    super.key,
    required this.panes,
  });

  Widget _buildPane(ChatPaneArgs pane, int index) {
    return ChatDetailScreen(
      key: ValueKey('pane_${index}_${pane.chatId}'),
      chatId: pane.chatId,
      otherUserId: pane.otherUserId,
      otherUserName: pane.otherUserName,
      otherUserAvatarUrl: pane.otherUserAvatarUrl,
      isGroup: pane.isGroup,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Guard: only available on web at large widths
    if (!kIsWeb || !WebLayoutConfig.isDualPaneMode(context) || panes.isEmpty) {
      return const SizedBox.shrink();
    }

    final visiblePanes = panes.take(4).toList(growable: false);

    final paneCount = visiblePanes.length;

    if (paneCount == 1) {
      final pane = visiblePanes.first;
      return Scaffold(body: _buildPane(pane, 0));
    }

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          const gap = 1.0;
          const minPaneWidth = 300.0;
          final availableWidth = constraints.maxWidth;
          final totalGapWidth = gap * (paneCount - 1);
          final fittedPaneWidth =
              (availableWidth - totalGapWidth) / paneCount;
          final paneWidth = fittedPaneWidth < minPaneWidth
              ? minPaneWidth
              : fittedPaneWidth;

          final row = Row(
            children: [
              for (var i = 0; i < paneCount; i++) ...[
                SizedBox(
                  width: paneWidth,
                  child: _buildPane(visiblePanes[i], i),
                ),
                if (i < paneCount - 1)
                  const SizedBox(
                    width: gap,
                    child: VerticalDivider(width: 1, thickness: 1),
                  ),
              ],
            ],
          );

          return paneWidth == fittedPaneWidth
              ? row
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: row,
                );
        },
      ),
    );
  }
}
