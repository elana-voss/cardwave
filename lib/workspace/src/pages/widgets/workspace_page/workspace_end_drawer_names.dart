part of '../../workspace_page.dart';

class _WorkspaceEndDrawerNames extends StatelessWidget {
  const _WorkspaceEndDrawerNames({required this.visibleChatController});
  final ChatPageController visibleChatController;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const DrawerSectionHeader('Names'),
        _sessionSwitchTile(
          visibleChatController: visibleChatController,
          icon: Icons.badge,
          title: 'Suggest NPC Names',
          subtitle: 'Pick names from the curated database',
          read: (s) => s.configMedia?.nameToolSuggestAllowed ?? false,
          write: (v) => visibleChatController.updateSelectedChatSettings(
            nameToolSuggestAllowed: v,
          ),
        ),
      ],
    );
  }
}
