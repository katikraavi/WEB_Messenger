import 'package:flutter/material.dart';

class MessageSearchResult extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle? style;

  const MessageSearchResult({
    super.key,
    required this.text,
    required this.query,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final baseStyle = style ?? DefaultTextStyle.of(context).style;
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      return Text(text, style: baseStyle);
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = normalizedQuery.toLowerCase();
    final spans = <TextSpan>[];
    var start = 0;

    while (start < text.length) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) {
        spans.add(TextSpan(text: text.substring(start), style: baseStyle));
        break;
      }

      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index), style: baseStyle));
      }

      spans.add(
        TextSpan(
          text: text.substring(index, index + normalizedQuery.length),
          style: baseStyle.copyWith(
            backgroundColor: Colors.yellow.shade400,
            fontWeight: FontWeight.w700,
          ),
        ),
      );

      start = index + normalizedQuery.length;
    }

    return RichText(text: TextSpan(children: spans));
  }
}