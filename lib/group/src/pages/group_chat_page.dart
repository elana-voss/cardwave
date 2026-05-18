import 'dart:async';

import 'package:cardwave/character/character.dart';
import 'package:cardwave/chat/chat.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/group/src/controllers/group_chat_controller.dart';
import 'package:cardwave/group/src/pages/widgets/group_character_drawer.dart';
import 'package:cardwave/group/src/pages/widgets/group_switch_dialog.dart';
import 'package:cardwave/group/src/pages/widgets/tile_activation_strategy.dart';
import 'package:cardwave/group/src/pages/widgets/tile_auto_chat_delay.dart';
import 'package:cardwave/group/src/services/group_chat_service.dart';
import 'package:cardwave/group/src/services/group_file_service.dart';
import 'package:cardwave/group/src/services/group_prompt_service.dart';
import 'package:cardwave/llm_app/llm_app.dart';
import 'package:cardwave/settings/settings.dart';
import 'package:cardwave/workspace/workspace.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

part 'widgets/group_chat_page_end_drawer.dart';
part 'widgets/group_chat_page_end_drawer_image.dart';
part 'widgets/group_chat_page_end_drawer_names.dart';
part 'widgets/group_chat_page_end_drawer_web.dart';

class GroupChatPage extends StatefulWidget {
  const GroupChatPage({required this.groupId, super.key});
  final String groupId;

  @override
  State<GroupChatPage> createState() => _GroupChatPageState();
}

class _GroupChatPageState extends State<GroupChatPage> {
  GroupChatController? _controller;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    try {
      final settings = context.read<SettingsService>();
      final userName = settings.settings.activePersona.name;

      final groupFileService = context.read<GroupFileService>();
      final groupChatService = context.read<GroupChatService>();
      final groupPromptService = context.read<GroupPromptService>();
      final executionService = context.read<ChatExecutionService>();
      final promptRepository = context.read<PromptRepository>();
      final characterService = context.read<CharacterService>();
      final imageGenerationService = context.read<ImageGenerationService>();
      final videoGenerationService = context.read<VideoGenerationController>();
      final videoPromptBuilder = context.read<VideoPromptBuilder>();
      final textToSpeechService = context.read<TextToSpeechController>();
      final toolDispatcher = context.read<ToolDispatcher>();
      final pureHelpers = context.read<LlmPureHelpers>();
      final chatRepository = context.read<ChatRepository>();

      // Ensure the global character list is populated before we resolve
      // group members — the user may open group chat before visiting the
      // character grid, in which case characterFiles would be empty.
      if (characterService.characterFiles.isEmpty) {
        await characterService.loadCharacters();
      }

      // Load (or create) the persistent group definition.
      final groupFile = await groupFileService.loadOrCreate(
        widget.groupId,
        name: 'Group Chat',
      );

      // Load the latest chat session for this group; create a fresh one if
      // none exists yet.
      var session = await groupChatService.getLatestChatForGroup(groupFile.id);
      final chatPresetId =
          settings.settings.domainPresetIds[LlmProviderDomainEnum.chat] ?? '';
      session ??= groupChatService.createChat(
        groupFile: groupFile,
        chatPresetId: chatPresetId,
        userName: userName,
      );

      if (!mounted) return;

      setState(() {
        _controller = GroupChatController(
          groupFile: groupFile,
          session: session!,
          groupPromptService: groupPromptService,
          groupFileService: groupFileService,
          groupChatService: groupChatService,
          executionService: executionService,
          settingsService: settings,
          pureHelpers: pureHelpers,
          promptRepository: promptRepository,
          characterService: characterService,
          imageGenerationService: imageGenerationService,
          videoGenerationService: videoGenerationService,
          videoPromptBuilder: videoPromptBuilder,
          textToSpeechService: textToSpeechService,
          toolDispatcher: toolDispatcher,
          chatRepository: chatRepository,
          userName: userName,
        );
      });
    } on Exception catch (e) {
      if (mounted) setState(() => _loadError = e);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Group Chat')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Failed to load group chat:\n$_loadError'),
          ),
        ),
      );
    }

    final controller = _controller;
    if (controller == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<GroupChatController>.value(value: controller),
        ChangeNotifierProvider<BaseChatViewController>.value(value: controller),
      ],
      child: const _GroupChatScaffold(),
    );
  }
}

class _GroupChatScaffold extends StatelessWidget {
  const _GroupChatScaffold();

  @override
  Widget build(BuildContext context) {
    final isWide =
        MediaQuery.sizeOf(context).width >= AppConstants.tabletBreakpoint;

    return AppScaffold(
      drawer: isWide ? null : const GroupCharacterDrawer(),
      endDrawer: const _GroupChatEndDrawer(),
      appBar: _GroupChatAppBar(isWide: isWide),
      resizeToAvoidBottomInset: !kIsWeb,
      body: isWide ? const _WideLayout() : const _NarrowChatBody(),
    );
  }
}

class _GroupChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _GroupChatAppBar({required this.isWide});
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GroupChatController>();
    final hasCharacters = controller.characters.isNotEmpty;
    final isAuto = controller.isAutoChatActive;
    final isGenerating = controller.isGenerating;
    final errorColor = Theme.of(context).colorScheme.error;

    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.grid_view_rounded),
        onPressed: () => Navigator.pop(context),
      ),
      title: AppBarSwitcherTitle(
        displayName: controller.groupFile.group.name,
        onTap: () => GroupSwitchDialog.show(context),
      ),
      actions: [
        if (!isWide)
          Builder(
            builder: (ctx) => IconButton(
              key: const Key('group-characters-drawer'),
              icon: const Icon(Icons.group),
              tooltip: 'Characters',
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            ),
          ),
        IconButton(
          key: const Key('group-next-turn'),
          icon: const Icon(Icons.skip_next),
          tooltip: 'Next turn',
          onPressed: (hasCharacters && !isGenerating && !isAuto)
              ? controller.generateReply
              : null,
        ),
        IconButton(
          key: const Key('group-auto-chat-toggle'),
          icon: Icon(
            isAuto ? Icons.stop_circle_outlined : Icons.play_circle_outline,
            color: isAuto ? errorColor : null,
          ),
          tooltip: isAuto ? 'Stop auto-chat' : 'Start auto-chat',
          onPressed: hasCharacters
              ? (isAuto
                    ? controller.stopAutoChat
                    : (isGenerating ? null : controller.startAutoChat))
              : null,
        ),
        if (isGenerating)
          IconButton(
            icon: const Icon(Icons.cancel_outlined),
            tooltip: 'Stop generation',
            onPressed: controller.stopGeneration,
          ),
        const SettingsGearMenu(),
        Builder(
          builder: (ctx) => IconButton(
            key: const Key('appbar-end-drawer'),
            icon: const Icon(Icons.menu),
            tooltip: 'Settings',
            onPressed: () => Scaffold.of(ctx).openEndDrawer(),
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

/// Narrow-screen body: blurred background of the first character behind ChatView.
class _NarrowChatBody extends StatelessWidget {
  const _NarrowChatBody();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GroupChatController>();
    if (controller.characters.isEmpty) {
      return _GroupEmptyState(
        icon: Icons.group_add,
        text: 'This group has no characters yet.',
        action: Builder(
          builder: (context) => FilledButton.icon(
            key: const Key('group-add-character'),
            icon: const Icon(Icons.add),
            label: const Text('Add a character'),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      );
    }
    final firstChar = controller.characters.first;
    final theme = context.select<SettingsService, ChatTheme>(
      (s) => s.settings.chatTheme,
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(child: ImageBackgroundBlurred(character: firstChar)),
        ChatView(theme: theme, onNewChat: controller.clearChat),
      ],
    );
  }
}

class _WideLayout extends StatelessWidget {
  const _WideLayout();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GroupChatController>();
    final isEmpty = controller.characters.isEmpty;
    // Guarded by `isEmpty` above.
    // ignore: qcheck/avoid_unsafe_collection_methods
    final firstChar = isEmpty ? null : controller.characters.first;
    final lastSpeaker = controller.lastSpeaker;
    final theme = context.select<SettingsService, ChatTheme>(
      (s) => s.settings.chatTheme,
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        if (firstChar != null)
          Positioned.fill(child: ImageBackgroundBlurred(character: firstChar)),
        Row(
          children: [
            const Expanded(
              child: GroupCharacterDrawer(embedded: true),
            ),
            Expanded(
              flex: 2,
              child: isEmpty
                  ? const _GroupEmptyState(
                      icon: Icons.arrow_back,
                      text: 'Pick a character from the list on the left.',
                    )
                  : ChatView(theme: theme, onNewChat: controller.clearChat),
            ),
            Expanded(
              child: lastSpeaker == null
                  ? const SizedBox.shrink()
                  : ImageThumbnailStyled(file: lastSpeaker),
            ),
          ],
        ),
      ],
    );
  }
}

class _GroupEmptyState extends StatelessWidget {
  const _GroupEmptyState({required this.icon, required this.text, this.action});
  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      // Non-uniform: `SizedBox(16)` and conditional `SizedBox(24)`;
      // single `spacing:` can't express both.
      // ignore: qcheck/prefer_spacing
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          Text(text),
          if (action != null) ...[const SizedBox(height: 24), action!],
        ],
      ),
    );
  }
}
