part of '../group_chat_page.dart';

class _GroupWebSection extends StatelessWidget {
  const _GroupWebSection({required this.controller});
  final GroupChatController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const DrawerSectionHeader('Web'),
        _sessionSwitchTile(
          controller: controller,
          icon: Icons.cloud_download,
          title: 'Allow Web Fetch',
          subtitle: 'Read public web pages when relevant',
          read: (s) => s.configMedia?.webToolFetchAllowed ?? false,
          write: (v) =>
              controller.updateSelectedChatSettings(webToolFetchAllowed: v),
        ),
        _sessionSwitchTile(
          controller: controller,
          icon: Icons.rate_review,
          title: 'Review URL Before Fetching',
          subtitle: 'Confirm each fetch',
          read: (s) => s.configMedia?.webToolFetchReview ?? false,
          write: (v) =>
              controller.updateSelectedChatSettings(webToolFetchReview: v),
        ),
      ],
    );
  }
}
