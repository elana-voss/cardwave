part of '../../workspace_page.dart';

class _WorkspaceEndDrawerSpeech extends StatelessWidget {
  const _WorkspaceEndDrawerSpeech({
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
        DrawerSectionHeader(t.common.modelCapability.speech),
        TileTtsPreset(
          chatSession: visibleChatController.selectedChat,
          characterFile: activeCharacterFile,
          onChanged: visibleChatController.persistActiveChat,
        ),
        TileTtsVoice(
          chatSession: visibleChatController.selectedChat,
          characterFile: activeCharacterFile,
          onChanged: visibleChatController.persistActiveChat,
        ),
        if (isAdvanced)
          TileTtsLanguage(
            chatSession: visibleChatController.selectedChat,
            characterFile: activeCharacterFile,
            onChanged: visibleChatController.persistActiveChat,
          ),
        DrawerShowAdvanced(
          expanded: isAdvanced,
          onToggle: onToggleAdvanced,
        ),
      ],
    );
  }
}
