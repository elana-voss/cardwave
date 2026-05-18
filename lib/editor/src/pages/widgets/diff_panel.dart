import 'package:flutter/material.dart';

/// One side of the AI-diff confirmation dialog — a titled, boxed,
/// selectable rich-text view of the original or suggested text with the
/// diff highlights baked into [spans]. `tokenCount` adds a "(N Tokens)"
/// suffix to the title when known.
class DiffPanel extends StatelessWidget {
  const DiffPanel({
    required this.title,
    required this.spans,
    required this.tokenCount,
    super.key,
  });
  final String title;
  final List<InlineSpan> spans;
  final int? tokenCount;

  @override
  Widget build(BuildContext context) {
    final tokenText = tokenCount != null ? ' ($tokenCount Tokens)' : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Text(
          '$title$tokenText',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: SelectionArea(child: Text.rich(TextSpan(children: spans))),
        ),
      ],
    );
  }
}
