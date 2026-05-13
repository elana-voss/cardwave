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
                    const DrawerSectionHeader('Chat'),
                    TileNsfw(
                      chatSession: visibleChatController.selectedChat,
                      onChanged: (value) => visibleChatController
                          .updateSelectedChatSettings(isNsfw: value),
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
                    if (isAdv(_DrawerSectionEnum.chat)) ...[
                      TileTrailingParagraph(
                        chatSession: visibleChatController.selectedChat,
                        onChanged: (value) async {
                          await visibleChatController
                              .updateSelectedChatSettings(
                                removeTrailingSentences: value,
                              );
                          if (value) {
                            await visibleChatController.trimTrailingParagraph();
                          }
                        },
                      ),
                      TileMaxResponseLength(
                        chatSession: visibleChatController.selectedChat,
                      ),
                      TileReasoningEffort(
                        chatSession: visibleChatController.selectedChat,
                      ),
                    ],
                    DrawerShowAdvanced(
                      expanded: isAdv(_DrawerSectionEnum.chat),
                      onToggle: () => toggleAdv(_DrawerSectionEnum.chat),
                    ),
                    // ── Chat Appearance ──
                    const DrawerSectionHeader('Chat Theme'),
                    ChatThemeTile(
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
                        final disabledColor = theme.colorScheme.onSurface
                            .withValues(alpha: kDisabledAlpha);
                        final hasBg =
                            visibleChatController
                                .selectedChat
                                ?.backgroundImage !=
                            null;
                        final hasAvatar =
                            activeCharacterFile
                                .card
                                .cardwaveData
                                .customAvatar !=
                            null;
                        return ListTile(
                          leading: const Icon(Icons.restart_alt),
                          title: const Text('Reset Images'),
                          trailing: SizedBox(
                            width: 160,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  InkWell(
                                    onTap: hasBg
                                        ? () => visibleChatController
                                              .setBackgroundImage(null)
                                        : null,
                                    child: Icon(
                                      Icons.wallpaper,
                                      size: 18,
                                      color: hasBg ? null : disabledColor,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  InkWell(
                                    onTap: hasAvatar
                                        ? () {
                                            activeCharacterFile
                                                    .card
                                                    .cardwaveData
                                                    .customAvatar =
                                                null;
                                            unawaited(
                                              characterService
                                                  .saveJsonInCacheAndPngNow(
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
                    // ── Text-to-Speech ──
                    const DrawerSectionHeader('Speech'),
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
                    if (isAdv(_DrawerSectionEnum.speech))
                      TileTtsLanguage(
                        chatSession: visibleChatController.selectedChat,
                        characterFile: activeCharacterFile,
                        onChanged: visibleChatController.persistActiveChat,
                      ),
                    DrawerShowAdvanced(
                      expanded: isAdv(_DrawerSectionEnum.speech),
                      onToggle: () => toggleAdv(_DrawerSectionEnum.speech),
                    ),
                    // ── Video Generation ──
                    const DrawerSectionHeader('Video'),
                    _sessionSwitchTile(
                      icon: Icons.shield,
                      title: 'Unrestricted Videos',
                      subtitle: 'Allow NSFW video prompts',
                      read: (s) => s.configMedia?.videoNsfwAllowed ?? false,
                      write: (v) => visibleChatController
                          .updateSelectedChatSettings(videoNsfwAllowed: v),
                    ),
                    _sessionSwitchTile(
                      icon: Icons.movie_creation,
                      title: 'Character Can Send Videos',
                      subtitle: 'Attach a short video when natural',
                      read: (s) => s.configMedia?.videoToolSendAllowed ?? false,
                      write: (v) => visibleChatController
                          .updateSelectedChatSettings(videoToolSendAllowed: v),
                    ),
                    ListenableBuilder(
                      listenable: characterService,
                      builder: (context, _) {
                        final prefix =
                            activeCharacterFile.configMedia?.videoPromptPrefix;
                        return ListTile(
                          leading: const Icon(Icons.movie_filter),
                          title: const Text('Video Style'),
                          trailing: DrawerTrailingValue(
                            prefix?.isNotEmpty == true ? prefix! : 'None',
                          ),
                          onTap: () {
                            Navigator.of(
                              navContext,
                              rootNavigator: true,
                            ).pop();
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
                    if (isAdv(_DrawerSectionEnum.video)) ...[
                      _sessionSwitchTile(
                        icon: Icons.rate_review,
                        title: 'Review Video Prompt',
                        subtitle: 'Edit before generating',
                        read: (s) => s.configMedia?.videoPromptReview ?? false,
                        write: (v) => visibleChatController
                            .updateSelectedChatSettings(videoPromptReview: v),
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
                      expanded: isAdv(_DrawerSectionEnum.video),
                      onToggle: () => toggleAdv(_DrawerSectionEnum.video),
                    ),
                    // ── Image Generation ──
                    const DrawerSectionHeader('Image'),
                    _sessionSwitchTile(
                      icon: Icons.shield,
                      title: 'Unrestricted Images',
                      subtitle: 'Allow NSFW image prompts',
                      read: (s) => s.configMedia?.imageNsfwAllowed ?? false,
                      write: (v) => visibleChatController
                          .updateSelectedChatSettings(imageNsfwAllowed: v),
                    ),
                    _sessionSwitchTile(
                      icon: Icons.camera_alt,
                      title: 'Character Can Send Selfies',
                      subtitle: 'Attach a selfie when natural',
                      read: (s) =>
                          s.configMedia?.imageToolSelfieAllowed ?? false,
                      write: (v) =>
                          visibleChatController.updateSelectedChatSettings(
                            imageToolSelfieAllowed: v,
                          ),
                    ),
                    ListenableBuilder(
                      listenable: characterService,
                      builder: (context, _) {
                        final prefix =
                            activeCharacterFile.configMedia?.imagePromptPrefix;
                        return ListTile(
                          leading: const Icon(Icons.auto_fix_high),
                          title: const Text('Image Style'),
                          trailing: DrawerTrailingValue(
                            prefix?.isNotEmpty == true ? prefix! : 'None',
                            suffix: InkWell(
                              onTap: () => _showStylePresetsDialog(
                                activeCharacterFile,
                                characterService,
                              ),
                              child: const Icon(Icons.style, size: 18),
                            ),
                          ),
                          onTap: () {
                            Navigator.of(
                              navContext,
                              rootNavigator: true,
                            ).pop();
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
                    if (isAdv(_DrawerSectionEnum.image)) ...[
                      _sessionSwitchTile(
                        icon: Icons.rate_review,
                        title: 'Review Image Prompt',
                        subtitle: 'Edit before generating',
                        read: (s) => s.configMedia?.imagePromptReview ?? false,
                        write: (v) => visibleChatController
                            .updateSelectedChatSettings(imagePromptReview: v),
                      ),
                      _sessionSwitchTile(
                        icon: Icons.rate_review_outlined,
                        title: 'Review Tool Image Prompts',
                        subtitle: 'Edit tool-triggered prompts',
                        read: (s) =>
                            s.configMedia?.imageToolPromptReview ?? false,
                        write: (v) =>
                            visibleChatController.updateSelectedChatSettings(
                              imageToolPromptReview: v,
                            ),
                      ),
                      _sessionSwitchTile(
                        icon: Icons.text_fields,
                        title: 'Allow Selfie Captions',
                        subtitle: 'Caption rendered on the image',
                        read: (s) =>
                            s.configMedia?.imageToolSelfieCaptionsAllowed ??
                            false,
                        write: (v) =>
                            visibleChatController.updateSelectedChatSettings(
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
                      expanded: isAdv(_DrawerSectionEnum.image),
                      onToggle: () => toggleAdv(_DrawerSectionEnum.image),
                    ),
                    // ── Web ──
                    const DrawerSectionHeader('Web'),
                    _sessionSwitchTile(
                      icon: Icons.cloud_download,
                      title: 'Allow Web Fetch',
                      subtitle: 'Read public web pages when relevant',
                      read: (s) => s.configMedia?.webToolFetchAllowed ?? false,
                      write: (v) => visibleChatController
                          .updateSelectedChatSettings(webToolFetchAllowed: v),
                    ),
                    _sessionSwitchTile(
                      icon: Icons.rate_review,
                      title: 'Review URL Before Fetching',
                      subtitle: 'Confirm each fetch',
                      read: (s) => s.configMedia?.webToolFetchReview ?? false,
                      write: (v) => visibleChatController
                          .updateSelectedChatSettings(webToolFetchReview: v),
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
                    const DrawerSectionHeader('Display'),
                    DrawerSwitchTile(
                      leading: const Icon(Icons.image),
                      title: const Text('Show Character Image'),
                      subtitle: const Text('Wide-screen editor only'),
                      value: settings.editorImageVisible,
                      onChanged: (value) {
                        settings.editorImageVisible = value;
                        unawaited(settingsService.saveSettings());
                        Navigator.of(navContext, rootNavigator: true).pop();
                      },
                    ),
                    if (onGlobalAiAction != null) ...[
                      const DrawerSectionHeader('AI'),
                      for (final action in AiActionEnum.values)
                        ListTile(
                          leading: Icon(action.icon),
                          title: Text(action.label),
                          onTap: () {
                            Navigator.of(
                              navContext,
                              rootNavigator: true,
                            ).pop();
                            onGlobalAiAction!(action);
                          },
                        ),
                    ],
                    const DrawerSectionHeader('Editing'),
                    ListTile(
                      leading: const Icon(Icons.cleaning_services),
                      title: const Text('Content Cleaner'),
                      onTap: () async {
                        Navigator.of(
                          navContext,
                          rootNavigator: true,
                        ).pop();
                        if (onApplyCleaner != null) {
                          await NavigationService().showContentCleanerDialog(
                            onApply: onApplyCleaner!,
                          );
                        }
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.find_replace),
                      title: const Text('Find & Replace'),
                      onTap: () async {
                        Navigator.of(
                          navContext,
                          rootNavigator: true,
                        ).pop();
                        if (onApplyCleaner != null) {
                          await NavigationService().showFindReplaceDialog(
                            onApply: onApplyCleaner!,
                          );
                        }
                      },
                    ),
                    const DrawerSectionHeader('Export'),
                    ListTile(
                      leading: const Icon(Icons.image),
                      title: const Text('Export as PNG (V2/V3)'),
                      onTap: () async {
                        Navigator.of(
                          navContext,
                          rootNavigator: true,
                        ).pop();
                        try {
                          await characterService.exportAsPng(
                            activeCharacterFile,
                          );
                        } on Exception catch (e, st) {
                          LoggingService().error('PNG export failed', e, st);
                          NavigationService().showSnackBar(
                            AppConstants.exportFailedMessage,
                          );
                        }
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.data_object),
                      title: const Text('Export as JSON (V3)'),
                      onTap: () async {
                        Navigator.of(
                          navContext,
                          rootNavigator: true,
                        ).pop();
                        try {
                          await characterService.exportAsJson(
                            activeCharacterFile,
                          );
                        } on Exception catch (e, st) {
                          LoggingService().error('JSON V3 export failed', e, st);
                          NavigationService().showSnackBar(
                            AppConstants.exportFailedMessage,
                          );
                        }
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.data_object),
                      title: const Text('Export as JSON (V2)'),
                      onTap: () async {
                        Navigator.of(
                          navContext,
                          rootNavigator: true,
                        ).pop();
                        try {
                          await characterService.exportAsJson(
                            activeCharacterFile,
                            asV2: true,
                          );
                        } on Exception catch (e, st) {
                          LoggingService().error('JSON V2 export failed', e, st);
                          NavigationService().showSnackBar(
                            AppConstants.exportFailedMessage,
                          );
                        }
                      },
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

  /// Shared shape for the Video / Image / Web boolean rows: each one wraps
  /// a [DrawerSwitchTile] in a [ListenableBuilder] for the chat controller,
  /// reads the current value off the active session, and writes back via
  /// `updateSelectedChatSettings`. The 10 inline copies of this pattern
  /// differ only in icon, label, and which `configMedia` field they touch.
  // Small per-drawer tile builder; a shared widget would need ~10 call
  // sites here re-routed through an explicit controller param.
  // ignore: qcheck/avoid_returning_widgets
  Widget _sessionSwitchTile({
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
}

/// Sections in the chat drawer that have an expandable "advanced" group.
/// The persisted `AppSettings.drawerSectionAdvanced` map keys by [name]
/// (Chat Theme and Web are intentionally absent — neither has advanced
/// rows, so they do not render an expander).
enum _DrawerSectionEnum { chat, speech, video, image }
