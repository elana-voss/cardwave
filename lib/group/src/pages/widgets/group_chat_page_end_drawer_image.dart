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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const DrawerSectionHeader('Image'),
        _sessionSwitchTile(
          controller: controller,
          icon: Icons.shield,
          title: 'Unrestricted Images',
          subtitle: 'Allow NSFW image prompts',
          read: (s) => s.configMedia?.imageNsfwAllowed ?? false,
          write: (v) =>
              controller.updateSelectedChatSettings(imageNsfwAllowed: v),
        ),
        _sessionSwitchTile(
          controller: controller,
          icon: Icons.camera_alt,
          title: 'Character Can Send Selfies',
          subtitle: 'Attach a selfie when natural',
          read: (s) => s.configMedia?.imageToolSelfieAllowed ?? false,
          write: (v) =>
              controller.updateSelectedChatSettings(imageToolSelfieAllowed: v),
        ),
        if (isAdvanced) ...[
          _sessionSwitchTile(
            controller: controller,
            icon: Icons.rate_review,
            title: 'Review Image Prompt',
            subtitle: 'Edit before generating',
            read: (s) => s.configMedia?.imagePromptReview ?? false,
            write: (v) =>
                controller.updateSelectedChatSettings(imagePromptReview: v),
          ),
          _sessionSwitchTile(
            controller: controller,
            icon: Icons.rate_review_outlined,
            title: 'Review Tool Image Prompts',
            subtitle: 'Edit tool-triggered prompts',
            read: (s) => s.configMedia?.imageToolPromptReview ?? false,
            write: (v) =>
                controller.updateSelectedChatSettings(imageToolPromptReview: v),
          ),
          _sessionSwitchTile(
            controller: controller,
            icon: Icons.text_fields,
            title: 'Allow Selfie Captions',
            subtitle: 'Caption rendered on the image',
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
