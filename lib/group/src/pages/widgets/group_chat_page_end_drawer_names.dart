part of '../group_chat_page.dart';

class _GroupNamesSection extends StatelessWidget {
  const _GroupNamesSection({required this.controller});
  final GroupChatController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DrawerSectionHeader(t.llmApp.mediaSection.names),
        _sessionSwitchTile(
          controller: controller,
          icon: Icons.badge,
          title: t.group.groupChatPageEndDrawer.suggestNpcNamesTitle,
          subtitle: t.group.groupChatPageEndDrawer.suggestNpcNamesSubtitle,
          read: (s) => s.configMedia?.nameToolSuggestAllowed ?? false,
          write: (v) =>
              controller.updateSelectedChatSettings(nameToolSuggestAllowed: v),
        ),
      ],
    );
  }
}
