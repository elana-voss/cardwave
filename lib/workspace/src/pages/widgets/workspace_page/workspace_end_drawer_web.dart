part of '../../workspace_page.dart';

class _WorkspaceEndDrawerWeb extends StatelessWidget {
  const _WorkspaceEndDrawerWeb({required this.visibleChatController});
  final ChatPageController visibleChatController;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const DrawerSectionHeader('Web'),
        _sessionSwitchTile(
          visibleChatController: visibleChatController,
          icon: Icons.cloud_download,
          title: 'Allow Web Fetch',
          subtitle: 'Read public web pages when relevant',
          read: (s) => s.configMedia?.webToolFetchAllowed ?? false,
          write: (v) => visibleChatController.updateSelectedChatSettings(
            webToolFetchAllowed: v,
          ),
        ),
        _sessionSwitchTile(
          visibleChatController: visibleChatController,
          icon: Icons.rate_review,
          title: 'Review URL Before Fetching',
          subtitle: 'Confirm each fetch',
          read: (s) => s.configMedia?.webToolFetchReview ?? false,
          write: (v) => visibleChatController.updateSelectedChatSettings(
            webToolFetchReview: v,
          ),
        ),
      ],
    );
  }
}
