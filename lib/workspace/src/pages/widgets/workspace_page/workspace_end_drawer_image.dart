part of '../../workspace_page.dart';

class _WorkspaceEndDrawerImage extends StatelessWidget {
  const _WorkspaceEndDrawerImage({
    required this.visibleChatController,
    required this.activeCharacterFile,
    required this.characterService,
    required this.isAdvanced,
    required this.onToggleAdvanced,
  });
  final ChatPageController visibleChatController;
  final CharacterFile activeCharacterFile;
  final CharacterService characterService;
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
          visibleChatController: visibleChatController,
          icon: Icons.shield,
          title: t.group.groupChatPageEndDrawer.unrestrictedImagesTitle,
          subtitle: t.group.groupChatPageEndDrawer.allowNsfwImagePromptsSubtitle,
          read: (s) => s.configMedia?.imageNsfwAllowed ?? false,
          write: (v) => visibleChatController.updateSelectedChatSettings(
            imageNsfwAllowed: v,
          ),
        ),
        _sessionSwitchTile(
          visibleChatController: visibleChatController,
          icon: Icons.camera_alt,
          title: t.group.groupChatPageEndDrawer.characterCanSendSelfiesTitle,
          subtitle: t.group.groupChatPageEndDrawer.attachSelfieWhenNaturalSubtitle,
          read: (s) => s.configMedia?.imageToolSelfieAllowed ?? false,
          write: (v) => visibleChatController.updateSelectedChatSettings(
            imageToolSelfieAllowed: v,
          ),
        ),
        ListenableBuilder(
          listenable: characterService,
          builder: (context, _) {
            final prefix = activeCharacterFile.configMedia?.imagePromptPrefix;
            return ListTile(
              leading: const Icon(Icons.auto_fix_high),
              title: Text(t.workspace.workspaceEndDrawerImage.imageStyleTitle),
              trailing: DrawerTrailingValue(
                prefix?.isNotEmpty == true
                    ? prefix!
                    : t.workspace.workspaceEndDrawerImage.noneValue,
                suffix: InkWell(
                  onTap: () => _showStylePresetsDialog(
                    activeCharacterFile,
                    characterService,
                  ),
                  child: const Icon(Icons.style, size: 18),
                ),
              ),
              onTap: () {
                Navigator.of(context, rootNavigator: true).pop();
                unawaited(
                  _showImagePrefixDialog(
                    context,
                    activeCharacterFile,
                    characterService,
                  ),
                );
              },
            );
          },
        ),
        if (isAdvanced) ...[
          _sessionSwitchTile(
            visibleChatController: visibleChatController,
            icon: Icons.rate_review,
            title: t.group.groupChatPageEndDrawer.reviewImagePromptTitle,
            subtitle: t.group.groupChatPageEndDrawer.editBeforeGeneratingSubtitle,
            read: (s) => s.configMedia?.imagePromptReview ?? false,
            write: (v) => visibleChatController.updateSelectedChatSettings(
              imagePromptReview: v,
            ),
          ),
          _sessionSwitchTile(
            visibleChatController: visibleChatController,
            icon: Icons.rate_review_outlined,
            title: t.group.groupChatPageEndDrawer.reviewToolImagePromptsTitle,
            subtitle:
                t.group.groupChatPageEndDrawer.editToolTriggeredPromptsSubtitle,
            read: (s) => s.configMedia?.imageToolPromptReview ?? false,
            write: (v) => visibleChatController.updateSelectedChatSettings(
              imageToolPromptReview: v,
            ),
          ),
          _sessionSwitchTile(
            visibleChatController: visibleChatController,
            icon: Icons.text_fields,
            title: t.group.groupChatPageEndDrawer.allowSelfieCaptionsTitle,
            subtitle:
                t.group.groupChatPageEndDrawer.captionRenderedOnImageSubtitle,
            read: (s) =>
                s.configMedia?.imageToolSelfieCaptionsAllowed ?? false,
            write: (v) => visibleChatController.updateSelectedChatSettings(
              imageToolSelfieCaptionsAllowed: v,
            ),
          ),
          TileImagePreset(
            chatSession: visibleChatController.selectedChat,
            characterFile: activeCharacterFile,
            onChanged: visibleChatController.persistActiveChat,
          ),
          TileImageAspectRatio(
            chatSession: visibleChatController.selectedChat,
            characterFile: activeCharacterFile,
            onChanged: visibleChatController.persistActiveChat,
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
