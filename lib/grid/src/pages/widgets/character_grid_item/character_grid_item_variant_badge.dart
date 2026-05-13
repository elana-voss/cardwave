import 'package:flutter/material.dart';

class CharacterGridItemVariantBadge extends StatelessWidget {
  const CharacterGridItemVariantBadge({
    required this.count,
    super.key,
    this.onTap,
  });
  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '$count Variants',
      child: Material(
        color: Theme.of(context).colorScheme.primary,
        shape: const StadiumBorder(),
        elevation: 4,
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.style,
                  size: 16,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
                const SizedBox(width: 4),
                Text(
                  '$count',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
