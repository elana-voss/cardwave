import 'package:flutter/material.dart';

/// AppBar title that doubles as the affordance for switching the
/// active conversation. Renders a leading `▾` icon next to the
/// display name; tapping anywhere on the row invokes [onTap].
///
/// Used by both 1:1 chat (character switcher) and group chat (group
/// switcher) so the two surfaces share one mental model: tap the
/// title to change the active thing.
class AppBarSwitcherTitle extends StatelessWidget {
  const AppBarSwitcherTitle({
    required this.displayName,
    required this.onTap,
    super.key,
  });
  final String displayName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.all(Radius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.arrow_drop_down),
            Flexible(
              child: Text(displayName, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}
