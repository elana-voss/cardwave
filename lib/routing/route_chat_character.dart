import 'package:cardwave/app_routes_enum.dart';
import 'package:cardwave/character/character.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/routing/app_router_args_chat_page.dart';
import 'package:flutter/material.dart';

class RouteChatCharacter {
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
          arguments: AppRouterArgsChatPage(file),
        );
      }
    } on Exception catch (e, st) {
      LoggingService().error(
        'Navigation error to chat for ${file.card.name}',
        e,
        st,
      );
      NavigationService().showSnackBar(
        'Navigation error to chat. Character: ${file.card.name}',
      );
    }
  }
}
