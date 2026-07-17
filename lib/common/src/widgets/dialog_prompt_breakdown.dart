import 'package:cardwave/common/src/models/prompt_breakdown.dart';
import 'package:cardwave/common/src/widgets/app_dialog.dart';
import 'package:cardwave/common/src/widgets/prompt_breakdown_bar.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:flutter/material.dart';

/// Read-only detail view for a reply's prompt breakdown, opened by tapping the
/// bar under the last reply. Two tabs: a summary listing every part with its
/// token count and share of the context window, and an inspect view exposing
/// the actual text each part contributed (transient — empty for replies loaded
/// from disk).
class DialogPromptBreakdown extends StatefulWidget {
  const DialogPromptBreakdown({required this.breakdown, super.key});
  final PromptContextBreakdown breakdown;

  @override
  State<DialogPromptBreakdown> createState() => _DialogPromptBreakdownState();
}

class _DialogPromptBreakdownState extends State<DialogPromptBreakdown>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    // Assigned in initState, which always runs before dispose — the field can
    // never be read uninitialised here.
    // ignore: qcheck/avoid_disposing_late_fields
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final breakdown = widget.breakdown;
    final theme = Theme.of(context);
    final rows = breakdown.displayRows;
    // Only the parts that contributed text get an inspect entry — the reply
    // reservation and free space have none.
    final inspectRows = [
      for (final row in rows)
        if (row.kind != null && row.text.trim().isNotEmpty) row,
    ];

    return AppDialog(
      builder: (context, isMobile) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          Text(
            t.common.promptBreakdownDialog.title,
            style: theme.textTheme.titleLarge,
          ),
          PromptBreakdownBar(breakdown: breakdown),
          TabBar(
            controller: _tabs,
            tabs: [
              Tab(text: t.common.promptBreakdownDialog.breakdownTab),
              Tab(text: t.common.promptBreakdownDialog.contentTab),
            ],
          ),
          // IndexedStack lays out both tabs and sizes to the taller one, so
          // switching tabs never changes the dialog height and neither tab can
          // collapse to zero. Both lists shrink-wrap; the taller one (usually
          // the content tab once expanded) drives the height.
          AnimatedBuilder(
            animation: _tabs,
            builder: (context, _) => IndexedStack(
              index: _tabs.index,
              sizing: StackFit.loose,
              children: [
                _SummaryTab(breakdown: breakdown, rows: rows),
                _ContentTab(breakdown: breakdown, rows: inspectRows),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Per-part token counts and their share of the context window, then the
/// prompt total and the window size.
class _SummaryTab extends StatelessWidget {
  const _SummaryTab({required this.breakdown, required this.rows});
  final PromptContextBreakdown breakdown;
  final List<PromptBreakdownRow> rows;

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final realNote = breakdown.realInputTokens == null
        ? t.common.promptBreakdownDialog.promptTotalEstimated
        : t.common.promptBreakdownDialog.promptTotalProvider;
    return ListView(
      shrinkWrap: true,
      children: [
        const _SummaryHeader(),
        const Divider(height: 8),
        for (final row in rows)
          _SummaryRow(
            swatch: row.kind == null
                ? PromptBreakdownBar.freeColor(context)
                : PromptBreakdownBar.segmentColor(context, row.kind!),
            label: row.label,
            tokens: row.tokens,
            percent: breakdown.percentOfWindow(row.tokens),
          ),
        const Divider(),
        _SummaryRow(
          label: realNote,
          tokens: breakdown.promptTokens,
          percent: breakdown.percentOfWindow(breakdown.promptTokens),
          bold: true,
        ),
        _SummaryRow(
          label: t.common.promptBreakdownDialog.contextWindowLabel,
          tokens: breakdown.contextSize,
          percent: 100,
          bold: true,
        ),
      ],
    );
  }
}

/// Column header for the summary list — category on the left, token count and
/// window-share columns on the right, aligned to the rows below.
class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader();

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      letterSpacing: 0.8,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          const SizedBox(width: 20),
          Expanded(
            child: Text(
              t.common.promptBreakdownDialog.categoryHeader,
              style: style,
            ),
          ),
          Text(t.common.promptBreakdownDialog.tokensHeader, style: style),
          SizedBox(
            width: 56,
            child: Text(
              t.common.promptBreakdownDialog.usageHeader,
              style: style,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.tokens,
    required this.percent,
    this.swatch,
    this.bold = false,
  });
  final String label;
  final int tokens;
  final double percent;
  final Color? swatch;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = bold
        ? Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)
        : Theme.of(context).textTheme.bodyMedium;
    final mutedStyle = style?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
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
          Text(_formatTokens(tokens), style: style),
          SizedBox(
            width: 56,
            child: Text(
              '${percent.toStringAsFixed(1)}%',
              style: mutedStyle,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

/// Expandable tiles, one per prompt part: the header carries the name, tokens,
/// and window share; expanding reveals the exact text that part contributed.
class _ContentTab extends StatelessWidget {
  const _ContentTab({required this.breakdown, required this.rows});
  final PromptContextBreakdown breakdown;
  final List<PromptBreakdownRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      final t = Translations.of(context);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Text(
          t.common.promptBreakdownDialog.noContentToInspect,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    final theme = Theme.of(context);
    return ListView(
      shrinkWrap: true,
      children: [
        for (final row in rows)
          Theme(
            // Drop the default divider lines ExpansionTile draws above/below.
            data: theme.copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 4),
              // `spacing: 8` is not equivalent here: it would also insert a gap
              // between the label and the token count, where there is none
              // today. Keeping the single SizedBox preserves the current layout.
              // ignore: qcheck/prefer_spacing
              title: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: PromptBreakdownBar.segmentColor(context, row.kind!),
                      borderRadius: const BorderRadius.all(Radius.circular(2)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(row.label, style: theme.textTheme.bodyMedium),
                  ),
                  Text(
                    '${_formatTokens(row.tokens)} · '
                    '${breakdown.percentOfWindow(row.tokens).toStringAsFixed(1)}%',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              childrenPadding: const EdgeInsets.only(
                left: 20,
                right: 4,
                bottom: 12,
              ),
              expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SelectableText(
                  row.text.trim(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Thousands-separated token count, matching the screenshot's "18.1k" style for
/// large numbers and plain integers below 1,000.
String _formatTokens(int tokens) {
  if (tokens < 1000) return '$tokens';
  final thousands = tokens / 1000;
  return '${thousands.toStringAsFixed(1)}k';
}
