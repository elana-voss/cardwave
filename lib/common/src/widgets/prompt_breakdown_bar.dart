import 'package:cardwave/common/src/models/prompt_breakdown.dart';
import 'package:cardwave/common/src/models/prompt_segment_kind_enum.dart';
import 'package:cardwave/common/src/utils/navigation_service.dart';
import 'package:flutter/material.dart';

/// Thin segmented bar shown under an AI reply. Full width is the model's
/// context window; coloured segments are the prompt's parts sized by token
/// share; the muted tail is still-free context. Hover reveals a labelled
/// legend; tap opens the detail dialog. The bar itself carries no labels so
/// it stays unobtrusive inside the message bubble.
class PromptBreakdownBar extends StatelessWidget {
  const PromptBreakdownBar({required this.breakdown, super.key});
  final PromptContextBreakdown breakdown;

  static const double _barHeight = 8;

  /// Stable per-part colour: the active theme's primary hue rotated around the
  /// wheel by the part's position, so neon and default themes both look right.
  static Color segmentColor(BuildContext context, PromptSegmentKindEnum kind) {
    final base = HSLColor.fromColor(Theme.of(context).colorScheme.primary);
    // Golden-angle hue stepping puts neighbouring parts far apart on the wheel
    // instead of one small step apart, and the lightness alternates so any two
    // parts that still land on a near hue stay distinct.
    final hue = (base.hue + kind.index * 137.508) % 360;
    final lightness = kind.index.isEven ? 0.62 : 0.48;
    return HSLColor.fromAHSL(1, hue, 0.66, lightness).toColor();
  }

  static Color freeColor(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.22);

  static Color _rowColor(BuildContext context, PromptBreakdownRow row) =>
      row.kind == null
      ? freeColor(context)
      : segmentColor(context, row.kind!);

  @override
  Widget build(BuildContext context) {
    final blocks = <Widget>[
      for (final row in breakdown.displayRows)
        if (row.tokens > 0)
          Expanded(
            flex: row.tokens,
            child: ColoredBox(color: _rowColor(context, row)),
          ),
    ];
    if (blocks.isEmpty) return const SizedBox.shrink();

    return Tooltip(
      richMessage: _legend(context),
      waitDuration: const Duration(milliseconds: 300),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () =>
              NavigationService().showPromptBreakdownDialog(breakdown: breakdown),
          child: Container(
            height: _barHeight,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(Radius.circular(4)),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: blocks,
            ),
          ),
        ),
      ),
    );
  }

  TextSpan _legend(BuildContext context) {
    final lines = <TextSpan>[
      for (final row in breakdown.displayRows)
        TextSpan(
          children: [
            TextSpan(
              text: '■ ',
              style: TextStyle(color: _rowColor(context, row)),
            ),
            TextSpan(text: '${row.label}: ${row.tokens}\n'),
          ],
        ),
    ];
    final realNote = breakdown.realInputTokens == null ? ' (estimated)' : '';
    lines.add(
      TextSpan(
        text:
            '${breakdown.usedTokens} / ${breakdown.contextSize} used$realNote',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
    return TextSpan(children: lines);
  }
}
