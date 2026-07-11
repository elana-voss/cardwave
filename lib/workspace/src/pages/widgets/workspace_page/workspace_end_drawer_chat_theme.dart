part of '../../workspace_page.dart';

class _WorkspaceEndDrawerChatTheme extends StatelessWidget {
  const _WorkspaceEndDrawerChatTheme({
    required this.visibleChatController,
    required this.activeCharacterFile,
    required this.settingsService,
    required this.characterService,
  });
  final ChatPageController visibleChatController;
  final CharacterFile activeCharacterFile;
  final SettingsService settingsService;
  final CharacterService characterService;

  @override
  Widget build(BuildContext context) {
    final settings = settingsService.settings;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DrawerSectionHeader(t.group.groupChatPageEndDrawer.chatThemeSectionHeader),
        TileChatTheme(
          settings: settings,
          onThemeChanged: (theme) {
            settings.chatTheme = theme;
            unawaited(settingsService.saveSettings());
          },
        ),
        ListenableBuilder(
          listenable: Listenable.merge([
            visibleChatController,
            characterService,
          ]),
          builder: (context, _) {
            final theme = Theme.of(context);
            final disabledColor = theme.colorScheme.onSurface.withValues(
              alpha: kDisabledAlpha,
            );
            final hasBg =
                visibleChatController.selectedChat?.backgroundImage != null;
            final hasAvatar =
                activeCharacterFile.card.cardwaveData.customAvatar != null;
            return ListTile(
              leading: const Icon(Icons.restart_alt),
              title: Text(t.workspace.workspaceEndDrawerChatTheme.resetImagesTitle),
              trailing: SizedBox(
                width: 160,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 4,
                    children: [
                      InkWell(
                        onTap: hasBg
                            ? () =>
                                  visibleChatController.setBackgroundImage(null)
                            : null,
                        child: Icon(
                          Icons.wallpaper,
                          size: 18,
                          color: hasBg ? null : disabledColor,
                        ),
                      ),
                      InkWell(
                        onTap: hasAvatar
                            ? () {
                                activeCharacterFile
                                    .card
                                    .cardwaveData
                                    .customAvatar = null;
                                unawaited(
                                  characterService.saveJsonInCacheAndPngNow(
                                    activeCharacterFile,
                                  ),
                                );
                              }
                            : null,
                        child: Icon(
                          Icons.face,
                          size: 18,
                          color: hasAvatar ? null : disabledColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
