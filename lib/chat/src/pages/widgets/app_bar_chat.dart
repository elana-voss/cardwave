import 'package:cardwave/character/character.dart';
import 'package:cardwave/chat/src/controllers/chat_page_controller.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/settings/settings.dart';
import 'package:cardwave/workspace/workspace.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AppBarChat extends StatelessWidget implements PreferredSizeWidget {
  const AppBarChat({
    required this.characterFile,
    required this.isWideScreen,
    super.key,
  });
  final CharacterFile characterFile;
  final bool isWideScreen;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final workspace = context.watch<WorkspaceController>();

    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.grid_view_rounded),
        onPressed: () => Navigator.pop(context),
      ),
      title: AppBarSwitcherTitle(
        displayName: characterFile.card.displayName,
        onTap: () => WorkspaceSwitchCharacter.switchCharacterInWorkspace(
          context,
          currentCharacterFile: characterFile,
        ),
      ),
      actionsPadding: const EdgeInsets.only(right: 16),
      actions: [
        WorkspaceBaseToggle(
          base: workspace.base,
          compact: !isWideScreen,
          onBaseChanged: (newBase) =>
              context.read<WorkspaceController>().setBase(newBase),
        ),
        if (isWideScreen)
          IconButton(
            icon: RotatedBox(
              quarterTurns: 1,
              child: Icon(
                workspace.chatSidePanel ? Icons.crop_square : Icons.splitscreen,
              ),
            ),
            tooltip: workspace.chatSidePanel
                ? 'Hide editor panel'
                : 'Show editor side-by-side',
            onPressed: workspace.toggleChatSidePanel,
          ),
        const SizedBox(width: 16),
        SettingsGearMenu(
          character: characterFile,
          chatPageController: context.watch<ChatPageController>(),
        ),
        Builder(
          builder: (context) => IconButton(
            key: const Key('appbar-end-drawer'),
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openEndDrawer(),
          ),
        ),
      ],
    );
  }
}
