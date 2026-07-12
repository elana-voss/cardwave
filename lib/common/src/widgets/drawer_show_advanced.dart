import 'package:cardwave/common/src/theme/compact_theme.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:flutter/material.dart';

/// Per-section "More / Less" expander row. Sits at the bottom of a
/// section that has at least one advanced row; tapping toggles the
/// section's advanced rows visible/hidden. Mirrors Firefox's mobile
/// "More" tile — leading dots icon + plain title + tonal-pill chevron.
class DrawerShowAdvanced extends StatelessWidget {
  const DrawerShowAdvanced({
    required this.expanded,
    required this.onToggle,
    super.key,
  });
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final theme = Theme.of(context);
    return ListTile(
      onTap: onToggle,
      leading: const Icon(Icons.more_horiz),
      title: Text(expanded ? t.common.showAdvanced.less : t.common.showAdvanced.more),
      trailing: SizedBox(
        // Same 160 dp trailing column every row uses, so the chevron
        // anchors at the same right margin as the picker text/icons.
        width: 160,
        child: Align(
          alignment: Alignment.centerRight,
          child: Icon(
            expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
            size: 20,
            color: theme.colorScheme.onSurface.withValues(
              alpha: kDisabledAlpha,
            ),
          ),
        ),
      ),
    );
  }
}
