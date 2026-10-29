import 'package:flutter/material.dart';

class HighlightText extends StatelessWidget {
  const HighlightText(
    this.text, {
    super.key,
    this.query = '',
    this.style,
    this.maxLines,
    this.overflow,
  });

  final String text;
  final String query;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final term = query.trim().toLowerCase();
    final lower = text.toLowerCase();

    if (term.isEmpty || lower.length != text.length || !lower.contains(term)) {
      return Text(text, style: style, maxLines: maxLines, overflow: overflow);
    }

    final scheme = Theme.of(context).colorScheme;
    final marked = TextStyle(
      fontWeight: FontWeight.w800,
      backgroundColor: scheme.primary.withValues(alpha: 0.18),
    );

    final spans = <TextSpan>[];
    var start = 0;
    while (true) {
      final index = lower.indexOf(term, start);
      if (index == -1) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (index > start) spans.add(TextSpan(text: text.substring(start, index)));
      spans.add(
        TextSpan(
          text: text.substring(index, index + term.length),
          style: marked,
        ),
      );
      start = index + term.length;
    }

    return Text.rich(
      TextSpan(children: spans),
      style: style,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
