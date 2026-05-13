import 'dart:async';

import 'package:cardwave/common/common.dart';
import 'package:cardwave/settings/settings.dart';
import 'package:flutter/material.dart';

class ChatThemeTile extends StatelessWidget {
  const ChatThemeTile({
    required this.settings,
    required this.onThemeChanged,
    super.key,
  });
  final AppSettings settings;
  final ValueChanged<ChatTheme> onThemeChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.palette),
      title: const Text('Theme'),
      trailing: DrawerTrailingValue(settings.chatTheme.name),
      onTap: () {
        unawaited(
          showModalBottomSheet<void>(
            context: context,
            useRootNavigator: true,
            builder: (sheetContext) => SizedBox(
              width: double.infinity,
              child: ListView(
                shrinkWrap: true,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'Theme',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  for (final theme in ChatTheme.presets)
                    ListTile(
                      title: Text(theme.name),
                      selected: theme == settings.chatTheme,
                      onTap: () {
                        onThemeChanged(theme);
                        Navigator.pop(sheetContext);
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
