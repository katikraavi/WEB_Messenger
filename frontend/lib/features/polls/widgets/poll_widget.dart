import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Immutable value object for a single poll option, including its current vote
/// count as returned by the poll API.
@immutable
class PollOptionData {
  final String id;
  final String text;
  final int voteCount;

  const PollOptionData({
    required this.id,
    required this.text,
    required this.voteCount,
  });

  factory PollOptionData.fromJson(Map<String, dynamic> json) {
    return PollOptionData(
      id: json['id'] as String,
      text: json['text'] as String? ?? '',
      voteCount: (json['voteCount'] ?? json['vote_count'] ?? 0) as int,
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

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: question + optional "Closed" badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    poll.question,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                if (poll.isClosed)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Closed',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: Colors.grey.shade700),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Option rows
            ...poll.options.map((option) => _OptionRow(
                  option: option,
                  totalVotes: poll.totalVotes,
                  isVoted: option.id == poll.currentUserVotedOptionId,
                  isClosed: poll.isClosed,
                  onTap: poll.isClosed
                      ? null
                      : () => onVote(option.id),
                )),

            // Footer: total vote count + retract button
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${poll.totalVotes} vote${poll.totalVotes == 1 ? '' : 's'}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: Colors.grey.shade600),
                ),
                // Show retract option if user voted and poll is open
                if (hasUserVoted && !poll.isClosed && onRetract != null)
                  TextButton.icon(
                    onPressed: onRetract,
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Retract'),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A single option row showing text, progress bar, percentage and optional
/// check icon.
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
