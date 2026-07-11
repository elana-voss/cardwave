import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:flutter/material.dart';

/// Visual state of a single grid cell.
///
/// Pairs hue with type weight so users with reduced colour perception
/// still parse the signal.
enum MediaSettingsGridCellState {
  /// Resolver picks this layer's value — bold + primary.
  winning,

  /// This layer has a value, but a higher layer overrides it — normal
  /// weight, normal foreground.
  overridden,

  /// This layer has no own value; the displayed string is the inherited
  /// resolved value — italic + dimmed.
  inheriting,

  /// Field doesn't exist at this layer — placeholder, not tappable.
  notApplicable,
}

/// One cell in the layer grid. Renders a single string in one of four
/// visual states. Tap dispatch is the caller's responsibility — the cell
/// just calls [onTap] when one is provided. The cell's own [BuildContext]
/// is forwarded to [onTap] so callers that pop a menu can anchor it to
/// the cell via [BuildContext.findRenderObject].
class MediaSettingsGridCell extends StatelessWidget {
  const MediaSettingsGridCell({
    required this.text,
    required this.state,
    required this.onTap,
    super.key,
  });

  final String text;
  final MediaSettingsGridCellState state;
  final ValueChanged<BuildContext>? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final TextStyle style;
    switch (state) {
      case MediaSettingsGridCellState.winning:
        style = TextStyle(
          fontWeight: FontWeight.bold,
          color: cs.primary,
        );
      case MediaSettingsGridCellState.overridden:
        style = TextStyle(color: cs.onSurface);
      case MediaSettingsGridCellState.inheriting:
        style = TextStyle(
          color: cs.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        );
      case MediaSettingsGridCellState.notApplicable:
        style = TextStyle(color: cs.onSurface.withValues(alpha: 0.38));
    }

    final body = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Text(
        text,
        style: style,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        semanticsLabel: state == MediaSettingsGridCellState.notApplicable
            ? t.llmApp.mediaCell.notApplicable
            : null,
      ),
    );

    final tap = onTap;
    if (tap == null) return body;
    return InkWell(onTap: () => tap(context), child: body);
  }
}
