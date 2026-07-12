part of '../group_chat_page.dart';

/// Group flavor of [_WorkspaceEndDrawerImage]. Same field set, but the
/// per-character "Image Style" tile (`imagePromptPrefix`) is intentionally
/// omitted — groups have multiple characters so there's no single one to
/// attach the prefix to. Mirrors the Video Style skip in the Video section.
class _GroupImageSection extends StatelessWidget {
  const _GroupImageSection({
    required this.controller,
    required this.isAdvanced,
    required this.onToggleAdvanced,
  });
  final GroupChatController controller;
  final bool isAdvanced;
  final VoidCallback onToggleAdvanced;

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DrawerSectionHeader(t.llmApp.mediaSection.image),
        _sessionSwitchTile(
          controller: controller,
          icon: Icons.shield,
          title: t.group.groupChatPageEndDrawer.unrestrictedImagesTitle,
          subtitle: t.group.groupChatPageEndDrawer.allowNsfwImagePromptsSubtitle,
          read: (s) => s.configMedia?.imageNsfwAllowed ?? false,
          write: (v) =>
              controller.updateSelectedChatSettings(imageNsfwAllowed: v),
        ),
        _sessionSwitchTile(
          controller: controller,
          icon: Icons.camera_alt,
          title: t.group.groupChatPageEndDrawer.characterCanSendSelfiesTitle,
          subtitle: t.group.groupChatPageEndDrawer.attachSelfieWhenNaturalSubtitle,
          read: (s) => s.configMedia?.imageToolSelfieAllowed ?? false,
          write: (v) =>
              controller.updateSelectedChatSettings(imageToolSelfieAllowed: v),
        ),
        if (isAdvanced) ...[
          _sessionSwitchTile(
            controller: controller,
            icon: Icons.rate_review,
            title: t.group.groupChatPageEndDrawer.reviewImagePromptTitle,
            subtitle: t.group.groupChatPageEndDrawer.editBeforeGeneratingSubtitle,
            read: (s) => s.configMedia?.imagePromptReview ?? false,
            write: (v) =>
                controller.updateSelectedChatSettings(imagePromptReview: v),
          ),
          _sessionSwitchTile(
            controller: controller,
            icon: Icons.rate_review_outlined,
            title: t.group.groupChatPageEndDrawer.reviewToolImagePromptsTitle,
            subtitle:
                t.group.groupChatPageEndDrawer.editToolTriggeredPromptsSubtitle,
            read: (s) => s.configMedia?.imageToolPromptReview ?? false,
            write: (v) =>
                controller.updateSelectedChatSettings(imageToolPromptReview: v),
          ),
          _sessionSwitchTile(
            controller: controller,
            icon: Icons.text_fields,
            title: t.group.groupChatPageEndDrawer.allowSelfieCaptionsTitle,
            subtitle:
                t.group.groupChatPageEndDrawer.captionRenderedOnImageSubtitle,
            read: (s) =>
                s.configMedia?.imageToolSelfieCaptionsAllowed ?? false,
            write: (v) => controller.updateSelectedChatSettings(
              imageToolSelfieCaptionsAllowed: v,
            ),
          ),
          ListenableBuilder(
            listenable: controller,
            builder: (context, _) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TileImagePreset(
                  chatSession: controller.selectedChat,
                  onChanged: controller.persistSession,
                ),
                TileImageAspectRatio(
                  chatSession: controller.selectedChat,
                  onChanged: controller.persistSession,
                ),
              ],
            ),
          ),
        ],
        DrawerShowAdvanced(
          expanded: isAdvanced,
          onToggle: onToggleAdvanced,
        ),
      ],
    );
  }
}
