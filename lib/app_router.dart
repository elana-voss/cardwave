import 'package:cardwave/app_routes_enum.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/grid/grid.dart';
import 'package:cardwave/group/group.dart';
import 'package:cardwave/onboarding/onboarding.dart';
import 'package:cardwave/routing/app_router_args_chat_page.dart';
import 'package:cardwave/routing/app_router_args_group_chat.dart';
import 'package:cardwave/workspace/workspace.dart';
import 'package:flutter/material.dart';

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    if (settings.name == AppRoutesEnum.home.name) {
      return MaterialPageRoute(builder: (_) => const CharacterGridPage());
    }
    if (settings.name == AppRoutesEnum.onboarding.name) {
      return MaterialPageRoute(builder: (_) => const OnboardingPage());
    }
    if (settings.name == AppRoutesEnum.logging.name) {
      return MaterialPageRoute(builder: (_) => const CustomLogScreen());
    }
    if (settings.name == AppRoutesEnum.workspace.name) {
      final args = settings.arguments! as AppRouterArgsChatPage;
      return MaterialPageRoute(
        builder: (_) => WorkspacePage(
          characterFile: args.characterFile,
          initialBase: args.base,
        ),
      );
    }
    if (settings.name == AppRoutesEnum.groupChat.name) {
      final args = settings.arguments! as AppRouterArgsGroupChat;
      return MaterialPageRoute(
        builder: (_) => GroupChatPage(groupId: args.groupId),
      );
    }
    if (settings.name == AppRoutesEnum.groupGrid.name) {
      return MaterialPageRoute(builder: (_) => const GroupGridPage());
    }
    return MaterialPageRoute(builder: (_) => const CharacterGridPage());
  }
}
