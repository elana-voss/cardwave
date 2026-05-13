import 'package:flutter/material.dart';

/// Trailing value text for picker rows in the chat drawer. Single-line,
/// muted, ellipsized, and width-capped so a long value never pushes the
/// title off-screen. Pair with a [ListTile] whose `trailing:` slot accepts
/// this widget.
class DrawerTrailingValue extends StatelessWidget {
  const DrawerTrailingValue(this.value, {super.key, this.suffix});

  final String value;

  /// Optional widget rendered after the value text — typically an
  /// `InkWell` wrapping a small `Icon` (an `IconButton`'s 48 dp tap target
  /// would balloon the dense row). Sized externally; this widget does not
  /// constrain it.
  final Widget? suffix;

  /// Fixed trailing width shared with the toggle / chevron rows so all
  /// right-side content anchors to a single vertical line. Long values
  /// ellipsize within this width.
  static const double _trailingWidth = 160;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return SizedBox(
      width: _trailingWidth,
      child: Align(
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
              ),
            ),
            if (suffix != null) ...[const SizedBox(width: 4), suffix!],
          ],
        ),
      ),
    );
  }
}
