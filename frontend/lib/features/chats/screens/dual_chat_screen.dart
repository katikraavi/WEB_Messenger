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

  const ChatPaneArgs({
    required this.chatId,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserAvatarUrl,
  });
}

/// Side-by-side dual-chat layout for wide web screens.
///
/// Only rendered on web (`kIsWeb`) when the screen width meets the
/// [WebLayoutConfig.kDualPaneBreakpoint].  On narrow screens or non-web
/// platforms [SizedBox.shrink] is returned instead.
///
/// Each pane runs its own independent [ChatDetailScreen], which means both
/// panes maintain separate WebSocket subscriptions and message lists.
class DualChatScreen extends StatelessWidget {
  final ChatPaneArgs leftPane;
  final ChatPaneArgs rightPane;

  const DualChatScreen({
    super.key,
    required this.leftPane,
    required this.rightPane,
  });

  @override
  Widget build(BuildContext context) {
    // Guard: only available on web at large widths
    if (!kIsWeb || !WebLayoutConfig.isDualPaneMode(context)) {
      return const SizedBox.shrink();
    }

    return Scaffold(
      body: Row(
        children: [
          Expanded(
            flex: WebLayoutConfig.kLeftPaneFlex,
            child: ChatDetailScreen(
              key: ValueKey('left_${leftPane.chatId}'),
              chatId: leftPane.chatId,
              otherUserId: leftPane.otherUserId,
              otherUserName: leftPane.otherUserName,
              otherUserAvatarUrl: leftPane.otherUserAvatarUrl,
            ),
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(
            flex: WebLayoutConfig.kRightPaneFlex,
            child: ChatDetailScreen(
              key: ValueKey('right_${rightPane.chatId}'),
              chatId: rightPane.chatId,
              otherUserId: rightPane.otherUserId,
              otherUserName: rightPane.otherUserName,
              otherUserAvatarUrl: rightPane.otherUserAvatarUrl,
            ),
          ),
        ],
      ),
    );
  }
}
