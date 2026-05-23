import 'package:flutter/material.dart';

/// Surface card used across drawers, dialogs, and editor panels. Owns
/// visual chrome only (rounded corners, surface color); spacing — both
/// outer margin from the parent edge AND gap between sibling cards — is
/// the parent's responsibility.
class AppCard extends StatelessWidget {
  const AppCard({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
      child: child,
    );
  }
}
