part of '../../workspace_page.dart';

class _WorkspaceEndDrawerChat extends StatelessWidget {
  const _WorkspaceEndDrawerChat({
    required this.visibleChatController,
    required this.activeCharacterFile,
    required this.isAdvanced,
    required this.onToggleAdvanced,
  });
  final ChatPageController visibleChatController;
  final CharacterFile activeCharacterFile;
  final bool isAdvanced;
  final VoidCallback onToggleAdvanced;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const DrawerSectionHeader('Chat'),
        TileNsfw(
          chatSession: visibleChatController.selectedChat,
          onChanged: (value) =>
              visibleChatController.updateSelectedChatSettings(isNsfw: value),
        ),
        TileScenario(
          chatSession: visibleChatController.selectedChat,
          onChanged: (value) => visibleChatController
              .updateSelectedChatSettings(isScenario: value),
        ),
        TileAiProvider(
          chatSession: visibleChatController.selectedChat,
          characterFile: activeCharacterFile,
          onChanged: visibleChatController.refresh,
        ),
        if (isAdvanced) ...[
          TileTrailingParagraph(
            chatSession: visibleChatController.selectedChat,
            onChanged: (value) {
              unawaited(() async {
                await visibleChatController.updateSelectedChatSettings(
                  removeTrailingSentences: value,
                );
                if (value) {
                  await visibleChatController.trimTrailingParagraph();
                }
              }());
            },
          ),
          TileMaxResponseLength(
            chatSession: visibleChatController.selectedChat,
          ),
          TileReasoningEffort(chatSession: visibleChatController.selectedChat),
        ],
        DrawerShowAdvanced(expanded: isAdvanced, onToggle: onToggleAdvanced),
      ],
    );
  }
}
