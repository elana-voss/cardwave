import 'dart:async';
import 'dart:ui';

import 'package:cardwave/character/character.dart';
import 'package:cardwave/chat/chat.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/editor/editor.dart';
import 'package:cardwave/llm_app/llm_app.dart';
import 'package:cardwave/memory/memory.dart';
import 'package:cardwave/settings/settings.dart';
import 'package:cardwave/workspace/src/controllers/workspace_controller.dart';
import 'package:cardwave/workspace/src/models/chat_page_mode_enum.dart';
import 'package:cardwave/workspace/src/models/workspace_base_enum.dart';
import 'package:cardwave/workspace/src/pages/widgets/image_thumbnail_styled.dart';
import 'package:cardwave/workspace/src/pages/widgets/workspace_split_pane.dart';
import 'package:cardwave/workspace/src/pages/widgets/workspace_switch_character.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

part 'widgets/workspace_page/workspace_body.dart';
part 'widgets/workspace_page/workspace_end_drawer.dart';
part 'widgets/workspace_page/workspace_end_drawer_ai.dart';
part 'widgets/workspace_page/workspace_end_drawer_chat.dart';
part 'widgets/workspace_page/workspace_end_drawer_chat_theme.dart';
part 'widgets/workspace_page/workspace_end_drawer_display.dart';
part 'widgets/workspace_page/workspace_end_drawer_editing.dart';
part 'widgets/workspace_page/workspace_end_drawer_export.dart';
part 'widgets/workspace_page/workspace_end_drawer_image.dart';
part 'widgets/workspace_page/workspace_end_drawer_names.dart';
part 'widgets/workspace_page/workspace_end_drawer_speech.dart';
part 'widgets/workspace_page/workspace_end_drawer_video.dart';
part 'widgets/workspace_page/workspace_end_drawer_web.dart';

class WorkspacePage extends StatefulWidget {
  const WorkspacePage({
    required this.characterFile,
    super.key,
    this.initialBase = WorkspaceBaseEnum.chat,
  });
  final CharacterFile characterFile;
  final WorkspaceBaseEnum initialBase;

  @override
  State<WorkspacePage> createState() => _WorkspacePageState();
}

class _WorkspacePageState extends State<WorkspacePage> {
  final GlobalKey<EditorViewState> _editorKey = GlobalKey<EditorViewState>();

  late final WorkspaceController _workspaceController;
  late final ChatPageController _primaryChatController;
  late final ChatPageController _assistantChatController;
  late final EditorPageController _editorController;

  @override
  void initState() {
    super.initState();
    _workspaceController = WorkspaceController(initialBase: widget.initialBase);
    _workspaceController.addListener(_onWorkspaceModeChanged);

    _primaryChatController = ChatPageController(
      characterFile: widget.characterFile,
      chatService: context.read<ChatService>(),
      characterService: context.read<CharacterService>(),
      settingsService: context.read<SettingsService>(),
    );

    _assistantChatController = ChatPageController(
      characterFile: widget.characterFile,
      isAssistant: true,
      chatService: context.read<ChatService>(),
      characterService: context.read<CharacterService>(),
      settingsService: context.read<SettingsService>(),
    );

    _editorController = EditorPageController(
      characterFile: widget.characterFile,
      characterService: context.read<CharacterService>(),
      characterAiService: context.read<CharacterAiService>(),
      pureHelpers: context.read<LlmPureHelpers>(),
      settingsService: context.read<SettingsService>(),
    );
  }

  void _onWorkspaceModeChanged() {}

  @override
  void dispose() {
    _workspaceController.removeListener(_onWorkspaceModeChanged);
    _workspaceController.dispose();
    _primaryChatController.dispose();
    _assistantChatController.dispose();
    _editorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideScreen =
            constraints.maxWidth >= AppConstants.tabletBreakpoint;

        return PopScope(
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) {
              unawaited(
                context
                    .read<CharacterService>()
                    .flushJsonInCacheAndPngIfDirtyOrPending(
                      widget.characterFile,
                    ),
              );
            }
          },
          child: MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: _workspaceController),
              ChangeNotifierProvider.value(value: _primaryChatController),
              ChangeNotifierProvider.value(value: _editorController),
            ],
            child:
                Consumer3<
                  WorkspaceController,
                  ChatPageController,
                  EditorPageController
                >(
                  builder:
                      (
                        context,
                        workspace,
                        primaryChatController,
                        editorController,
                        child,
                      ) {
                        final mode = workspace.effectiveMode(isWideScreen);
                        final visibleChatController =
                            mode == ChatPageModeEnum.splitEditorAssistant
                            ? _assistantChatController
                            : primaryChatController;
                        final activeCharacterFile =
                            mode == ChatPageModeEnum.splitEditorAssistant
                            ? _assistantChatController.characterFile
                            : widget.characterFile;

                        final settingsService = context
                            .watch<SettingsService>();
                        final settings = settingsService.settings;
                        final isImageVisible =
                            workspace.base == WorkspaceBaseEnum.chat
                            ? settings.chatImageVisible
                            : settings.editorImageVisible;

                        final PreferredSizeWidget appBar =
                            workspace.base == WorkspaceBaseEnum.editor
                            ? AppBarEditor(
                                characterFile: widget.characterFile,
                                onTitleTap: () =>
                                    WorkspaceSwitchCharacter.switchCharacterInWorkspace(
                                      context,
                                      currentCharacterFile:
                                          widget.characterFile,
                                    ),
                                isSmallScreen: !isWideScreen,
                              )
                            : AppBarChat(
                                characterFile: widget.characterFile,
                                isWideScreen: isWideScreen,
                              );

                        return AppScaffold(
                          resizeToAvoidBottomInset: !kIsWeb,
                          appBar: appBar,
                          endDrawer: _WorkspaceEndDrawer(
                            visibleChatController: visibleChatController,
                            activeCharacterFile: activeCharacterFile,
                            allChatsList: _AllChatsList(
                              primaryChatController: primaryChatController,
                              characterFile: widget.characterFile,
                            ),
                            isWideScreen: isWideScreen,
                            onApplyCleaner: (processor) => _editorKey
                                .currentState
                                ?.applyCleaner(processor),
                            onGlobalAiAction: (action) => _editorKey
                                .currentState
                                ?.runGlobalAiAction(action),
                          ),
                          body: _WorkspaceBody(
                            mode: mode,
                            isWideScreen: isWideScreen,
                            isImageVisible: isImageVisible,
                            characterFile: widget.characterFile,
                            primaryChat: _PrimaryChat(
                              primaryChatController: primaryChatController,
                              characterFile: widget.characterFile,
                            ),
                            editor: _CharacterEditor(
                              editorController: editorController,
                              characterFile: widget.characterFile,
                              // isSmallScreen: isSmallScreen,
                              editorKey: _editorKey,
                            ),
                            assistantChat: _AssistantChat(
                              assistantChatController: _assistantChatController,
                              editorController: editorController,
                            ),
                          ),
                        );
                      },
                ),
          ),
        );
      },
    );
  }
}

class _AllChatsList extends StatelessWidget {
  const _AllChatsList({
    required this.primaryChatController,
    required this.characterFile,
  });
  final ChatPageController primaryChatController;
  final CharacterFile characterFile;

  @override
  Widget build(BuildContext context) {
    return AllChatsDrawerList(
      characterFile: characterFile,
      selectedChatId: primaryChatController.selectedChat?.id,
      onChatSelected: (entry) {
        unawaited(() async {
          await primaryChatController.selectChat(entry.id);
          if (!context.mounted) return;
          Navigator.of(context, rootNavigator: true).pop();
        }());
      },
      onChatDeleted: (deletedChatId) {
        if (primaryChatController.selectedChat?.id == deletedChatId) {
          primaryChatController.clearSelectedChat();
          unawaited(primaryChatController.reloadLatestChat());
          if (context.mounted) {
            Navigator.of(context, rootNavigator: true).pop();
          }
        }
      },
    );
  }
}

class _PrimaryChat extends StatelessWidget {
  const _PrimaryChat({
    required this.primaryChatController,
    required this.characterFile,
  });
  final ChatPageController primaryChatController;
  final CharacterFile characterFile;

  @override
  Widget build(BuildContext context) {
    final chatTheme = context.select<SettingsService, ChatTheme>(
      (s) => s.settings.chatTheme,
    );

    if (primaryChatController.isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (primaryChatController.isRebuildingIndex) ...[
              const SizedBox(height: 16),
              const Text('Rebuilding chat index...'),
            ],
          ],
        ),
      );
    }
    if (primaryChatController.selectedChat == null) {
      return const Center(child: Text('Select a chat to start messaging'));
    }
    return ChangeNotifierProvider<BaseChatViewController>(
      key: ValueKey(primaryChatController.selectedChat!.id),
      create: (ctx) => ChatController(
        chatSession: primaryChatController.selectedChat!,
        characterFile: characterFile,
        chatService: ctx.read<ChatService>(),
        characterService: ctx.read<CharacterService>(),
        settingsService: ctx.read<SettingsService>(),
        pureHelpers: ctx.read<LlmPureHelpers>(),
        promptRepository: ctx.read<PromptRepository>(),
        chatExecutionService: ctx.read<ChatExecutionService>(),
        textToSpeechService: ctx.read<TextToSpeechController>(),
        imageGenerationService: ctx.read<ImageGenerationService>(),
        videoGenerationService: ctx.read<VideoGenerationController>(),
        videoPromptBuilder: ctx.read<VideoPromptBuilder>(),
        toolDispatcher: ctx.read<ToolDispatcher>(),
        chatRepository: ctx.read<ChatRepository>(),
        memoryService: ctx.read<CardwaveMemoryModule>().memoryService,
      ),
      child: ChatView(
        characterFile: characterFile,
        theme: chatTheme,
        onNewChat: () => primaryChatController.promptNewChat(context),
      ),
    );
  }
}

class _CharacterEditor extends StatelessWidget {
  const _CharacterEditor({
    required this.editorController,
    required this.characterFile,
    required this.editorKey,
  });
  final EditorPageController editorController;
  final CharacterFile characterFile;
  final GlobalKey<EditorViewState> editorKey;

  @override
  Widget build(BuildContext context) {
    return EditorView(
      key: editorKey,
      characterFile: characterFile,
      selectedPanel: editorController.selectedPanel,
      onPanelChanged: editorController.setSelectedPanel,
    );
  }
}

class _AssistantChat extends StatelessWidget {
  const _AssistantChat({
    required this.assistantChatController,
    required this.editorController,
  });
  final ChatPageController assistantChatController;
  final EditorPageController editorController;

  @override
  Widget build(BuildContext context) {
    final chatTheme = context.select<SettingsService, ChatTheme>(
      (s) => s.settings.chatTheme,
    );

    return ListenableBuilder(
      listenable: assistantChatController,
      builder: (context, _) {
        LoggingService().info(
          '_AssistantChat.build: isLoading=${assistantChatController.isLoading} '
          'selectedChatId=${assistantChatController.selectedChat?.id ?? '(none)'} '
          'selectedChatMsgs=${assistantChatController.selectedChat?.messages.length ?? 0} '
          'file="${assistantChatController.characterFile.card.name}"',
        );
        if (assistantChatController.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (assistantChatController.selectedChat == null) {
          return const Center(child: Text('Failed to load assistant.'));
        }
        return ChangeNotifierProvider<BaseChatViewController>(
          key: ValueKey(assistantChatController.selectedChat!.id),
          create: (ctx) => ChatController(
            chatSession: assistantChatController.selectedChat!,
            characterFile: assistantChatController.characterFile,
            chatService: ctx.read<ChatService>(),
            characterService: ctx.read<CharacterService>(),
            settingsService: ctx.read<SettingsService>(),
            pureHelpers: ctx.read<LlmPureHelpers>(),
            promptRepository: ctx.read<PromptRepository>(),
            chatExecutionService: ctx.read<ChatExecutionService>(),
            textToSpeechService: ctx.read<TextToSpeechController>(),
            imageGenerationService: ctx.read<ImageGenerationService>(),
            videoGenerationService: ctx.read<VideoGenerationController>(),
            videoPromptBuilder: ctx.read<VideoPromptBuilder>(),
            toolDispatcher: ctx.read<ToolDispatcher>(),
            chatRepository: ctx.read<ChatRepository>(),
            memoryService: ctx.read<CardwaveMemoryModule>().memoryService,
            dataContextProvider: editorController.getCharacterDataJson,
          ),
          child: ChatView(
            characterFile: assistantChatController.characterFile,
            theme: chatTheme,
            onNewChat: () => assistantChatController.promptNewChat(context),
          ),
        );
      },
    );
  }
}
