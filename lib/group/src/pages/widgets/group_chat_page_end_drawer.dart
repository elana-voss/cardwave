part of '../group_chat_page.dart';

class _GroupChatEndDrawer extends StatelessWidget {
  const _GroupChatEndDrawer();

  @override
  Widget build(BuildContext context) {
    // Read (not watch) as references: the drawer body wraps everything in
    // `ListenableBuilder(listenable: …)` and passes the controller into
    // callbacks — the reactivity is there, not in this read.
    // ignore: qcheck/avoid_read_inside_build
    final controller = context.read<GroupChatController>();
    // ignore: qcheck/avoid_read_inside_build
    final settingsService = context.read<SettingsService>();

    return AppEndDrawer(
      chatSpecificMenuBuilder: (navContext) => ListenableBuilder(
        listenable: settingsService,
        builder: (context, _) {
          final settings = settingsService.settings;
          bool isAdv(_GroupSectionEnum section) =>
              settings.drawerSectionAdvanced['group_${section.name}'] ?? false;
          void toggleAdv(_GroupSectionEnum section) => unawaited(
            settingsService.setDrawerSectionAdvanced(
              'group_${section.name}',
              !isAdv(section),
            ),
          );
          return IconTheme.merge(
            data: const IconThemeData(size: 20),
            child: ListTileTheme(
              data: const ListTileThemeData(dense: true),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.edit_note),
                    title: const Text('Group overrides'),
                    subtitle: const Text(
                      'Shared scenario, main prompt, example dialogue',
                    ),
                    onTap: () {
                      Navigator.of(navContext, rootNavigator: true).pop();
                      unawaited(
                        NavigationService().showGroupOverridesDialog(
                          controller: controller,
                        ),
                      );
                    },
                  ),
                  // Media Defaults link — parallel to 1:1's top-of-drawer
                  // entry. Opens the per-session media-defaults grid.
                  ListenableBuilder(
                    listenable: controller,
                    builder: (context, _) {
                      final selectedChat = controller.selectedChat;
                      return MediaDefaultsDrawerEntry(
                        subtitle: 'Chat session',
                        onTap: () {
                          Navigator.of(context, rootNavigator: true).pop();
                          unawaited(
                            DialogAiSettings.show(
                              context,
                              initialTab: DialogAiSettingsTab.mediaDefaults,
                              mediaFocus:
                                  MediaSettingsGridFocus.allColumns,
                              chatSession: selectedChat,
                            ),
                          );
                        },
                      );
                    },
                  ),
                  const Divider(height: 1, thickness: 0.5),
                  // Quick actions — three of 1:1's four (no Favorite: group
                  // has multiple characters and no single favorite target).
                  ListenableBuilder(
                    listenable: controller,
                    builder: (context, _) {
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
                              unawaited(controller.promptNewChat(context));
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
                  // ── Group ──
                  const DrawerSectionHeader('Group'),
                  ListenableBuilder(
                    listenable: controller,
                    builder: (context, _) => TileAutoChatDelay(
                      value: controller.autoChatDelay,
                      onChanged: (v) => controller.autoChatDelay = v,
                    ),
                  ),
                  TileActivationStrategy(
                    value: settings.groupActivationStrategy,
                    onChanged: (v) {
                      settings.groupActivationStrategy = v;
                      unawaited(settingsService.saveSettings());
                    },
                  ),
                  // ── Chat ──
                  const DrawerSectionHeader('Chat'),
                  ListenableBuilder(
                    listenable: controller,
                    builder: (context, _) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TileNsfw(
                          chatSession: controller.selectedChat,
                          onChanged: (value) => controller
                              .updateSelectedChatSettings(isNsfw: value),
                        ),
                        TileScenario(
                          chatSession: controller.selectedChat,
                          onChanged: (value) => controller
                              .updateSelectedChatSettings(isScenario: value),
                        ),
                        TileAiProvider(
                          chatSession: controller.selectedChat,
                          characterFile: null,
                          onChanged: controller.refresh,
                        ),
                        if (isAdv(_GroupSectionEnum.chat)) ...[
                          TileTrailingParagraph(
                            chatSession: controller.selectedChat,
                            onChanged: (value) =>
                                controller.updateSelectedChatSettings(
                                  removeTrailingSentences: value,
                                ),
                          ),
                          TileMaxResponseLength(
                            chatSession: controller.selectedChat,
                          ),
                          TileReasoningEffort(
                            chatSession: controller.selectedChat,
                          ),
                        ],
                      ],
                    ),
                  ),
                  DrawerShowAdvanced(
                    expanded: isAdv(_GroupSectionEnum.chat),
                    onToggle: () => toggleAdv(_GroupSectionEnum.chat),
                  ),
                  // ── Chat Theme ──
                  const DrawerSectionHeader('Chat Theme'),
                  TileChatTheme(
                    settings: settings,
                    onThemeChanged: (theme) {
                      settings.chatTheme = theme;
                      unawaited(settingsService.saveSettings());
                    },
                  ),
                  // ── Speech ──
                  const DrawerSectionHeader('Speech'),
                  ListenableBuilder(
                    listenable: controller,
                    builder: (context, _) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TileTtsPreset(
                          chatSession: controller.selectedChat,
                          onChanged: controller.persistSession,
                        ),
                        TileTtsVoice(
                          chatSession: controller.selectedChat,
                          onChanged: controller.persistSession,
                        ),
                        if (isAdv(_GroupSectionEnum.speech))
                          TileTtsLanguage(
                            chatSession: controller.selectedChat,
                            onChanged: controller.persistSession,
                          ),
                      ],
                    ),
                  ),
                  DrawerShowAdvanced(
                    expanded: isAdv(_GroupSectionEnum.speech),
                    onToggle: () => toggleAdv(_GroupSectionEnum.speech),
                  ),
                  // ── Video ──
                  // Video Style (per-character `videoPromptPrefix`) is
                  // intentionally omitted: groups have multiple characters
                  // so there's no single character to attach the prefix to.
                  const DrawerSectionHeader('Video'),
                  _sessionSwitchTile(
                    controller: controller,
                    icon: Icons.shield,
                    title: 'Unrestricted Videos',
                    subtitle: 'Allow NSFW video prompts',
                    read: (s) => s.configMedia?.videoNsfwAllowed ?? false,
                    write: (v) => controller.updateSelectedChatSettings(
                      videoNsfwAllowed: v,
                    ),
                  ),
                  _sessionSwitchTile(
                    controller: controller,
                    icon: Icons.movie_creation,
                    title: 'Character Can Send Videos',
                    subtitle: 'Attach a short video when natural',
                    read: (s) => s.configMedia?.videoToolSendAllowed ?? false,
                    write: (v) => controller.updateSelectedChatSettings(
                      videoToolSendAllowed: v,
                    ),
                  ),
                  if (isAdv(_GroupSectionEnum.video)) ...[
                    _sessionSwitchTile(
                      controller: controller,
                      icon: Icons.rate_review,
                      title: 'Review Video Prompt',
                      subtitle: 'Edit before generating',
                      read: (s) => s.configMedia?.videoPromptReview ?? false,
                      write: (v) => controller.updateSelectedChatSettings(
                        videoPromptReview: v,
                      ),
                    ),
                    ListenableBuilder(
                      listenable: controller,
                      builder: (context, _) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TileVideoPreset(
                            chatSession: controller.selectedChat,
                            onChanged: controller.persistSession,
                          ),
                          TileVideoResolution(
                            chatSession: controller.selectedChat,
                            onChanged: controller.persistSession,
                          ),
                          TileVideoAspectRatio(
                            chatSession: controller.selectedChat,
                            onChanged: controller.persistSession,
                          ),
                          TileVideoDuration(
                            chatSession: controller.selectedChat,
                            onChanged: controller.persistSession,
                          ),
                        ],
                      ),
                    ),
                  ],
                  DrawerShowAdvanced(
                    expanded: isAdv(_GroupSectionEnum.video),
                    onToggle: () => toggleAdv(_GroupSectionEnum.video),
                  ),
                  // ── Image ──
                  _GroupImageSection(
                    controller: controller,
                    isAdvanced: isAdv(_GroupSectionEnum.image),
                    onToggleAdvanced: () => toggleAdv(_GroupSectionEnum.image),
                  ),
                  // ── Web ──
                  _GroupWebSection(controller: controller),
                  // ── Names ──
                  _GroupNamesSection(controller: controller),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

}

/// Group-flavor of the chat drawer's `_sessionSwitchTile`. Same shape;
/// captures `GroupChatController` instead of `ChatPageController`. Top-level
/// so every section part (Video, Image, Web, Names) can share it without
/// each having to redeclare the helper.
// ignore: qcheck/avoid_returning_widgets
Widget _sessionSwitchTile({
  required GroupChatController controller,
  required IconData icon,
  required String title,
  required String subtitle,
  required bool Function(ChatSession) read,
  required void Function(bool) write,
}) {
  return ListenableBuilder(
    listenable: controller,
    builder: (context, _) => DrawerSwitchTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      value: read(controller.selectedChat),
      onChanged: write,
    ),
  );
}

/// Sections in the group drawer that have an expandable "advanced" group.
/// Storage keys are prefixed `group_${name}` to avoid sharing expand state
/// with the 1:1 chat drawer's identically-named sections.
enum _GroupSectionEnum { chat, speech, video, image }
