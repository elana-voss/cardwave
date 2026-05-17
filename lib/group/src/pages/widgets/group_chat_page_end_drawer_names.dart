part of '../group_chat_page.dart';

class _GroupNamesSection extends StatelessWidget {
  const _GroupNamesSection({required this.controller});
  final GroupChatController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const DrawerSectionHeader('Names'),
        _sessionSwitchTile(
          controller: controller,
          icon: Icons.badge,
          title: 'Suggest NPC Names',
          subtitle: 'Pick names from the curated database',
          read: (s) => s.configMedia?.nameToolSuggestAllowed ?? false,
          write: (v) =>
              controller.updateSelectedChatSettings(nameToolSuggestAllowed: v),
        ),
      ],
    );
  }
}
