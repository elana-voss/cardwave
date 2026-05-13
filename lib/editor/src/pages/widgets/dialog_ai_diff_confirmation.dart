import 'dart:async';

import 'package:cardwave/common/common.dart';
import 'package:cardwave/editor/src/pages/widgets/diff_panel.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:diff_match_patch/diff_match_patch.dart';
import 'package:flutter/material.dart';

class DialogAiDiffConfirmation extends StatefulWidget {
  const DialogAiDiffConfirmation({
    required this.originalText,
    required this.suggestedText,
    super.key,
  });
  final String originalText;
  final String suggestedText;

  @override
  State<DialogAiDiffConfirmation> createState() =>
      _DialogAiDiffConfirmationState();
}

class _DialogAiDiffConfirmationState extends State<DialogAiDiffConfirmation> {
  int? _originalTokens;
  int? _suggestedTokens;

  @override
  void initState() {
    super.initState();
    unawaited(_loadTokens());
  }

  Future<void> _loadTokens() async {
    final original = await UtilsLlm.countTokens(widget.originalText);
    final suggested = await UtilsLlm.countTokens(widget.suggestedText);
    if (!mounted) return;
    setState(() {
      _originalTokens = original;
      _suggestedTokens = suggested;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dmp = DiffMatchPatch();
    final diffs = dmp.diff(widget.originalText, widget.suggestedText);
    dmp.diffCleanupSemantic(diffs);

    final originalSpans = _buildDiffSpans(context, diffs, showDeletions: true);
    final suggestedSpans = _buildDiffSpans(
      context,
      diffs,
      showInsertions: true,
    );

    return AppDialog(
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Apply Changes'),
        ),
      ],
      builder: (context, isMobile) {
        final originalWidget = DiffPanel(
          title: 'Original Text',
          spans: originalSpans,
          tokenCount: _originalTokens,
        );
        final suggestedWidget = DiffPanel(
          title: 'Suggested Text',
          spans: suggestedSpans,
          tokenCount: _suggestedTokens,
        );

        if (isMobile) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              originalWidget,
              const SizedBox(height: 16),
              suggestedWidget,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: originalWidget),
            const SizedBox(width: 16),
            Expanded(child: suggestedWidget),
          ],
        );
      },
    );
  }

  List<InlineSpan> _buildDiffSpans(
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
      backgroundColor: theme.colorScheme.primaryContainer.withValues(
        alpha: 0.3,
      ),
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

}
