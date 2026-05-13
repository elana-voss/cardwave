import 'package:cardwave/character/character.dart';
import 'package:cardwave/chat/chat.dart';
import 'package:cardwave/workspace/src/controllers/workspace_controller.dart';
import 'package:cardwave/workspace/src/pages/workspace_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class WorkspaceSwitchCharacter {
  static Future<void> switchCharacterInWorkspace(
    BuildContext context, {
    required CharacterFile currentCharacterFile,
  }) async {
    final selectedFile = await DialogCharacterSwitcher.show(
      context,
      currentCharacterFile: currentCharacterFile,
    );

    if (selectedFile == null || selectedFile == currentCharacterFile) return;
    if (!context.mounted) return;

    final currentBase = context.read<WorkspaceController>().base;
    await context
        .read<CharacterService>()
        .flushJsonInCacheAndPngIfDirtyOrPending(currentCharacterFile);
    if (!context.mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => WorkspacePage(
          characterFile: selectedFile,
          initialBase: currentBase,
        ),
      ),
    );
  }
}
