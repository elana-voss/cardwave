import 'package:cardwave/app_routes_enum.dart';
import 'package:cardwave/character/character.dart';
import 'package:cardwave/routing/app_router_args_chat_page.dart';
import 'package:cardwave/workspace/workspace.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class RouteCreateCharacter {
  // We pass the context to the execute method because
  // the context should be current to the widget triggering it.
  Future<void> execute(BuildContext context) async {
    final characterService = context.read<CharacterService>();
    final newCharFile = await CharacterCreateController.runInteractive(
      characterService,
    );

    if (newCharFile == null) return;

    if (context.mounted) {
      await Navigator.of(context).pushNamed(
        AppRoutesEnum.workspace.name,
        arguments: AppRouterArgsChatPage(newCharFile, WorkspaceBaseEnum.editor),
      );
    }
  }
}
