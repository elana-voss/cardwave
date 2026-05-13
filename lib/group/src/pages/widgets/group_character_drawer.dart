import 'package:cardwave/group/src/pages/widgets/group_character_panel.dart';
import 'package:flutter/material.dart';

/// Wraps [GroupCharacterPanel] in a scaffold shell that visually mirrors
/// `AppEndDrawer`. Two modes:
///
/// - [embedded] `false` (default, narrow layout): hosted inside a [Drawer]
///   with the same clamped width and themed background as `AppEndDrawer`,
///   and a themed `AppBar` with a close button.
/// - [embedded] `true` (wide layout): no outer [Drawer], transparent
///   backgrounds so the blurred character image bleeds through, no close
///   button (the column is permanently visible).
class GroupCharacterDrawer extends StatelessWidget {
  const GroupCharacterDrawer({super.key, this.embedded = false});
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scaffold = Scaffold(
      backgroundColor: embedded
          ? Colors.transparent
          : theme.drawerTheme.backgroundColor,
      appBar: embedded
          ? null
          : AppBar(
              elevation: embedded ? 0 : 1,
              backgroundColor: embedded
                  ? Colors.transparent
                  : theme.colorScheme.surface,
              title: const Text('Characters'),
              automaticallyImplyLeading: false,
              actions: embedded
                  ? null
                  : [
                      IconButton(
                        icon: Transform.flip(
                          flipX: true,
                          child: const Icon(Icons.menu_open),
                        ),
                        tooltip: 'Close',
                        onPressed: () =>
                            Navigator.of(context, rootNavigator: true).pop(),
                      ),
                    ],
              actionsPadding: const EdgeInsets.only(right: 16),
            ),
      body: const GroupCharacterPanel(),
    );

    if (embedded) return scaffold;

    return Drawer(
      width: (MediaQuery.sizeOf(context).width * 0.90).clamp(0.0, 500.0),
      child: scaffold,
    );
  }
}
