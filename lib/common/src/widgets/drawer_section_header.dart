import 'package:cardwave/common/src/theme/compact_theme.dart';
import 'package:flutter/material.dart';

/// M3-style section caption above a group of drawer rows. Bundles a
/// hairline divider with an ALL-CAPS, muted, letter-spaced label —
/// closes the previous section visually and reads as a category, not
/// a tappable row.
class DrawerSectionHeader extends StatelessWidget {
  const DrawerSectionHeader(this.title, {super.key});
  final String title;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: kDisabledAlpha);
    // crossAxisAlignment: start is required — Column defaults to `center`,
    // which centers the Padding (sized to its Text child, not full-width)
    // and pushes the section title to the middle of the drawer.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1, thickness: 0.5),
        Padding(
          padding: const EdgeInsets.only(left: 8, top: 12, bottom: 4),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: muted,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}
