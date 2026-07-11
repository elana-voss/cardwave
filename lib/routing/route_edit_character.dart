import 'package:cardwave/app_routes_enum.dart';
import 'package:cardwave/character/character.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/i18n/gen/translations.g.dart';
import 'package:cardwave/routing/app_router_args_chat_page.dart';
import 'package:cardwave/workspace/workspace.dart';
import 'package:flutter/material.dart';

class RouteEditCharacter {
  // We pass the context to the execute method because
  // the context should be current to the widget triggering it.
  Future<void> execute(BuildContext context, CharacterFile file) async {
    try {
      if (context.mounted) {
        final navigator = Navigator.of(context, rootNavigator: true);
        final currentRoute = ModalRoute.of(context);

        if (currentRoute is PopupRoute) {
          navigator.pop();
        }

        await navigator.pushNamed(
          AppRoutesEnum.workspace.name,
          arguments: AppRouterArgsChatPage(file, WorkspaceBaseEnum.editor),
        );
      }
    } on Exception catch (e, st) {
      LoggingService().error(
        'Navigation error to edit for ${file.card.name}',
        e,
        st,
      );
      NavigationService().showSnackBar(
        t.routing.editCharacter.navigationError(name: file.card.name),
      );
    }
  }
}
