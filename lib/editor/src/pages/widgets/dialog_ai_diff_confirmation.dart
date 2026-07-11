import 'dart:async';

import 'package:cardwave/common/common.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
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

    final originalSpans = buildDiffSpans(context, diffs, showDeletions: true);
    final suggestedSpans = buildDiffSpans(
      context,
      diffs,
      showInsertions: true,
    );

    return AppDialog(
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(t.editor.dialogAiDiffConfirmation.applyChangesButton),
        ),
      ],
      builder: (context, isMobile) {
        final originalWidget = DiffPanel(
          title: t.editor.dialogAiDiffConfirmation.originalTextTitle,
          spans: originalSpans,
          tokenCount: _originalTokens,
        );
        final suggestedWidget = DiffPanel(
          title: t.editor.dialogAiDiffConfirmation.suggestedTextTitle,
          spans: suggestedSpans,
          tokenCount: _suggestedTokens,
        );

        if (isMobile) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 16,
            children: [originalWidget, suggestedWidget],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 16,
          children: [
            Expanded(child: originalWidget),
            Expanded(child: suggestedWidget),
          ],
        );
      },
    );
  }

}
