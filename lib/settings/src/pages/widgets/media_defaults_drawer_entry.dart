import 'package:cardwave/common/common.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:cardwave/settings/src/pages/dialog_ai_settings.dart';
import 'package:flutter/material.dart';

/// "Configuration" section header + Media Defaults `ListTile` pair used
/// at the top of every drawer that surfaces the AI/media settings
/// dialog. The widget owns the chrome (icon, title, section header)
/// and reads its label from [DialogAiSettingsTab.mediaDefaults] so a
/// rename touches one place. The caller supplies the [subtitle] (scope
/// hint: 'Chat session' / 'Character' / 'App') and an [onTap] that
/// pops the drawer + opens `DialogAiSettings.show` with the right
/// `mediaFocus` and scope params. Pass `null` [onTap] to render
/// disabled (e.g. chat-drawer when no session is selected).
class MediaDefaultsDrawerEntry extends StatelessWidget {
  const MediaDefaultsDrawerEntry({
    required this.subtitle,
    required this.onTap,
    super.key,
  });

  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DrawerSectionHeader(t.settings.mediaDefaultsDrawerEntry.configurationHeader),
        ListTile(
          leading: Icon(DialogAiSettingsTab.mediaDefaults.icon),
          title: Text(DialogAiSettingsTab.mediaDefaults.label),
          subtitle: Text(subtitle),
          enabled: onTap != null,
          onTap: onTap,
        ),
      ],
    );
  }
}
