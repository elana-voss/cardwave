import 'package:flutter/material.dart';

/// M3 surface-tinted section caption used by the dense settings/media
/// pages — `surfaceContainerHighest` band with bold title, optional
/// subtitle on a second line, optional trailing action widget (e.g. an
/// edit button row). Pairs with the dense-row pattern: no card chrome,
/// hairline dividers between rows.
///
/// Padding tightens when [trailing] is present so the action buttons
/// don't push the band thicker than the text-only variant.
class SectionHeaderBand extends StatelessWidget {
  const SectionHeaderBand({
    required this.title,
    super.key,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasSubtitle = subtitle != null && subtitle!.isNotEmpty;
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: trailing != null
            ? const EdgeInsets.fromLTRB(16, 6, 8, 6)
            : const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (hasSubtitle)
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}
