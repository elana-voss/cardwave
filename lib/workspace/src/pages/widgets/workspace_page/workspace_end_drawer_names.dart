part of '../../workspace_page.dart';

class _WorkspaceEndDrawerNames extends StatelessWidget {
  const _WorkspaceEndDrawerNames({required this.visibleChatController});
  final ChatPageController visibleChatController;

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DrawerSectionHeader(t.llmApp.mediaSection.names),
        _sessionSwitchTile(
          visibleChatController: visibleChatController,
          icon: Icons.badge,
          title: t.group.groupChatPageEndDrawer.suggestNpcNamesTitle,
          subtitle: t.group.groupChatPageEndDrawer.suggestNpcNamesSubtitle,
          read: (s) => s.configMedia?.nameToolSuggestAllowed ?? false,
          write: (v) => visibleChatController.updateSelectedChatSettings(
            nameToolSuggestAllowed: v,
          ),
        ),
      ],
    );
  }
}
