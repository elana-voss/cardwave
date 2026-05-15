import 'dart:async';

import 'package:cardwave/character/character.dart';
import 'package:cardwave/chat/src/controllers/base_chat_view_controller.dart';
import 'package:cardwave/chat/src/controllers/mixins/chat_image_generation_mixin.dart';
import 'package:cardwave/chat/src/controllers/mixins/chat_video_generation_mixin.dart';
import 'package:cardwave/chat/src/controllers/text_to_speech_controller.dart';
import 'package:cardwave/chat/src/controllers/video_generation_controller.dart';
import 'package:cardwave/chat/src/models/bubble_waiting_for_enum.dart';
import 'package:cardwave/chat/src/models/chat_message.dart';
import 'package:cardwave/chat/src/models/chat_session.dart';
import 'package:cardwave/chat/src/models/chat_swipe.dart';
import 'package:cardwave/chat/src/models/generation_event.dart';
import 'package:cardwave/chat/src/repositories/chat_repository.dart';
import 'package:cardwave/chat/src/services/chat_execution_service.dart';
import 'package:cardwave/chat/src/services/chat_service.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/llm_app/llm_app.dart';
import 'package:cardwave/settings/settings.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:cardwave_storage/cardwave_storage.dart';
import 'package:flutter/material.dart';

class ChatController extends BaseChatViewController
    with ChatVideoGenerationMixin, ChatImageGenerationMixin {
  ChatController({
    required this.chatSession,
    required this.characterFile,
    required this.chatService,
    required this.characterService,
    required this.settingsService,
    required this.pureHelpers,
    required this.promptRepository,
    required this.chatExecutionService,
    required this.textToSpeechService,
    required this.imageGenerationService,
    required this.videoGenerationService,
    required this.videoPromptBuilder,
    required this.toolDispatcher,
    required this.chatRepository,
    this.dataContextProvider,
  }) {
    scrollController.addListener(_onScroll);
    final providers = settingsService.settings.providerConfigs;
    validateConfigMediaSession(
      session: chatSession,
      providers: providers,
      pureHelpers: pureHelpers,
    );
    validateConfigMediaCharacter(
      character: characterFile,
      providers: providers,
      pureHelpers: pureHelpers,
    );
  }
  static final _sentenceBoundaryRE = RegExp('[.!?]+');

  @override
  final ChatSession chatSession;
  final CharacterFile characterFile;
  final ChatService chatService;
  final CharacterService characterService;
  final SettingsService settingsService;
  final LlmPureHelpers pureHelpers;
  final PromptRepository promptRepository;
  final ChatExecutionService chatExecutionService;
  final TextToSpeechController textToSpeechService;
  @override
  final ImageGenerationService imageGenerationService;
  @override
  final VideoGenerationController videoGenerationService;
  @override
  final VideoPromptBuilder videoPromptBuilder;
  @override
  final ToolDispatcher toolDispatcher;
  final ChatRepository chatRepository;

  @override
  final ScrollController scrollController = ScrollController();
  @override
  final TextEditingController inputController = TextEditingController();
  @override
  final FocusNode focusNode = FocusNode();
  @override
  final ValueNotifier<String> streamingContent = ValueNotifier('');

  String? Function()? dataContextProvider;

  @override
  bool isGenerating = false;
  bool isImpersonating = false;
  bool isImproving = false;
  ValueNotifier<bool>? _cancelToken;
  bool _isDisposed = false;
  bool _userDetached = false;
  @override
  bool get userDetached => _userDetached;

  @override
  String get chatsFolder => characterFile.appCardChatsFolder;

  // --- ChatImageGenerationMixin hooks ---

  @override
  SettingsService get imageGenSettingsService => settingsService;

  @override
  ChatSession get imageGenSession => chatSession;

  @override
  CharacterFile? get imageGenTargetCharacter => characterFile;

  @override
  String get imageGenUserName => chatSession.personaName.isNotEmpty
      ? chatSession.personaName
      : settingsService.settings.activePersona.name;

  @override
  String get imageGenChatDirectoryPath => characterFile.appCardChatsFolder;

  @override
  ChatRepository get imageGenChatRepository => chatRepository;

  @override
  void imageGenPersistSession() {
    unawaited(chatService.updateChat(characterFile, chatSession));
  }

  // --- ChatVideoGenerationMixin hooks ---

  @override
  LlmPureHelpers get videoGenLlmService => pureHelpers;

  @override
  SettingsService get videoGenSettingsService => settingsService;

  @override
  ChatSession get videoGenSession => chatSession;

  @override
  CharacterFile? get videoGenTargetCharacter => characterFile;

  @override
  String get videoGenUserName => chatSession.personaName.isNotEmpty
      ? chatSession.personaName
      : settingsService.settings.activePersona.name;

  @override
  void videoGenPersistSession() {
    unawaited(chatService.updateChat(characterFile, chatSession));
  }

  // --- Display name / character resolution ---

  /// 1:1 identity resolution is driven entirely by [ChatMessage.role].
  ///
  /// Every 1:1 session has exactly one character, stored on this controller
  /// as [characterFile]. Individual messages do not (and need not) carry a
  /// character id — the session context already implies it. We therefore
  /// ignore [ChatMessage.characterId] here and branch on the role:
  ///
  ///   - [ChatRoleEnum.user] → the user's persona name (session-cached, with a
  ///     fallback to the active persona in settings).
  ///   - anything else (assistant / character / system) → the session's
  ///     single character's nickname (preferred) or its canonical name.
  @override
  String resolveDisplayName(ChatMessage message) {
    if (message.role == ChatRoleEnum.user) {
      final personaName = chatSession.personaName;
      if (personaName.isNotEmpty) return personaName;
      return settingsService.settings.activePersona.name;
    }
    final card = characterFile.card;
    final nickname = card.nickname;
    return (nickname != null && nickname.isNotEmpty) ? nickname : card.name;
  }

  /// 1:1 messages are authored either by the user or by this session's sole
  /// [characterFile]; there is no per-message character lookup to perform.
  @override
  CharacterFile? resolveCharacterFile(ChatMessage message) {
    if (message.role == ChatRoleEnum.user) return null;
    return characterFile;
  }

  // --- Capability flags ---

  @override
  bool get supportsSwipe => true;
  @override
  bool get supportsImpersonation => true;
  @override
  bool get supportsContinue => true;
  @override
  bool get supportsImproveInput => true;

  @override
  bool get isProcessingInput => isImpersonating || isImproving;

  @override
  List<ChatMessage> get messages => chatSession.messages;

  @override
  void dispose() {
    _isDisposed = true;
    stopGeneration();
    scrollController.removeListener(_onScroll);
    scrollController.dispose();
    inputController.dispose();
    focusNode.dispose();
    streamingContent.dispose();
    super.dispose();
  }

  @override
  void jumpToBottom() {
    if (scrollController.hasClients) {
      scrollController.jumpTo(0);
    }
  }

  @override
  void scrollToBottom({bool animated = true, bool force = false}) {
    if (_isDisposed || !scrollController.hasClients) return;
    if (!force && _userDetached) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isDisposed || !scrollController.hasClients) return;
      if (animated) {
        unawaited(
          scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          ),
        );
      } else {
        scrollController.jumpTo(0);
      }
    });
  }

  void _onScroll() {
    if (!scrollController.hasClients) return;
    final pixels = scrollController.position.pixels;
    final nowDetached = pixels > AppConstants.chatScrollStickThreshold;
    if (nowDetached == _userDetached) return;
    final wasDetached = _userDetached;
    _userDetached = nowDetached;
    // On re-entry while streaming, snap to the live edge.
    if (wasDetached && !nowDetached && isGenerating) {
      jumpToBottom();
    }
    _notify();
  }

  /// Sends a user message and triggers the AI response generation.
  @override
  Future<void> sendMessage() async {
    final userMessageText = inputController.text.trim();
    if (userMessageText.isEmpty) {
      if (chatSession.messages.isNotEmpty &&
          chatSession.messages.last.role == ChatRoleEnum.user &&
          !isGenerating) {
        await _generateReply(dataContext: dataContextProvider?.call());
      }
      return;
    }

    final userMessage = ChatMessage(
      role: ChatRoleEnum.user,
      swipes: [
        ChatSwipe(
          content: userMessageText,
          tokenCount: await UtilsLlm.countTokens(userMessageText),
        ),
      ],
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    if (_isDisposed) return;

    chatSession.messages.add(userMessage);
    inputController.clear();
    _notify();
    scrollToBottom(force: true);

    unawaited(chatService.updateChat(characterFile, chatSession));

    if (_isDisposed) return;
    await _generateReply(dataContext: dataContextProvider?.call());
  }

  /// Regenerates the last assistant message.
  @override
  Future<void> regenerateLastMessage() async {
    if (chatSession.messages.isEmpty) return;
    final lastMsg = chatSession.messages.last;
    if (lastMsg.role != ChatRoleEnum.assistant) return;

    lastMsg.addSwipe('');
    lastMsg.tokenCount = null;
    _notify();
    scrollToBottom(force: true);

    unawaited(chatService.updateChat(characterFile, chatSession));

    if (_isDisposed) return;
    await _generateReply(
      existingMessage: lastMsg,
      dataContext: dataContextProvider?.call(),
    );
  }

  /// Forces the LLM to generate a reply to the current chat state.
  @override
  Future<void> generateReply() async {
    if (_isDisposed || isGenerating) return;
    await _generateReply(dataContext: dataContextProvider?.call());
  }

  /// Forces the LLM to continue its last message.
  @override
  Future<void> continueChat() async {
    if (_isDisposed || isGenerating || chatSession.messages.isEmpty) return;

    final lastAssistantIndex = chatSession.messages.lastIndexWhere(
      (m) => m.role == ChatRoleEnum.assistant,
    );
    if (lastAssistantIndex == -1) return;

    final lastAssistantMsg = chatSession.messages[lastAssistantIndex];
    final prompt = promptRepository.continueChat;

    final tempUserMsg = ChatMessage(
      role: ChatRoleEnum.user,
      swipes: [ChatSwipe(content: prompt)],
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    if (lastAssistantMsg.content.isNotEmpty &&
        !lastAssistantMsg.content.endsWith('\n')) {
      lastAssistantMsg.content += '\n\n';
    }

    await _generateReply(
      existingMessage: lastAssistantMsg,
      injectedMessage: tempUserMsg,
      dataContext: dataContextProvider?.call(),
    );
  }

  /// Forces the LLM to generate a message acting as the user.
  @override
  Future<void> impersonateUser() async {
    if (_isDisposed || isGenerating) return;

    final userName = chatSession.personaName.isNotEmpty
        ? chatSession.personaName
        : settingsService.settings.activePersona.name;
    final charName = characterFile.card.nickname?.isNotEmpty == true
        ? characterFile.card.nickname!
        : characterFile.card.name;

    final lengthConstraint = _calculateUserLengthConstraint();
    var prompt = promptRepository.impersonateUser;
    prompt = prompt.replaceAll('%USER_NAME%', userName);
    prompt = prompt.replaceAll('%CHAR_NAME%', charName);
    prompt = prompt.replaceAll('%LENGTH_CONSTRAINT%', lengthConstraint);

    final tempUserMsg = ChatMessage(
      role: ChatRoleEnum.user,
      swipes: [ChatSwipe(content: prompt)],
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    _cancelToken = ValueNotifier(false);
    isGenerating = true;
    isImpersonating = true;
    inputController.clear();
    _notify();
    scrollToBottom(force: true);

    var bufferedText = '';
    var lastUpdateMs = 0;

    try {
      final stream = chatExecutionService.generateChatReply(
        chatSession,
        characterFile,
        cancelToken: _cancelToken!,
        injectedMessage: tempUserMsg,
        isImpersonating: true,
        dataContext: dataContextProvider?.call(),
      );

      await for (final event in stream) {
        if (_isDisposed) break;
        if (event is GenerationTokenEvent) {
          bufferedText += event.token;
          if (bufferedText.trimLeft().isEmpty) {
            bufferedText = '';
            continue;
          }
          final now = DateTime.now().millisecondsSinceEpoch;
          if (now - lastUpdateMs > 250) {
            inputController.value = TextEditingValue(
              text: bufferedText,
              selection: TextSelection.collapsed(offset: bufferedText.length),
            );
            lastUpdateMs = now;
          }
        } else if (event is GenerationCompleteEvent) {
          bufferedText = event.finalContent;
        }
      }
    } on Exception catch (e, stackTrace) {
      if (_cancelToken?.value != true) {
        LoggingService().error(
          '1:1 chat: impersonateUser failed',
          e,
          stackTrace,
        );
        NavigationService().showSnackBar(UtilsLlm.extractUserFriendlyError(e));
      }
    } finally {
      var finalContent = bufferedText.trimRight();

      if (chatSession.removeTrailingSentences) {
        finalContent = chatService.trimTrailingParagraph(finalContent);
      }

      if (!_isDisposed) {
        inputController.value = TextEditingValue(
          text: finalContent,
          selection: TextSelection.collapsed(offset: finalContent.length),
        );
      }

      _cancelToken?.dispose();
      _cancelToken = null;
      isGenerating = false;
      isImpersonating = false;
      _notify();
    }
  }

  String _calculateUserLengthConstraint() {
    final recentUserMessages = chatSession.messages
        .where((m) => m.role == ChatRoleEnum.user && m.content.isNotEmpty)
        .toList();
    final recentHistory = recentUserMessages.length > 5
        ? recentUserMessages.sublist(recentUserMessages.length - 5)
        : recentUserMessages;

    if (recentHistory.isEmpty) {
      return ' Limit your response to approximately 1 paragraph.';
    }

    var totalParagraphs = 0;
    var totalSentences = 0;
    var usesParagraphs = false;

    for (final msg in recentHistory) {
      final content = msg.content.trim();
      final paragraphs = content
          .split('\n')
          .where((s) => s.trim().isNotEmpty)
          .length;
      if (paragraphs > 1) {
        usesParagraphs = true;
      }
      totalParagraphs += paragraphs;

      final sentences = content
          .split(_sentenceBoundaryRE)
          .where((s) => s.trim().isNotEmpty)
          .length;
      totalSentences += sentences > 0 ? sentences : 1;
    }

    if (usesParagraphs) {
      final avgParagraphs = (totalParagraphs / recentHistory.length).round();
      final unit = avgParagraphs == 1 ? 'paragraph' : 'paragraphs';
      return ' Limit your response to approximately $avgParagraphs $unit.';
    }
    final avgSentences = (totalSentences / recentHistory.length).round();
    final unit = avgSentences == 1 ? 'sentence' : 'sentences';
    return ' Limit your response to approximately $avgSentences $unit.';
  }

  /// Analyzes and improves the current user input via LLM.
  @override
  Future<void> improveInput() async {
    final rawInput = inputController.text.trim();
    if (rawInput.isEmpty || _isDisposed || isGenerating) return;

    final userName = chatSession.personaName.isNotEmpty
        ? chatSession.personaName
        : settingsService.settings.activePersona.name;
    final charName = characterFile.card.nickname?.isNotEmpty == true
        ? characterFile.card.nickname!
        : characterFile.card.name;

    var prompt = promptRepository.improveUserMessagePostHistory;
    prompt = prompt.replaceAll('%CURRENT_USER_MESSAGE%', rawInput);
    prompt = prompt.replaceAll('%USER_NAME%', userName);
    prompt = prompt.replaceAll('%CHAR_NAME%', charName);

    final originalInput = rawInput;
    _cancelToken = ValueNotifier(false);
    isGenerating = true;
    isImproving = true;
    inputController.clear();
    _notify();

    var bufferedText = '';
    var lastUpdateMs = 0;

    try {
      final stream = chatExecutionService.generateUtilityResponseWithHistory(
        chatSession,
        cancelToken: _cancelToken!,
        systemPrompt: promptRepository.improveUserMessagePreHistory,
        postHistoryPrompt: prompt,
      );

      await for (final event in stream) {
        if (_isDisposed || _cancelToken?.value == true) break;
        if (event is GenerationTokenEvent) {
          bufferedText += event.token;
          if (bufferedText.trimLeft().isEmpty) {
            bufferedText = '';
            continue;
          }
          final now = DateTime.now().millisecondsSinceEpoch;
          if (now - lastUpdateMs > 250) {
            inputController.value = TextEditingValue(
              text: bufferedText,
              selection: TextSelection.collapsed(offset: bufferedText.length),
            );
            lastUpdateMs = now;
          }
        } else if (event is GenerationCompleteEvent) {
          bufferedText = event.finalContent;
        }
      }
    } on Exception catch (e, stackTrace) {
      if (_cancelToken?.value != true) {
        LoggingService().error('1:1 chat: improveInput failed', e, stackTrace);
        NavigationService().showSnackBar(UtilsLlm.extractUserFriendlyError(e));
      }
    } finally {
      if (_cancelToken?.value == true) {
        if (!_isDisposed) {
          inputController.value = TextEditingValue(
            text: originalInput,
            selection: TextSelection.collapsed(offset: originalInput.length),
          );
        }
      } else {
        var finalContent = bufferedText.trim();

        finalContent = finalContent.replaceAll(RegExp(r'^"|"$'), '').trim();
        finalContent = finalContent
            .replaceAll(
              RegExp(
                r'^(Here is the improved message|Improved message|Improved):?\s*',
                caseSensitive: false,
              ),
              '',
            )
            .trim();

        if (!_isDisposed) {
          inputController.value = TextEditingValue(
            text: finalContent,
            selection: TextSelection.collapsed(offset: finalContent.length),
          );
        }
      }

      _cancelToken?.dispose();
      _cancelToken = null;
      isGenerating = false;
      isImproving = false;
      _notify();
    }
  }

  /// Core method for AI response generation.
  Future<void> _generateReply({
    ChatMessage? existingMessage,
    ChatMessage? injectedMessage,
    String? dataContext,
  }) async {
    _cancelToken = ValueNotifier(false);
    isGenerating = true;
    streamingContent.value = '';

    final assistantMessageToBeFilled =
        existingMessage ??
        ChatMessage(
          role: ChatRoleEnum.assistant,
          swipes: [ChatSwipe(content: '')],
          timestamp: DateTime.now().millisecondsSinceEpoch,
        );
    assistantMessageToBeFilled.waitingFor = BubbleWaitingForEnum.callingLlm;

    if (existingMessage == null) {
      chatSession.messages.add(assistantMessageToBeFilled);
    }

    _notify();
    scrollToBottom(force: true);

    var lastUpdateMs = 0;
    var bufferedText = '';

    try {
      final stream = chatExecutionService.generateChatReply(
        chatSession,
        characterFile,
        cancelToken: _cancelToken!,
        injectedMessage: injectedMessage,
        dataContext: dataContext,
        dispatchToolCalls: buildToolDispatch(
          targetMessage: assistantMessageToBeFilled,
        ),
      );

      await for (final event in stream) {
        if (_isDisposed) break;
        if (event is GenerationTokenEvent) {
          bufferedText += event.token;
          assistantMessageToBeFilled.waitingFor =
              BubbleWaitingForEnum.streamingText;
          // Throttle UI paints to ~4 Hz: LLMs can emit dozens of tokens per
          // second and pushing every one into streamingContent hammers the
          // widget tree with rebuilds and jank-induces autoscroll. The final
          // full content is painted once in the finally block.
          final now = DateTime.now().millisecondsSinceEpoch;
          if (now - lastUpdateMs > 250) {
            streamingContent.value = bufferedText;
            scrollToBottom(animated: false);
            lastUpdateMs = now;
          }
        } else if (event is GenerationTokenWipeEvent) {
          // Tool-using iteration ended — drop whatever was streamed so
          // the next iteration starts from a clean bubble. The model's
          // intermediate prose is not user-visible.
          bufferedText = '';
          streamingContent.value = '';
        } else if (event is GenerationToolLoopProgressEvent) {
          assistantMessageToBeFilled.waitingFor =
              BubbleWaitingForEnum.runningTool;
          assistantMessageToBeFilled.waitingForLabel = event.label;
        } else if (event is GenerationCompleteEvent) {
          assistantMessageToBeFilled.content = event.finalContent;
          assistantMessageToBeFilled.rawPrompt = event.rawPrompt;
          assistantMessageToBeFilled.generationTime = event.generationTime;
          assistantMessageToBeFilled.tokenCount = event.tokenCount;
          assistantMessageToBeFilled.modelUsed = event.modelUsed;
          assistantMessageToBeFilled.waitingFor = BubbleWaitingForEnum.complete;
          assistantMessageToBeFilled.waitingForLabel = null;

          // Persist tool-call records onto the active swipe so future
          // turns can reason about prior tool work.
          if (event.toolCallRecords.isNotEmpty &&
              assistantMessageToBeFilled.swipes.isNotEmpty) {
            assistantMessageToBeFilled.activeSwipe.toolCalls.addAll(
              event.toolCallRecords,
            );
          }

          if (assistantMessageToBeFilled.content.isNotEmpty) {
            characterFile.appCardTimestampLastChatted =
                DateTime.now().millisecondsSinceEpoch;
            await characterService.saveJsonInCacheNow(characterFile);
          }
        }
      }

      _notify();
      scrollToBottom();
    } on Exception catch (e, stackTrace) {
      if (_cancelToken?.value != true) {
        LoggingService().error('1:1 chat: generateReply failed', e, stackTrace);
        NavigationService().showSnackBar(UtilsLlm.extractUserFriendlyError(e));
      }
    } finally {
      if (assistantMessageToBeFilled.content.isEmpty &&
          bufferedText.isNotEmpty) {
        var finalContent = bufferedText.trimRight();
        if (chatSession.removeTrailingSentences) {
          finalContent = chatService.trimTrailingParagraph(finalContent);
        }
        assistantMessageToBeFilled.content = finalContent;
      }

      if (!_isDisposed) {
        streamingContent.value = assistantMessageToBeFilled.content;
      }

      // Drop the assistant bubble when it has nothing to show — no prose,
      // no media, and no in-flight work. Media-bearing replies (a tool
      // attached an image / video) and still-running bubbles are kept.
      if (chatSession.messages.contains(assistantMessageToBeFilled) &&
          assistantMessageToBeFilled.content.isEmpty &&
          assistantMessageToBeFilled.waitingFor ==
              BubbleWaitingForEnum.complete &&
          assistantMessageToBeFilled.attachedImages.isEmpty &&
          assistantMessageToBeFilled.videoPath == null) {
        if (assistantMessageToBeFilled.swipes.length > 1) {
          assistantMessageToBeFilled.swipes.removeLast();
          assistantMessageToBeFilled.swipeIndex--;
        } else {
          chatSession.messages.remove(assistantMessageToBeFilled);
        }
      } else if (assistantMessageToBeFilled.content.isNotEmpty) {
        assistantMessageToBeFilled.tokenCount ??= await UtilsLlm.countTokens(
          assistantMessageToBeFilled.content,
        );
      }

      unawaited(chatService.updateChat(characterFile, chatSession));

      _cancelToken?.dispose();
      _cancelToken = null;
      isGenerating = false;
      _notify();
    }
  }

  @override
  void stopGeneration() {
    _cancelToken?.value = true;
  }

  @override
  Future<void> deleteMessage(ChatMessage message) async {
    if (isGenerating) {
      stopGeneration();
    }
    chatSession.messages.remove(message);
    await chatService.updateChat(characterFile, chatSession);
    _cleanupAttachedImages(message);
    await textToSpeechService.invalidateOnDelete(
      chatsFolder: chatsFolder,
      chatSession: chatSession,
      message: message,
      settings: settingsService.settings,
      character: resolveCharacterFile(message),
    );
    _notify();
  }

  void _cleanupAttachedImages(ChatMessage message) {
    for (final path in message.attachedImages) {
      unawaited(AppStorage.instance.deleteFile(StorageDomainEnum.cards, path));
      unawaited(
        AppStorage.instance.deleteFile(
          StorageDomainEnum.cards,
          UtilsImage.thumbnailPathFor(path),
        ),
      );
    }
  }

  @override
  Future<void> updateMessage(ChatMessage message, String newContent) async {
    final previousContent = message.content;
    message.content = newContent;
    message.tokenCount = await UtilsLlm.countTokens(newContent);
    await chatService.updateChat(characterFile, chatSession);
    if (previousContent != newContent) {
      await textToSpeechService.invalidateOnEdit(
        chatsFolder: chatsFolder,
        chatSession: chatSession,
        messageTimestamp: message.timestamp,
        previousContent: previousContent,
        settings: settingsService.settings,
        character: resolveCharacterFile(message),
      );
    }
    _notify();
  }

  @override
  Future<void> changeSwipe(ChatMessage message) async {
    message.tokenCount ??= await UtilsLlm.countTokens(message.content);
    await chatService.updateChat(characterFile, chatSession);
    _notify();
  }

  void toggleStreaming() {
    chatSession.isStreaming = !chatSession.isStreaming;
    unawaited(chatService.updateChat(characterFile, chatSession));
    _notify();
  }

  void _notify() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }
}
