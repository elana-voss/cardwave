import 'dart:async';

import 'package:cardwave/common/common.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:cardwave/settings/settings.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Drawer toggle for "require approval before applying an assistant-
/// proposed card edit of this modality". The three modalities (edit,
/// addition, deletion) only differ in title, icon, and which
/// `AppSettings` boolean they read/write — the modality enum carries that
/// split internally.
class TileAssistantCardEditRequireApproval extends StatelessWidget {
  const TileAssistantCardEditRequireApproval({
    required this.modality,
    super.key,
  });
  final CardEditModality modality;

  @override
  Widget build(BuildContext context) {
    Translations.of(context); // subscribe to locale changes; _title reads t
    final svc = context.watch<SettingsService>();
    return DrawerSwitchTile(
      title: Text(_title),
      value: _read(svc.settings),
      leading: Icon(_icon),
      onChanged: (v) {
        _write(svc.settings, value: v);
        unawaited(svc.saveSettings());
      },
    );
  }

  String get _title => switch (modality) {
        CardEditModality.edit =>
          t.character.requireApprovalTile.edits,
        CardEditModality.addition =>
          t.character.requireApprovalTile.additions,
        CardEditModality.deletion =>
          t.character.requireApprovalTile.deletions,
      };

  IconData get _icon => switch (modality) {
        CardEditModality.edit => Icons.edit_note,
        CardEditModality.addition => Icons.add_box_outlined,
        CardEditModality.deletion => Icons.delete_outline,
      };

  bool _read(AppSettings s) => switch (modality) {
        CardEditModality.edit =>
          s.assistantCardEditRequireApprovalForEdits,
        CardEditModality.addition =>
          s.assistantCardEditRequireApprovalForAdditions,
        CardEditModality.deletion =>
          s.assistantCardEditRequireApprovalForDeletions,
      };

  void _write(AppSettings s, {required bool value}) {
    switch (modality) {
      case CardEditModality.edit:
        s.assistantCardEditRequireApprovalForEdits = value;
      case CardEditModality.addition:
        s.assistantCardEditRequireApprovalForAdditions = value;
      case CardEditModality.deletion:
        s.assistantCardEditRequireApprovalForDeletions = value;
    }
  }
}
