import 'package:flutter/material.dart';

/// Compact boolean-indicator row for the chat drawer. Renders as a
/// tappable [ListTile] with a check-filled or hollow circle in the
/// trailing slot — the row itself carries the toggle behavior via
/// [ListTile.onTap]. Pair with the drawer's `ListTileTheme` for
/// `dense: true` etc.
class DrawerSwitchTile extends StatelessWidget {
  const DrawerSwitchTile({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.leading,
    super.key,
  });

  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final cb = onChanged;
    return ListTile(
      leading: leading,
      title: title,
      subtitle: subtitle,
      trailing: SizedBox(
        width: 160,
        child: Align(
          alignment: Alignment.centerRight,
          child: Transform.scale(
            scale: 0.7,
            // Pivots the scale around the child's right edge so the painted
            // Switch ends flush with the layout box's right edge — keeps the
            // toggle in the same vertical line as adjacent text/icon trailings.
            alignment: Alignment.centerRight,
            child: Switch(
              value: value,
              onChanged: cb,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
      ),
      enabled: cb != null,
      onTap: cb == null ? null : () => cb(!value),
    );
  }
}
