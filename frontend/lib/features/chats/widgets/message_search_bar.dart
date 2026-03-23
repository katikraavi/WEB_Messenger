import 'package:flutter/material.dart';

class MessageSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final int totalResults;
  final int currentIndex;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onClose;

  const MessageSearchBar({
    super.key,
    required this.controller,
    required this.totalResults,
    required this.currentIndex,
    required this.onQueryChanged,
    required this.onNext,
    required this.onPrevious,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final hasResults = totalResults > 0;

    return Material(
      color: Colors.amber.shade50,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                autofocus: true,
                onChanged: onQueryChanged,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Search messages',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: controller.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            controller.clear();
                            onQueryChanged('');
                          },
                          icon: const Icon(Icons.clear),
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              hasResults ? '${currentIndex + 1} of $totalResults' : '0 results',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            IconButton(
              onPressed: hasResults ? onPrevious : null,
              icon: const Icon(Icons.keyboard_arrow_up),
              tooltip: 'Previous result',
            ),
            IconButton(
              onPressed: hasResults ? onNext : null,
              icon: const Icon(Icons.keyboard_arrow_down),
              tooltip: 'Next result',
            ),
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close),
              tooltip: 'Close search',
            ),
          ],
        ),
      ),
    );
  }
}