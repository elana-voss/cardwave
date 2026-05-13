import 'package:cardwave/app_routes_enum.dart';
import 'package:cardwave/group/src/controllers/group_chat_controller.dart';
import 'package:cardwave/group/src/models/group_file.dart';
import 'package:cardwave/group/src/pages/widgets/dialog_select_group.dart';
import 'package:cardwave/group/src/services/group_chat_service.dart';
import 'package:cardwave/group/src/services/group_file_service.dart';
import 'package:cardwave/routing/app_router_args_group_chat.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Opens the group picker and, if the user picks a different group,
/// replaces the current group-chat route with one for the chosen group.
///
/// Captures the navigator and the two group services from [context]
/// up-front so the call survives the dialog route lifecycle. Mirrors
/// the shape of [DialogGroupOverrides.show].
class GroupSwitchDialog {
  const GroupSwitchDialog._();

  static Future<void> show(BuildContext context) async {
    final navigator = Navigator.of(context);
    final groupFileService = context.read<GroupFileService>();
    final groupChatService = context.read<GroupChatService>();
    final currentGroupId = context.read<GroupChatController>().groupFile.id;

    final selected = await showDialog<GroupFile>(
      context: navigator.context,
      builder: (_) => MultiProvider(
        providers: [
          ChangeNotifierProvider<GroupFileService>.value(
            value: groupFileService,
          ),
          ChangeNotifierProvider<GroupChatService>.value(
            value: groupChatService,
          ),
        ],
        child: const DialogSelectGroup(),
      ),
    );
    if (selected == null) return;
    if (selected.id == currentGroupId) return;
    await navigator.pushReplacementNamed(
      AppRoutesEnum.groupChat.name,
      arguments: AppRouterArgsGroupChat(selected.id),
    );
  }
}
