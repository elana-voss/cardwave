part of '../../workspace_page.dart';

class _WorkspaceEndDrawerWeb extends StatelessWidget {
  const _WorkspaceEndDrawerWeb({required this.visibleChatController});
  final ChatPageController visibleChatController;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DrawerSectionHeader(t.llmApp.mediaSection.web),
        _sessionSwitchTile(
          visibleChatController: visibleChatController,
          icon: Icons.cloud_download,
          title: t.group.groupChatPageEndDrawer.allowWebFetchTitle,
          subtitle: t.group.groupChatPageEndDrawer.allowWebFetchSubtitle,
          read: (s) => s.configMedia?.webToolFetchAllowed ?? false,
          write: (v) => visibleChatController.updateSelectedChatSettings(
            webToolFetchAllowed: v,
          ),
        ),
        _sessionSwitchTile(
          visibleChatController: visibleChatController,
          icon: Icons.rate_review,
          title: t.group.groupChatPageEndDrawer.reviewUrlTitle,
          subtitle: t.group.groupChatPageEndDrawer.reviewUrlSubtitle,
          read: (s) => s.configMedia?.webToolFetchReview ?? false,
          write: (v) => visibleChatController.updateSelectedChatSettings(
            webToolFetchReview: v,
          ),
        ),
      ],
    );
  }
}
