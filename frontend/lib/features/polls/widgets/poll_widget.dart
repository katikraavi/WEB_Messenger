import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Immutable value object for a single poll option, including its current vote
/// count as returned by the poll API.
@immutable
class PollOptionData {
  final String id;
  final String text;
  final int voteCount;
  
  /// For non-anonymous polls: list of voters for this option
  /// Each voter is a map with 'userId', 'username', and 'email'
  final List<Map<String, dynamic>>? voters;

  const PollOptionData({
    required this.id,
    required this.text,
    required this.voteCount,
    this.voters,
  });

  factory PollOptionData.fromJson(Map<String, dynamic> json) {
    return PollOptionData(
      id: json['id'] as String,
      text: json['text'] as String? ?? '',
      voteCount: (json['voteCount'] ?? json['vote_count'] ?? 0) as int,
      voters: (json['voters'] as List<dynamic>?)
          ?.map((v) => Map<String, dynamic>.from(v as Map))
          .toList(),
    );
  }
}

/// Immutable value object representing a full poll and its aggregate results.
@immutable
class PollData {
  final String id;
  final String question;
  final List<PollOptionData> options;
  final bool isAnonymous;
  final bool isClosed;
  final int totalVotes;

  /// The option ID the current user has voted for, or null if they haven't
  /// voted yet.
  final String? currentUserVotedOptionId;

  const PollData({
    required this.id,
    required this.question,
    required this.options,
    required this.isAnonymous,
    required this.isClosed,
    required this.totalVotes,
    required this.currentUserVotedOptionId,
  });

  factory PollData.fromJson(Map<String, dynamic> json) {
    final rawOptions = (json['options'] as List<dynamic>?) ?? [];
    return PollData(
      id: json['id'] as String,
      question: json['question'] as String? ?? '',
      options: rawOptions
          .map((o) => PollOptionData.fromJson(o as Map<String, dynamic>))
          .toList(),
      isAnonymous: (json['isAnonymous'] ?? json['is_anonymous'] ?? false) as bool,
      isClosed: (json['isClosed'] ?? json['is_closed'] ?? false) as bool,
      totalVotes: (json['totalVotes'] ?? json['total_votes'] ?? 0) as int,
      currentUserVotedOptionId:
          (json['currentUserVotedOptionId'] ?? json['current_user_voted_option_id'])
              as String?,
    );
  }
}

/// Renders a poll inside a chat message.
///
/// Shows the question, each option as a tappable progress-bar row, vote
/// percentages, and a "Closed" badge when [PollData.isClosed] is true.
/// When the user taps an option [onVote] is called with the option id.
class PollWidget extends StatelessWidget {
  final PollData poll;

  /// Called with the tapped option's id.  `async` so callers can await the
  /// network call.
  final Future<void> Function(String optionId) onVote;

  /// Called when the user retracts their vote. Optional.
  final Future<void> Function()? onRetract;

  const PollWidget({
    super.key,
    required this.poll,
    required this.onVote,
    this.onRetract,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasUserVoted = poll.currentUserVotedOptionId != null;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: question + badges
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        poll.question,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          // Vote count badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F9FF),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFFBFDBFE),
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              '${poll.totalVotes} vote${poll.totalVotes == 1 ? '' : 's'}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: const Color(0xFF0369A1),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Anonymous badge
                          if (poll.isAnonymous)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFFD1D5DB),
                                  width: 0.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.lock_outline,
                                    size: 12,
                                    color: const Color(0xFF6B7280),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Anonymous',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: const Color(0xFF6B7280),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(width: 8),
                          // Closed badge
                          if (poll.isClosed)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFFFECACA),
                                  width: 0.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.lock,
                                    size: 12,
                                    color: const Color(0xFFDC2626),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Closed',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: const Color(0xFFDC2626),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Option rows
            ...poll.options.map((option) {
              final isCurrentVote =
                  option.id == poll.currentUserVotedOptionId;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _EnhancedOptionRow(
                    option: option,
                    totalVotes: poll.totalVotes,
                    isVoted: isCurrentVote,
                    isClosed: poll.isClosed,
                    isAnonymous: poll.isAnonymous,
                    onTap: poll.isClosed ? null : () => onVote(option.id),
                  ),
                  // Voter info for non-anonymous polls
                  if (!poll.isAnonymous &&
                      option.voters != null &&
                      option.voters!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 12,
                        bottom: 12,
                        top: 6,
                      ),
                      child: _VotersList(voters: option.voters!),
                    )
                  else
                    const SizedBox(height: 8),
                ],
              );
            }),

            // Footer: retract button
            if (hasUserVoted && !poll.isClosed && onRetract != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onRetract,
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Retract vote'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF6B7280),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Enhanced option row with improved visual hierarchy and voter count
class _EnhancedOptionRow extends StatelessWidget {
  final PollOptionData option;
  final int totalVotes;
  final bool isVoted;
  final bool isClosed;
  final bool isAnonymous;
  final VoidCallback? onTap;

  const _EnhancedOptionRow({
    required this.option,
    required this.totalVotes,
    required this.isVoted,
    required this.isClosed,
    required this.isAnonymous,
    required this.onTap,
  });

  double get _fraction =>
      totalVotes > 0 ? option.voteCount / totalVotes : 0.0;

  String get _percentageLabel =>
      totalVotes == 0 ? '0%' : '${(_fraction * 100).round()}%';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isClickable = onTap != null;

    final primaryColor = theme.colorScheme.primary;
    final fillColor = isVoted
        ? primaryColor.withOpacity(0.15)
        : const Color(0xFFF3F4F6);
    final borderColor = isVoted
        ? primaryColor.withOpacity(0.4)
        : const Color(0xFFE5E7EB);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isClickable ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          splashColor: isClickable
              ? primaryColor.withOpacity(0.1)
              : Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: borderColor, width: 1.5),
              borderRadius: BorderRadius.circular(12),
              color: fillColor,
            ),
            clipBehavior: Clip.hardEdge,
            child: Stack(
              children: [
                // Animated progress fill
                FractionallySizedBox(
                  widthFactor: _fraction,
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          primaryColor.withOpacity(0.25),
                          primaryColor.withOpacity(0.12),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),
                // Content row
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      // Option text
                      Expanded(
                        child: Text(
                          option.text,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight:
                                isVoted ? FontWeight.w700 : FontWeight.w500,
                            color: isVoted
                                ? const Color(0xFF111827)
                                : const Color(0xFF374151),
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Vote count and percentage column
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _percentageLabel,
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: isVoted
                                  ? primaryColor
                                  : const Color(0xFF6B7280),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${option.voteCount} vote${option.voteCount == 1 ? '' : 's'}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: const Color(0xFF9CA3AF),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      // Voted checkmark
                      if (isVoted)
                        Icon(
                          Icons.check_circle_rounded,
                          size: 20,
                          color: primaryColor,
                        )
                      else if (isClickable)
                        Icon(
                          Icons.radio_button_unchecked_rounded,
                          size: 20,
                          color: const Color(0xFFD1D5DB),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Displays voters as compact avatars with initials/names
class _VotersList extends StatelessWidget {
  final List<Map<String, dynamic>> voters;

  const _VotersList({required this.voters});

  String _getInitials(Map<String, dynamic> voter) {
    final username = voter['username'] as String?;
    final email = voter['email'] as String?;
    final displayName = username ?? email ?? 'U';

    // Get first letter of username, or first letter of email
    if (displayName.contains('@')) {
      return displayName.split('@')[0][0].toUpperCase();
    }
    return displayName.isEmpty ? 'U' : displayName[0].toUpperCase();
  }

  Color _getColorForVoter(String username) {
    final colors = [
      const Color(0xFFEC4899), // pink
      const Color(0xFF8B5CF6), // purple
      const Color(0xFF3B82F6), // blue
      const Color(0xFF06B6D4), // cyan
      const Color(0xFF10B981), // emerald
      const Color(0xFFF59E0B), // amber
      const Color(0xFFEF4444), // red
    ];
    final hash = username.hashCode;
    return colors[hash.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.check_circle, size: 14, color: const Color(0xFF10B981)),
            const SizedBox(width: 6),
            Text(
              'Voted by',
              style: theme.textTheme.labelSmall?.copyWith(
                color: const Color(0xFF6B7280),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: voters.take(6).map((voter) {
            final username = voter['username'] as String?;
            final email = voter['email'] as String?;
            final initials = _getInitials(voter);
            final avatarColor = _getColorForVoter(username ?? email ?? '');
            final displayName = username ?? email;

            return Tooltip(
              message: displayName ?? 'Unknown',
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: avatarColor,
                  boxShadow: [
                    BoxShadow(
                      color: avatarColor.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(8),
                child: Text(
                  initials,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }).toList(),
        ),
        if (voters.length > 6) ...[
          const SizedBox(height: 6),
          Text(
            '+ ${voters.length - 6} more',
            style: theme.textTheme.labelSmall?.copyWith(
              color: const Color(0xFF9CA3AF),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

/// A simpler option row for backwards compatibility (kept for reference)
class _OptionRow extends StatelessWidget {
  final PollOptionData option;
  final int totalVotes;
  final bool isVoted;
  final bool isClosed;
  final VoidCallback? onTap;

  const _OptionRow({
    required this.option,
    required this.totalVotes,
    required this.isVoted,
    required this.isClosed,
    required this.onTap,
  });

  double get _fraction =>
      totalVotes > 0 ? option.voteCount / totalVotes : 0.0;

  String get _percentageLabel =>
      '${(_fraction * 100).round()}%';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fillColor = isVoted
        ? theme.colorScheme.primary.withOpacity(0.25)
        : Colors.grey.shade200;
    final borderColor = isVoted
        ? theme.colorScheme.primary
        : Colors.grey.shade300;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(8),
          ),
          clipBehavior: Clip.hardEdge,
          child: Stack(
            children: [
              // Progress fill
              FractionallySizedBox(
                widthFactor: _fraction,
                child: Container(
                  height: 44,
                  color: fillColor,
                ),
              ),
              // Label row
              SizedBox(
                height: 44,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          option.text,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: isVoted ? FontWeight.w600 : null,
                          ),
                        ),
                      ),
                      Text(
                        _percentageLabel,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Colors.grey.shade700),
                      ),
                      if (isVoted) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.check_circle,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
