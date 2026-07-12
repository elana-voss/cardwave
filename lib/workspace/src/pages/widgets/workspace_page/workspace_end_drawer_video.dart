part of '../../workspace_page.dart';

class _WorkspaceEndDrawerVideo extends StatelessWidget {
  const _WorkspaceEndDrawerVideo({
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
        DrawerSectionHeader(t.llmApp.mediaSection.video),
        _sessionSwitchTile(
          visibleChatController: visibleChatController,
          icon: Icons.shield,
          title: t.group.groupChatPageEndDrawer.unrestrictedVideosTitle,
          subtitle: t.group.groupChatPageEndDrawer.allowNsfwVideoPromptsSubtitle,
          read: (s) => s.configMedia?.videoNsfwAllowed ?? false,
          write: (v) => visibleChatController.updateSelectedChatSettings(
            videoNsfwAllowed: v,
          ),
        ),
        _sessionSwitchTile(
          visibleChatController: visibleChatController,
          icon: Icons.movie_creation,
          title: t.group.groupChatPageEndDrawer.characterCanSendVideosTitle,
          subtitle:
              t.group.groupChatPageEndDrawer.attachShortVideoWhenNaturalSubtitle,
          read: (s) => s.configMedia?.videoToolSendAllowed ?? false,
          write: (v) => visibleChatController.updateSelectedChatSettings(
            videoToolSendAllowed: v,
          ),
        ),
        ListenableBuilder(
          listenable: characterService,
          builder: (context, _) {
            final prefix = activeCharacterFile.configMedia?.videoPromptPrefix;
            return ListTile(
              leading: const Icon(Icons.movie_filter),
              title: Text(t.workspace.workspaceEndDrawerVideo.videoStyleTitle),
              trailing: DrawerTrailingValue(
                prefix?.isNotEmpty == true
                    ? prefix!
                    : t.workspace.workspaceEndDrawerImage.noneValue,
              ),
              onTap: () {
                Navigator.of(context, rootNavigator: true).pop();
                unawaited(
                  _showVideoPrefixDialog(
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
            title: t.group.groupChatPageEndDrawer.reviewVideoPromptTitle,
            subtitle: t.group.groupChatPageEndDrawer.editBeforeGeneratingSubtitle,
            read: (s) => s.configMedia?.videoPromptReview ?? false,
            write: (v) => visibleChatController.updateSelectedChatSettings(
              videoPromptReview: v,
            ),
          ),
          TileVideoPreset(
            chatSession: visibleChatController.selectedChat,
            characterFile: activeCharacterFile,
            onChanged: visibleChatController.persistActiveChat,
          ),
          TileVideoResolution(
            chatSession: visibleChatController.selectedChat,
            characterFile: activeCharacterFile,
            onChanged: visibleChatController.persistActiveChat,
          ),
          TileVideoAspectRatio(
            chatSession: visibleChatController.selectedChat,
            characterFile: activeCharacterFile,
            onChanged: visibleChatController.persistActiveChat,
          ),
          TileVideoDuration(
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
