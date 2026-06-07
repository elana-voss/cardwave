import 'package:cardwave/common/src/models/prompt_breakdown.dart';
import 'package:cardwave/common/src/widgets/app_dialog.dart';
import 'package:cardwave/common/src/widgets/prompt_breakdown_bar.dart';
import 'package:flutter/material.dart';

/// Read-only detail view for a reply's prompt breakdown: every part with its
/// token count, the reply reservation, free space, and the totals. Opened by
/// tapping the breakdown bar under a message.
class DialogPromptBreakdown extends StatelessWidget {
  const DialogPromptBreakdown({required this.breakdown, super.key});
  final PromptContextBreakdown breakdown;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final realNote = breakdown.realInputTokens == null
        ? 'Prompt total (estimated)'
        : 'Prompt total (provider)';

    return AppDialog(
      builder: (context, isMobile) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          Text('Prompt Breakdown', style: theme.textTheme.titleLarge),
          PromptBreakdownBar(breakdown: breakdown),
          const SizedBox(height: 4),
          for (final row in breakdown.displayRows)
            _Row(
              swatch: row.kind == null
                  ? PromptBreakdownBar.freeColor(context)
                  : PromptBreakdownBar.segmentColor(context, row.kind!),
              label: row.label,
              tokens: row.tokens,
            ),
          const Divider(),
          _Row(label: realNote, tokens: breakdown.promptTokens, bold: true),
          _Row(
            label: 'Context window',
            tokens: breakdown.contextSize,
            bold: true,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.tokens, this.swatch, this.bold = false});
  final String label;
  final int tokens;
  final Color? swatch;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = bold
        ? Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          if (swatch != null) ...[
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: swatch,
                borderRadius: const BorderRadius.all(Radius.circular(2)),
              ),
            ),
            const SizedBox(width: 8),
          ] else
            const SizedBox(width: 20),
          Expanded(child: Text(label, style: style)),
          Text('$tokens', style: style),
        ],
      ),
    );
  }
}
