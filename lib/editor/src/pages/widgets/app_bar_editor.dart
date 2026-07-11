import 'dart:async';

import 'package:cardwave/character/character.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/editor/src/controllers/editor_page_controller.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:cardwave/settings/settings.dart';
import 'package:cardwave/workspace/workspace.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AppBarEditor extends StatelessWidget implements PreferredSizeWidget {
  const AppBarEditor({
    required this.characterFile,
    required this.isSmallScreen,
    required this.onTitleTap,
    super.key,
  });
  final CharacterFile characterFile;
  final bool isSmallScreen;
  final VoidCallback onTitleTap;

  @override
  Widget build(BuildContext context) {
    final workspace = context.watch<WorkspaceController>();
    final isSidePanelOn = workspace.editorSidePanel && !isSmallScreen;

    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.grid_view_rounded),
        onPressed: () => Navigator.pop(context),
      ),
      title: AppBarSwitcherTitle(
        displayName: characterFile.card.displayName,
        onTap: onTitleTap,
      ),
      actions: [
        WorkspaceBaseToggle(
          base: workspace.base,
          compact: isSmallScreen,
          onBaseChanged: (newBase) {
            unawaited(context.read<EditorPageController>().flushChanges());
            workspace.setBase(newBase);
          },
        ),
        if (!isSmallScreen)
          IconButton(
            icon: RotatedBox(
              quarterTurns: 1,
              child: Icon(
                isSidePanelOn ? Icons.crop_square : Icons.splitscreen,
              ),
            ),
            tooltip: isSidePanelOn
                ? t.editor.appBarEditor.hideAssistantPanelTooltip
                : t.editor.appBarEditor.showChatAssistantTooltip,
            onPressed: workspace.toggleEditorSidePanel,
          ),
        const SizedBox(width: 16),
        SettingsGearMenu(character: characterFile),
        Builder(
          builder: (context) => IconButton(
            key: const Key('appbar-end-drawer'),
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openEndDrawer(),
          ),
        ),
      ],
      actionsPadding: const EdgeInsets.only(right: 16),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
