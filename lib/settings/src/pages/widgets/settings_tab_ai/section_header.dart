import 'package:flutter/material.dart';

/// Plain M3 section header for the AI Providers tab — bold `titleMedium`
/// title on the natural surface (no fill), optional subtitle below, and
/// optional trailing widget on the title row (e.g. an overflow `⋮`).
/// Closes with a hairline divider so the title block reads as a unit.
/// Per-section action buttons live on a separate row beneath the header
/// — this widget is intentionally title-only so the actions row can
/// carry its own divider underneath without nesting concerns.
class AiTabSectionHeader extends StatelessWidget {
  const AiTabSectionHeader({
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
    final muted = theme.colorScheme.onSurfaceVariant;
    final hasSubtitle = subtitle != null && subtitle!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Thick top divider is the section break. Sits above every title
        // (dashboard and each provider) so the eye lands on a hard line
        // before the title, then flows into actions/rows without another
        // divider interrupting the title-to-actions handoff.
        Divider(
          height: 2,
          thickness: 2,
          color: theme.colorScheme.outlineVariant,
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 12, trailing != null ? 4 : 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.clip,
                    ),
                    if (hasSubtitle)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: muted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ],
    );
  }
}
