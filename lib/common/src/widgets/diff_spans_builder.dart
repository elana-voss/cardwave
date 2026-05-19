import 'package:diff_match_patch/diff_match_patch.dart';
import 'package:flutter/material.dart';

/// Renders a `diff_match_patch` diff as colored inline spans. Insertions are
/// tinted with the primary color; deletions are struck-through with the
/// error color. `showInsertions` and `showDeletions` let callers render a
/// "before" panel (deletions only) and an "after" panel (insertions only)
/// from the same diff result.
List<InlineSpan> buildDiffSpans(
  BuildContext context,
  List<Diff> diffs, {
  bool showInsertions = false,
  bool showDeletions = false,
}) {
  final spans = <InlineSpan>[];
  final theme = Theme.of(context);

  final deletionStyle = TextStyle(
    color: theme.colorScheme.error,
    backgroundColor: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
    decoration: TextDecoration.lineThrough,
  );
  final insertionStyle = TextStyle(
    color: theme.colorScheme.primary,
    backgroundColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
  );

  for (final diff in diffs) {
    switch (diff.operation) {
      case DIFF_INSERT:
        if (showInsertions) {
          spans.add(TextSpan(text: diff.text, style: insertionStyle));
        }
      case DIFF_DELETE:
        if (showDeletions) {
          spans.add(TextSpan(text: diff.text, style: deletionStyle));
        }
      case DIFF_EQUAL:
        spans.add(TextSpan(text: diff.text));
    }
  }
  return spans;
}
