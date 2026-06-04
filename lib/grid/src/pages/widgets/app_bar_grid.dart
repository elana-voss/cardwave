import 'package:cardwave/app_routes_enum.dart';
import 'package:cardwave/character/character.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/routing/route_create_character.dart';
import 'package:cardwave/settings/settings.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AppBarGrid extends StatelessWidget implements PreferredSizeWidget {
  const AppBarGrid({super.key, this.actions});
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final service = context.watch<CharacterService>();
    final isNeon = context.select<ThemeNotifier, bool>(
      (t) => t.themeStyle == ThemeStyleEnum.neon,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideScreen =
            constraints.maxWidth >= AppConstants.tabletBreakpoint;

        final groupsButton = TextButton.icon(
          key: const Key('grid-groups-button'),
          icon: const Icon(Icons.group),
          label: const Text('Groups'),
          onPressed: () => Navigator.of(
            context,
          ).pushReplacementNamed(AppRoutesEnum.groupGrid.name),
        );

        return AppBar(
          toolbarHeight: kToolbarHeight,
          titleSpacing: 20,
          automaticallyImplyLeading: false,
          title: isWideScreen
              ? Row(
                  spacing: 8,
                  children: [
                    if (isNeon)
                      const GradientText(
                        'Cardwave',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                    FilledButton.icon(
                      key: const Key('grid-create-new-button'),
                      onPressed: () => RouteCreateCharacter().execute(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Create New'),
                    ),
                    FilledButton.tonalIcon(
                      key: const Key('grid-import-button'),
                      onPressed: () =>
                          CharacterImportController.runBulkImport(service),
                      icon: const Icon(Icons.upload),
                      label: const Text('Import'),
                    ),
                  ],
                )
              : groupsButton,
          actions: [
            if (isWideScreen) groupsButton,
            ...?actions,
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
