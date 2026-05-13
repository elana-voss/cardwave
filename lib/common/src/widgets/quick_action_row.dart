import 'package:cardwave/common/src/theme/compact_theme.dart';
import 'package:flutter/material.dart';

/// Single entry in a [QuickActionRow]. Pass [selectedIcon] when the action
/// has a stateful selected look (e.g. filled vs. outline star); leave it
/// null for stateless tiles. [tileKey] attaches a key to the rendered tile
/// for `find.byKey` test lookups.
class QuickAction {
  const QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.tileKey,
    this.selectedIcon,
    this.isSelected = false,
  });

  final Key? tileKey;
  final IconData icon;
  final IconData? selectedIcon;
  final String label;
  final VoidCallback? onTap;
  final bool isSelected;
}

/// Minimal icon-above-label action row used at the top of the chat drawer.
/// Bare InkWells, evenly spaced — relies on a Material ancestor (Scaffold
/// body, AppCard) for the tap ripple.
class QuickActionRow extends StatelessWidget {
  const QuickActionRow({required this.actions, super.key});

  final List<QuickAction> actions;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final action in actions)
          _Tile(key: action.tileKey, action: action),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.action, super.key});

  final QuickAction action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = action.isSelected;
    final icon = (selected && action.selectedIcon != null)
        ? action.selectedIcon!
        : action.icon;
    final disabled = action.onTap == null;
    final iconColor = disabled
        ? theme.colorScheme.onSurface.withValues(alpha: kDisabledAlpha)
        : theme.colorScheme.onSurface.withValues(alpha: 0.70);
    final labelColor = disabled
        ? theme.colorScheme.onSurface.withValues(alpha: kDisabledAlpha)
        : theme.colorScheme.onSurface.withValues(alpha: 0.54);
    return Expanded(
      child: InkWell(
        onTap: action.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(height: 4),
              Text(
                action.label,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: labelColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
