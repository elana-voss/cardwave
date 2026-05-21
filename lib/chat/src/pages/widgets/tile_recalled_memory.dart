import 'dart:async';

import 'package:cardwave/common/common.dart';
import 'package:cardwave/settings/settings.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// App-wide drawer toggle for showing, beneath each AI reply, the story-memory
/// lines that informed it. Hidden while story memory is off — there is nothing
/// to reveal then. The setting itself is off by default, so basic users never
/// see the footnotes.
class TileRecalledMemory extends StatelessWidget {
  const TileRecalledMemory({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<SettingsService>();
    if (!svc.settings.memoryEnabled) return const SizedBox.shrink();
    return DrawerSwitchTile(
      title: const Text('Show Recalled Memory'),
      value: svc.settings.showRecalledMemory,
      leading: const Icon(Icons.history_edu),
      onChanged: (value) {
        svc.settings.showRecalledMemory = value;
        unawaited(svc.saveSettings());
      },
    );
  }
}
