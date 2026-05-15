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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const DrawerSectionHeader('Video'),
        _sessionSwitchTile(
          visibleChatController: visibleChatController,
          icon: Icons.shield,
          title: 'Unrestricted Videos',
          subtitle: 'Allow NSFW video prompts',
          read: (s) => s.configMedia?.videoNsfwAllowed ?? false,
          write: (v) => visibleChatController.updateSelectedChatSettings(
            videoNsfwAllowed: v,
          ),
        ),
        _sessionSwitchTile(
          visibleChatController: visibleChatController,
          icon: Icons.movie_creation,
          title: 'Character Can Send Videos',
          subtitle: 'Attach a short video when natural',
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
              title: const Text('Video Style'),
              trailing: DrawerTrailingValue(
                prefix?.isNotEmpty == true ? prefix! : 'None',
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
            title: 'Review Video Prompt',
            subtitle: 'Edit before generating',
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
