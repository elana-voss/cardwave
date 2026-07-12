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
    final t = Translations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (visibleChatController.isAssistant) ...[
          DrawerSectionHeader(
            t.workspace.workspaceEndDrawerChat.assistantCardEditsSectionHeader,
          ),
          const TileAssistantCardEditRequireApproval(
            modality: CardEditModality.edit,
          ),
          const TileAssistantCardEditRequireApproval(
            modality: CardEditModality.addition,
          ),
          const TileAssistantCardEditRequireApproval(
            modality: CardEditModality.deletion,
          ),
        ],
        DrawerSectionHeader(t.group.groupChatPageEndDrawer.chatSectionHeader),
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
        if (!visibleChatController.isAssistant) const TileRecalledMemory(),
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
