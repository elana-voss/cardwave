part of '../group_chat_page.dart';

class _GroupWebSection extends StatelessWidget {
  const _GroupWebSection({required this.controller});
  final GroupChatController controller;

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DrawerSectionHeader(t.llmApp.mediaSection.web),
        _sessionSwitchTile(
          controller: controller,
          icon: Icons.cloud_download,
          title: t.group.groupChatPageEndDrawer.allowWebFetchTitle,
          subtitle: t.group.groupChatPageEndDrawer.allowWebFetchSubtitle,
          read: (s) => s.configMedia?.webToolFetchAllowed ?? false,
          write: (v) =>
              controller.updateSelectedChatSettings(webToolFetchAllowed: v),
        ),
        _sessionSwitchTile(
          controller: controller,
          icon: Icons.rate_review,
          title: t.group.groupChatPageEndDrawer.reviewUrlTitle,
          subtitle: t.group.groupChatPageEndDrawer.reviewUrlSubtitle,
          read: (s) => s.configMedia?.webToolFetchReview ?? false,
          write: (v) =>
              controller.updateSelectedChatSettings(webToolFetchReview: v),
        ),
      ],
    );
  }
}
