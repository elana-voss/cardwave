part of '../../workspace_page.dart';

class _WorkspaceEndDrawer extends StatelessWidget {
  const _WorkspaceEndDrawer({
    required this.visibleChatController,
    required this.activeCharacterFile,
    required this.allChatsList,
    required this.isWideScreen,
    this.onApplyCleaner,
    this.onGlobalAiAction,
  });
  final ChatPageController visibleChatController;
  final CharacterFile activeCharacterFile;
  final Widget allChatsList;
  final bool isWideScreen;
  final void Function(String Function(String))? onApplyCleaner;
  final ValueChanged<AiActionEnum>? onGlobalAiAction;

  @override
  Widget build(BuildContext context) {
    // Read (not watch) as references — the drawer body uses these inside an
    // in-route `ListenableBuilder` (a SettingsService notify out here
    // doesn't reach the pushed drawer route; see the comment in
    // `chatSpecificMenuBuilder` below).
    // ignore: qcheck/avoid_read_inside_build
    final settingsService = context.read<SettingsService>();
    // ignore: qcheck/avoid_read_inside_build
    final characterService = context.read<CharacterService>();
    // ignore: qcheck/avoid_read_inside_build
    final nodesService = context.read<CardwaveNodesModule>().nodesService;
    final workspace = context.watch<WorkspaceController>();

    final showEditorTools = workspace.base == WorkspaceBaseEnum.editor;

    return AppEndDrawer(
      chatSpecificMenuBuilder: (navContext) => ListenableBuilder(
        // The drawer body lives inside `AppEndDrawer`'s nested Navigator. A
        // SettingsService notify out here doesn't propagate to widgets inside
        // a pushed route — so the per-section "Show advanced" toggle only
        // reacts inside an in-route ListenableBuilder.
        listenable: settingsService,
        builder: (context, _) {
          final settings = settingsService.settings;
          bool isAdv(_DrawerSectionEnum section) =>
              settings.drawerSectionAdvanced[section.name] ?? false;
          void toggleAdv(_DrawerSectionEnum section) => unawaited(
            settingsService.setDrawerSectionAdvanced(
              section.name,
              !isAdv(section),
            ),
          );
          // Drawer rows are dense so many toggles fit a narrow panel; the
          // group drawer intentionally opts out of these defaults.
          return IconTheme.merge(
            data: const IconThemeData(size: 20),
            child: ListTileTheme(
              data: const ListTileThemeData(
                dense: true,
                // vertical: -4 is the maximum compression; goes beyond
                // VisualDensity.compact (which is just -2 under the hood).
                // visualDensity: VisualDensity(vertical: -2),
                // contentPadding: EdgeInsets.symmetric(horizontal: 12),
                // horizontalTitleGap: 8,
                // minVerticalPadding: 0,
                // minLeadingWidth: 0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ------------------------------------------------------------------
                  // NOT EDITOR
                  // ------------------------------------------------------------------
                  if (!showEditorTools) ...[
                    // Top-of-drawer entry: configuration is semantically
                    // distinct from the chat-specific actions below, so it
                    // sits above them under its own section header.
                    ListenableBuilder(
                      listenable: visibleChatController,
                      builder: (context, _) {
                        final selectedChat = visibleChatController.selectedChat;
                        return MediaDefaultsDrawerEntry(
                          subtitle: 'Chat session',
                          onTap: selectedChat == null
                              ? null
                              : () {
                                  Navigator.of(
                                    context,
                                    rootNavigator: true,
                                  ).pop();
                                  unawaited(
                                    DialogAiSettings.show(
                                      context,
                                      initialTab:
                                          DialogAiSettingsTab.mediaDefaults,
                                      mediaFocus:
                                          MediaSettingsGridFocus.allColumns,
                                      chatSession: selectedChat,
                                      character: activeCharacterFile,
                                      chatPageController: visibleChatController,
                                    ),
                                  );
                                },
                        );
                      },
                    ),
                    const Divider(height: 1, thickness: 0.5),
                    // ── Quick actions ──
                    ListenableBuilder(
                      listenable: visibleChatController,
                      builder: (context, _) {
                        final isFav = visibleChatController
                            .characterFile
                            .card
                            .cardwaveData
                            .isFavorite;
                        final imageVisible = settings.chatImageVisible;
                        return QuickActionRow(
                          actions: [
                            QuickAction(
                              tileKey: const Key('chat-menu-new-chat'),
                              icon: Icons.add_comment,
                              label: 'New Chat',
                              onTap: () {
                                Navigator.of(
                                  navContext,
                                  rootNavigator: true,
                                ).pop();
                                unawaited(
                                  visibleChatController.promptNewChat(context),
                                );
                              },
                            ),
                            QuickAction(
                              tileKey: const Key('drawer-all-chats'),
                              icon: Icons.forum,
                              label: 'All Chats',
                              onTap: () => Navigator.of(
                                navContext,
                              ).pushNamed('/all_chats'),
                            ),
                            QuickAction(
                              icon: Icons.favorite_border,
                              selectedIcon: Icons.favorite,
                              isSelected: isFav,
                              label: 'Favorite',
                              onTap: visibleChatController.toggleFavorite,
                            ),
                            QuickAction(
                              icon: Icons.image_not_supported_outlined,
                              selectedIcon: Icons.image,
                              isSelected: imageVisible,
                              label: 'Show Image',
                              onTap: () {
                                settings.chatImageVisible = !imageVisible;
                                unawaited(settingsService.saveSettings());
                                Navigator.of(
                                  navContext,
                                  rootNavigator: true,
                                ).pop();
                              },
                            ),
                          ],
                        );
                      },
                    ),
                    // ── Chat Behavior ──
                    _WorkspaceEndDrawerChat(
                      visibleChatController: visibleChatController,
                      activeCharacterFile: activeCharacterFile,
                      isAdvanced: isAdv(_DrawerSectionEnum.chat),
                      onToggleAdvanced: () =>
                          toggleAdv(_DrawerSectionEnum.chat),
                    ),
                    _WorkspaceEndDrawerChatTheme(
                      visibleChatController: visibleChatController,
                      activeCharacterFile: activeCharacterFile,
                      settingsService: settingsService,
                      characterService: characterService,
                    ),
                    _WorkspaceEndDrawerSpeech(
                      visibleChatController: visibleChatController,
                      activeCharacterFile: activeCharacterFile,
                      isAdvanced: isAdv(_DrawerSectionEnum.speech),
                      onToggleAdvanced: () =>
                          toggleAdv(_DrawerSectionEnum.speech),
                    ),
                    _WorkspaceEndDrawerVideo(
                      visibleChatController: visibleChatController,
                      activeCharacterFile: activeCharacterFile,
                      characterService: characterService,
                      isAdvanced: isAdv(_DrawerSectionEnum.video),
                      onToggleAdvanced: () =>
                          toggleAdv(_DrawerSectionEnum.video),
                    ),
                    _WorkspaceEndDrawerImage(
                      visibleChatController: visibleChatController,
                      activeCharacterFile: activeCharacterFile,
                      characterService: characterService,
                      isAdvanced: isAdv(_DrawerSectionEnum.image),
                      onToggleAdvanced: () =>
                          toggleAdv(_DrawerSectionEnum.image),
                    ),
                    _WorkspaceEndDrawerWeb(
                      visibleChatController: visibleChatController,
                    ),
                    _WorkspaceEndDrawerNames(
                      visibleChatController: visibleChatController,
                    ),
                    // NODES debug snapshot — development/tuning tool per
                    // spec §10, not intended for end-user interaction.
                    ListTile(
                      leading: const Icon(Icons.bug_report_outlined),
                      title: const Text('NODES Engine'),
                      subtitle: const Text('Debug snapshot'),
                      onTap: () {
                        Navigator.of(navContext, rootNavigator: true).pop();
                        unawaited(
                          NodesDebugController.show(
                            nodesService: nodesService,
                          ),
                        );
                      },
                    ),
                  ]
                  // ------------------------------------------------------------------
                  // EDITOR
                  // ------------------------------------------------------------------
                  else ...[
                    // Top-of-drawer entry: configuration is semantically
                    // distinct from editor actions below, so it sits
                    // above them under its own section header. The next
                    // section's DrawerSectionHeader provides the divider.
                    MediaDefaultsDrawerEntry(
                      subtitle: 'Character',
                      onTap: () {
                        Navigator.of(
                          navContext,
                          rootNavigator: true,
                        ).pop();
                        unawaited(
                          DialogAiSettings.show(
                            navContext,
                            initialTab: DialogAiSettingsTab.mediaDefaults,
                            mediaFocus:
                                MediaSettingsGridFocus.appAndCharacter,
                            character: activeCharacterFile,
                          ),
                        );
                      },
                    ),
                    _WorkspaceEndDrawerDisplay(
                      settingsService: settingsService,
                    ),
                    if (onGlobalAiAction != null)
                      _WorkspaceEndDrawerAi(
                        onGlobalAiAction: onGlobalAiAction!,
                      ),
                    _WorkspaceEndDrawerEditing(onApplyCleaner: onApplyCleaner),
                    _WorkspaceEndDrawerExport(
                      activeCharacterFile: activeCharacterFile,
                      characterService: characterService,
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
      chatSpecificRoutes: {
        if (!showEditorTools)
          '/all_chats': (_) => AppDrawerPage(
            title: 'All Chats',
            child: allChatsList,
          ),
      },
    );
  }

}

/// Shared shape for the Video / Image / Web boolean rows: each one wraps
/// a [DrawerSwitchTile] in a [ListenableBuilder] for the chat controller,
/// reads the current value off the active session, and writes back via
/// `updateSelectedChatSettings`. The 10 inline copies of this pattern
/// differ only in icon, label, and which `configMedia` field they touch.
// Small per-drawer tile builder; a shared widget would need ~10 call
// sites here re-routed through an explicit controller param.
// ignore: qcheck/avoid_returning_widgets
Widget _sessionSwitchTile({
  required ChatPageController visibleChatController,
  required IconData icon,
  required String title,
  required String subtitle,
  required bool Function(ChatSession) read,
  required void Function(bool) write,
}) {
  return ListenableBuilder(
    listenable: visibleChatController,
    builder: (context, _) {
      final session = visibleChatController.selectedChat;
      return DrawerSwitchTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        value: session != null && read(session),
        onChanged: session != null ? write : null,
      );
    },
  );
}

Future<void> _showImagePrefixDialog(
  BuildContext context,
  CharacterFile characterFile,
  CharacterService characterService,
) => _showPromptPrefixDialog(
  context,
  characterFile,
  characterService,
  PromptPrefixDomain.image,
);

Future<void> _showVideoPrefixDialog(
  BuildContext context,
  CharacterFile characterFile,
  CharacterService characterService,
) => _showPromptPrefixDialog(
  context,
  characterFile,
  characterService,
  PromptPrefixDomain.video,
);

Future<void> _showPromptPrefixDialog(
  BuildContext context,
  CharacterFile characterFile,
  CharacterService characterService,
  PromptPrefixDomain domain,
) async {
  final currentValue = switch (domain) {
    PromptPrefixDomain.image => characterFile.configMedia?.imagePromptPrefix,
    PromptPrefixDomain.video => characterFile.configMedia?.videoPromptPrefix,
  };
  final result = await showCharacterPromptPrefixDialog(
    context,
    domain: domain,
    currentValue: currentValue,
  );
  if (result == null) return;
  final cm = characterFile.configMedia ??= ConfigMediaCharacter();
  final stored = result.isEmpty ? null : result;
  switch (domain) {
    case PromptPrefixDomain.image:
      cm.imagePromptPrefix = stored;
    case PromptPrefixDomain.video:
      cm.videoPromptPrefix = stored;
  }
  await characterService.flushJsonInCacheAndPngIfDirtyOrPending(
    characterFile,
  );
}

void _showStylePresetsDialog(
  CharacterFile characterFile,
  CharacterService characterService,
) {
  unawaited(
    NavigationService().showStylePresetsDialog(
      characterFile: characterFile,
      characterService: characterService,
    ),
  );
}

/// Sections in the chat drawer that have an expandable "advanced" group.
/// The persisted `AppSettings.drawerSectionAdvanced` map keys by [name]
/// (Chat Theme and Web are intentionally absent — neither has advanced
/// rows, so they do not render an expander).
enum _DrawerSectionEnum { chat, speech, video, image }
