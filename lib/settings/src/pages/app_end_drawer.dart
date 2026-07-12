import 'dart:async';

import 'package:cardwave/common/common.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:cardwave/settings/src/services/settings_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AppEndDrawer extends StatelessWidget {
  const AppEndDrawer({
    super.key,
    this.chatSpecificMenuBuilder,
    this.chatSpecificRoutes,
    this.chatSpecificActions,
  });
  final Widget Function(BuildContext)? chatSpecificMenuBuilder;
  final Map<String, WidgetBuilder>? chatSpecificRoutes;

  /// Action widgets prepended to the drawer's title-row `AppBar.actions`,
  /// before the close icon. Used by the chat workspace to surface the
  /// "Configure all" + "Show all" toggles in a stable spot. `null` (the
  /// default) keeps the title row at "Menu" + close.
  final List<Widget>? chatSpecificActions;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: (MediaQuery.sizeOf(context).width * 0.90).clamp(0.0, 500.0),
      child: Navigator(
        initialRoute: '/',
        onGenerateRoute: (routeSettings) {
          return MaterialPageRoute<void>(
            settings: routeSettings,
            builder: (navContext) {
              if (chatSpecificRoutes != null &&
                  chatSpecificRoutes!.containsKey(routeSettings.name)) {
                return chatSpecificRoutes![routeSettings.name]!(navContext);
              }

              switch (routeSettings.name) {
                case '/':
                default:
                  return _MainDrawerList(
                    chatSpecificMenuBuilder: chatSpecificMenuBuilder,
                    chatSpecificActions: chatSpecificActions,
                  );
              }
            },
          );
        },
      ),
    );
  }
}

class _MainDrawerList extends StatelessWidget {
  const _MainDrawerList({
    required this.chatSpecificMenuBuilder,
    required this.chatSpecificActions,
  });
  final Widget Function(BuildContext)? chatSpecificMenuBuilder;
  final List<Widget>? chatSpecificActions;

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final settingsService = context.watch<SettingsService>();
    final settings = settingsService.settings;
    final activePersona = settings.activePersona;
    return Scaffold(
      backgroundColor: Theme.of(context).drawerTheme.backgroundColor,
      appBar: AppBar(
        elevation: 1,
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: TextButton.icon(
          key: const Key('drawer-persona-button'),
          onPressed: () {
            Navigator.of(context, rootNavigator: true).pop();
            unawaited(NavigationService().showPersonasDialog());
          },
          icon: const Icon(Icons.person),
          label: Text(
            activePersona.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        titleSpacing: 8,
        automaticallyImplyLeading: false,
        actions: [
          if (settings.personas.length > 1)
            PopupMenuButton<String>(
              icon: const Icon(Icons.swap_vert),
              tooltip: t.settings.endDrawer.switchPersonaTooltip,
              onSelected: (id) {
                settings.defaultPersonaId = id;
                unawaited(settingsService.saveSettings());
              },
              itemBuilder: (_) => [
                for (final persona in settings.personas)
                  PopupMenuItem(
                    value: persona.id,
                    child: Text(
                      persona.name,
                      style: persona.id == activePersona.id
                          ? const TextStyle(fontWeight: FontWeight.bold)
                          : null,
                    ),
                  ),
              ],
            ),
          ...?chatSpecificActions,
          IconButton(
            icon: Transform.flip(
              flipX: true,
              child: const Icon(Icons.menu_open),
            ),
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
          ),
        ],
        actionsPadding: const EdgeInsets.only(right: 16),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          if (chatSpecificMenuBuilder != null)
            chatSpecificMenuBuilder!(context),
        ],
      ),
    );
  }
}

