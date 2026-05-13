import 'package:cardwave/app_routes_enum.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/settings/settings.dart';
import 'package:flutter/material.dart';

class AppBarGroupGrid extends StatelessWidget implements PreferredSizeWidget {
  const AppBarGroupGrid({required this.onCreateGroup, super.key});
  final VoidCallback onCreateGroup;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideScreen =
            constraints.maxWidth >= AppConstants.tabletBreakpoint;

        final charactersButton = TextButton.icon(
          icon: const Icon(Icons.person),
          label: const Text('Characters'),
          onPressed: () => Navigator.of(
            context,
          ).pushReplacementNamed(AppRoutesEnum.home.name),
        );

        return AppBar(
          toolbarHeight: kToolbarHeight,
          titleSpacing: 20,
          automaticallyImplyLeading: false,
          title: isWideScreen
              ? FilledButton.icon(
                  key: const Key('group-new-button'),
                  onPressed: onCreateGroup,
                  icon: const Icon(Icons.add),
                  label: const Text('New group'),
                )
              : charactersButton,
          actions: [
            if (isWideScreen) charactersButton,
            const SettingsGearMenu(),
            Builder(
              builder: (context) => IconButton(
                key: const Key('appbar-end-drawer'),
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(context).openEndDrawer(),
                tooltip: 'Menu',
              ),
            ),
          ],
          actionsPadding: const EdgeInsets.only(right: 16),
        );
      },
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
