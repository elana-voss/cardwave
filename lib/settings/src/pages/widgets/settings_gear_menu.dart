import 'dart:async';

import 'package:cardwave/character/character.dart';
import 'package:cardwave/chat/chat.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:cardwave/llm_app/llm_app.dart';
import 'package:cardwave/settings/settings.dart';
import 'package:flutter/material.dart';

enum _GearActionEnum {
  aiProviders,
  appSettings,
  language,
  mediaApp,
  mediaCharacter,
  mediaChat,
  logs,
}

/// Gear icon + popup menu giving app-wide access to AI Providers, App
/// Settings, Media Defaults (App/Character/Chat), and Logs. The three
/// Media entries always render so the menu shape stays constant across
/// appbars; the Character and Chat rows are disabled when their scope
/// isn't reachable from the current page (Character grid has no
/// character; editor has no chat). Logs sits below a divider because
/// it's a developer surface, not a user setting.
class SettingsGearMenu extends StatelessWidget {
  const SettingsGearMenu({
    super.key,
    this.character,
    this.chatPageController,
  });

  final CharacterFile? character;
  final ChatPageController? chatPageController;

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    return PopupMenuButton<_GearActionEnum>(
      key: const Key('settings-gear-menu'),
      icon: const Icon(Icons.settings),
      tooltip: t.settings.gearMenu.settingsTooltip,
      onSelected: (action) => _onSelected(context, action),
      itemBuilder: (_) {
        final session = chatPageController?.selectedChat;
        final charEnabled = character != null;
        final chatEnabled = chatPageController != null && session != null;
        return [
          PopupMenuItem(
            key: const Key('settings-ai-providers'),
            value: _GearActionEnum.aiProviders,
            child: ListTile(
              leading: Icon(DialogAiSettingsTab.aiProviders.icon),
              title: Text(DialogAiSettingsTab.aiProviders.label),
            ),
          ),
          PopupMenuItem(
            key: const Key('settings-media-defaults-app'),
            value: _GearActionEnum.mediaApp,
            child: ListTile(
              leading: Icon(DialogAiSettingsTab.mediaDefaults.icon),
              title: Text(DialogAiSettingsTab.mediaDefaults.label),
              subtitle: Text(
                t.settings.gearMenu.mediaDefaultsApp,
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ),
          ),
          PopupMenuItem(
            key: const Key('settings-media-defaults-character'),
            value: _GearActionEnum.mediaCharacter,
            enabled: charEnabled,
            child: ListTile(
              enabled: charEnabled,
              leading: Icon(DialogAiSettingsTab.mediaDefaults.icon),
              title: Text(DialogAiSettingsTab.mediaDefaults.label),
              subtitle: Text(
                t.settings.gearMenu.mediaDefaultsCharacter,
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ),
          ),
          PopupMenuItem(
            key: const Key('settings-media-defaults-chat'),
            value: _GearActionEnum.mediaChat,
            enabled: chatEnabled,
            child: ListTile(
              enabled: chatEnabled,
              leading: Icon(DialogAiSettingsTab.mediaDefaults.icon),
              title: Text(DialogAiSettingsTab.mediaDefaults.label),
              subtitle: Text(
                t.settings.gearMenu.mediaDefaultsChat,
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ),
          ),
          const PopupMenuDivider(),
          PopupMenuItem(
            key: const Key('settings-language'),
            value: _GearActionEnum.language,
            child: ListTile(
              leading: const Icon(Icons.language),
              title: Text(t.settings.gearLanguage),
            ),
          ),
          PopupMenuItem(
            key: const Key('settings-app-settings'),
            value: _GearActionEnum.appSettings,
            child: ListTile(
              leading: const Icon(Icons.settings),
              title: Text(t.settings.gearMenu.appSettings),
            ),
          ),
          const PopupMenuDivider(),
          PopupMenuItem(
            key: const Key('settings-logs'),
            value: _GearActionEnum.logs,
            child: ListTile(
              leading: const Icon(Icons.bug_report),
              title: Text(t.settings.gearMenu.logs),
            ),
          ),
        ];
      },
    );
  }

  void _onSelected(BuildContext context, _GearActionEnum action) {
    switch (action) {
      case _GearActionEnum.aiProviders:
        SettingsMenuController.openAiProvidersTab(context);
      case _GearActionEnum.appSettings:
        SettingsMenuController.openAppSettingsTab();
      case _GearActionEnum.language:
        unawaited(NavigationService().showLanguageDialog());
      case _GearActionEnum.mediaApp:
        SettingsMenuController.openMediaDefaults(context);
      case _GearActionEnum.mediaCharacter:
        SettingsMenuController.openMediaDefaults(
          context,
          mediaFocus: MediaSettingsGridFocus.appAndCharacter,
          character: character,
        );
      case _GearActionEnum.mediaChat:
        final controller = chatPageController!;
        SettingsMenuController.openMediaDefaults(
          context,
          mediaFocus: MediaSettingsGridFocus.allColumns,
          character: character,
          chatSession: controller.selectedChat,
          chatPageController: controller,
        );
      case _GearActionEnum.logs:
        SettingsMenuController.openLogsScreen(context);
    }
  }
}
