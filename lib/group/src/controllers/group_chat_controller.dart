import 'dart:async';

import 'package:cardwave/character/character.dart';
import 'package:cardwave/chat/chat.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/group/src/models/group_data.dart';
import 'package:cardwave/group/src/models/group_file.dart';
import 'package:cardwave/group/src/services/group_chat_service.dart';
import 'package:cardwave/group/src/services/group_file_service.dart';
import 'package:cardwave/group/src/services/group_prompt_service.dart';
import 'package:cardwave/group/src/utils/group_speaker_selection.dart';
import 'package:cardwave/llm_app/llm_app.dart';
import 'package:cardwave/settings/settings.dart';
import 'package:cardwave_llm/cardwave_llm.dart';
import 'package:cardwave_storage/cardwave_storage.dart';
import 'package:flutter/material.dart';

class GroupChatController extends BaseChatViewController
    with ChatVideoGenerationMixin, ChatImageGenerationMixin {
  GroupChatController({
    required GroupFile groupFile,
    required ChatSession session,
    required GroupPromptService groupPromptService,
    required GroupFileService groupFileService,
    required GroupChatService groupChatService,
    required ChatExecutionService executionService,
    required SettingsService settingsService,
    required LlmPureHelpers pureHelpers,
    required PromptRepository promptRepository,
    required CharacterService characterService,
    required TextToSpeechController textToSpeechService,
    required this.imageGenerationService,
    required this.videoGenerationService,
    required this.videoPromptBuilder,
    required this.toolDispatcher,
    required ChatRepository chatRepository,
    required String userName,
  }) : _groupFile = groupFile,
       _session = session,
       _groupPromptService = groupPromptService,
       _groupFileService = groupFileService,
       _groupChatService = groupChatService,
       _executionService = executionService,
       _settingsService = settingsService,
       _llmService = pureHelpers,
       _promptRepository = promptRepository,
       _characterService = characterService,
       _textToSpeechService = textToSpeechService,
       _chatRepository = chatRepository,
       _userName = userName {
    // Ensure groupData is non-null so isGroup is true and tiles that bind to
    // session.groupData work without a null check.
    _session.groupData ??= GroupData();
    scrollController.addListener(_onScroll);
    final providers = _settingsService.settings.providerConfigs;
    validateConfigMediaSession(
      session: _session,
      providers: providers,
      pureHelpers: _llmService,
    );
    for (final member in characters) {
      validateConfigMediaCharacter(
        character: member,
        providers: providers,
        pureHelpers: _llmService,
      );
    }
  }
  final GroupPromptService _groupPromptService;
  final GroupFileService _groupFileService;
  final GroupChatService _groupChatService;
  final ChatExecutionService _executionService;
  final SettingsService _settingsService;
  final LlmPureHelpers _llmService;
  final PromptRepository _promptRepository;
  final CharacterService _characterService;
  final TextToSpeechController _textToSpeechService;
  final ChatRepository _chatRepository;
  @override
  final ToolDispatcher toolDispatcher;
  @override
  final ImageGenerationService imageGenerationService;
  @override
  final VideoGenerationController videoGenerationService;
  @override
  final VideoPromptBuilder videoPromptBuilder;
  final String _userName;

  final GroupFile _groupFile;
  final ChatSession _session;

  bool _isAutoChatActive = false;

  String? _lastSpeakerId;
  bool _userDetached = false;

  @override
  bool get userDetached => _userDetached;

  @override
  final ScrollController scrollController = ScrollController();
  @override
  final TextEditingController inputController = TextEditingController();
  @override
  final FocusNode focusNode = FocusNode();
  @override
  final ValueNotifier<String> streamingContent = ValueNotifier('');

  @override
  String get chatsFolder => GroupChatService.chatsFolderFor(_groupFile.id);

  // --- ChatImageGenerationMixin hooks ---

  @override
  SettingsService get imageGenSettingsService => _settingsService;

  @override
  ChatSession get imageGenSession => _session;

  /// For group chats, the target character is whoever spoke last — or the
  /// first group member if the chat is empty.
  @override
  CharacterFile? get imageGenTargetCharacter {
    final last = lastSpeaker;
    if (last != null) return last;
    final members = characters;
    return members.isNotEmpty ? members.first : null;
  }

  @override
  String get imageGenUserName => _userName;

  @override
  String get imageGenChatDirectoryPath =>
      GroupChatService.chatsFolderFor(_groupFile.id);

  @override
  ChatRepository get imageGenChatRepository => _chatRepository;

  @override
  void imageGenPersistSession() {
    _saveSession();
  }

  // --- ChatVideoGenerationMixin hooks ---

  @override
  LlmPureHelpers get videoGenLlmService => _llmService;

  @override
  SettingsService get videoGenSettingsService => _settingsService;

  @override
  ChatSession get videoGenSession => _session;

  /// For group chats, the target character is whoever spoke last — or the
  /// first group member if the chat is empty. Mirrors [imageGenTargetCharacter].
  @override
  CharacterFile? get videoGenTargetCharacter {
    final last = lastSpeaker;
    if (last != null) return last;
    final members = characters;
    return members.isNotEmpty ? members.first : null;
  }

  @override
  String get videoGenUserName => _userName;

  @override
  void videoGenPersistSession() {
    _saveSession();
  }

  // --- Persistence helpers ---

  /// Saves `_session` + notifies. Used by drawer tiles that mutate session
  /// fields directly (e.g. TTS voice/language) and need a save trigger.
  void persistSession() {
    _saveSession();
    if (isDisposed) return;
    notifyListeners();
  }

  void _saveSession() {
    if (isDisposed) return;
    unawaited(_groupChatService.updateChat(_groupFile.id, _session));
  }

  Future<void> _saveGroupFile() async {
    if (isDisposed) return;
    await _groupFileService.saveGroup(_groupFile);
  }

  // --- Capability flags ---

  @override
  bool get supportsSwipe => true;
  @override
  bool get supportsContinue => true;
  @override
  bool get supportsImproveInput => true;

  @override
  bool get isProcessingInput => isImproving;

  // --- Public accessors ---

  GroupFile get groupFile => _groupFile;

  ChatSession get selectedChat => _session;

  @override
  List<ChatMessage> get messages => List.unmodifiable(_session.messages);

  /// Members resolved from [GroupFile.group.memberAppCardIds] against the
  /// global [CharacterService]. Orphaned ids (characters that no longer
  /// exist) are silently skipped.
  List<CharacterFile> get characters {
    final all = _characterService.characterFiles;
    final resolved = <CharacterFile>[];
    for (final id in _groupFile.group.memberAppCardIds) {
      final match = all.where((c) => c.appCardId == id).firstOrNull;
      if (match != null) resolved.add(match);
    }
    return resolved;
  }

  bool get isAutoChatActive => _isAutoChatActive;

  /// The character who spoke most recently, or null.
  CharacterFile? get lastSpeaker => _lastSpeakerId == null
      ? null
      : characters.where((c) => c.appCardId == _lastSpeakerId).firstOrNull;

  // --- Auto-chat delay (app-wide setting) ---

  Duration get autoChatDelay =>
      Duration(seconds: _settingsService.settings.autoChatDelaySeconds);
  set autoChatDelay(Duration value) {
    _settingsService.settings.autoChatDelaySeconds = value.inSeconds;
    unawaited(_settingsService.saveSettings());
    notifyListeners();
  }

  // --- Chat-session settings (NSFW, scenario, trailing paragraph) ---

  void updateSelectedChatSettings({
    bool? isNsfw,
    bool? isScenario,
    bool? removeTrailingSentences,
    bool? videoNsfwAllowed,
    bool? videoToolSendAllowed,
    bool? videoPromptReview,
  }) {
    if (isDisposed) return;
    if (isNsfw != null) _session.isNsfw = isNsfw;
    if (isScenario != null) _session.isScenario = isScenario;
    if (removeTrailingSentences != null) {
      _session.removeTrailingSentences = removeTrailingSentences;
    }
    final touchesConfigMedia =
        videoNsfwAllowed != null ||
        videoToolSendAllowed != null ||
        videoPromptReview != null;
    if (touchesConfigMedia) {
      final cm = _session.configMedia ??= ConfigMediaSession();
      if (videoNsfwAllowed != null) cm.videoNsfwAllowed = videoNsfwAllowed;
      if (videoToolSendAllowed != null) {
        cm.videoToolSendAllowed = videoToolSendAllowed;
      }
      if (videoPromptReview != null) cm.videoPromptReview = videoPromptReview;
    }
    _saveSession();
    notifyListeners();
  }

  // --- Group overrides ---

  GroupData get groupData => _session.groupData ??= GroupData();

  void updateGroupData({
    String? overrideScenario,
    String? overrideSystemPrompt,
    String? overrideMesExample,
  }) {
    if (isDisposed) return;
    final data = _session.groupData ??= GroupData();
    data.overrideScenario = _normalizeOverride(overrideScenario);
    data.overrideSystemPrompt = _normalizeOverride(overrideSystemPrompt);
    data.overrideMesExample = _normalizeOverride(overrideMesExample);
    _saveSession();
    notifyListeners();
  }

  String? _normalizeOverride(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : value;
  }

  void refresh() {
    if (!isDisposed) notifyListeners();
  }

  // --- Display name / character resolution ---

  /// Group identity resolution requires per-message disambiguation.
  ///
  /// Unlike 1:1, a group session has multiple characters sharing the same
  /// message list, so the role alone cannot tell us *which* character spoke.
  /// Every assistant message produced in this controller is created with
  /// [ChatMessage.characterId] set to the authoring character's `appCardId`
  /// — that id is what we look up here.
  ///
  ///   - [ChatRoleEnum.user] → the user's display name (group flavor doesn't
  ///     currently cache a persona on the session; we hold it on the
  ///     controller as `_userName`).
  ///   - otherwise → look up the character by `message.characterId`. Falls
  ///     back to the raw id string if the character is no longer loaded
  ///     (e.g. removed from the group) so the bubble still renders *something*
  ///     rather than going blank.
  @override
  String resolveDisplayName(ChatMessage message) {
    if (message.role == ChatRoleEnum.user) return _userName;
    final id = message.characterId;
    if (id == null) return _userName;
    final char = characters.where((c) => c.appCardId == id).firstOrNull;
    if (char == null) return id;
    final nickname = char.card.nickname;
    return (nickname != null && nickname.isNotEmpty)
        ? nickname
        : char.card.name;
  }

  /// Look up the character file for a group message by [ChatMessage.characterId].
  /// Returns `null` for user messages or for unknown / unloaded character ids.
  @override
  CharacterFile? resolveCharacterFile(ChatMessage message) {
    if (message.role == ChatRoleEnum.user) return null;
    final id = message.characterId;
    if (id == null) return null;
    return characters.where((c) => c.appCardId == id).firstOrNull;
  }

  // --- Muting ---

  List<String> get _mutedIds => groupData.mutedMemberAppCardIds;

  bool isMuted(String appCardId) => _mutedIds.contains(appCardId);

  void toggleMute(String appCardId) {
    if (isDisposed) return;
    if (_mutedIds.contains(appCardId)) {
      _mutedIds.remove(appCardId);
    } else {
      _mutedIds.add(appCardId);
    }
    _saveSession();
    notifyListeners();
  }

  // --- Member management ---

  void addCharacter(CharacterFile character) {
    if (isDisposed) return;
    if (_groupFile.group.memberAppCardIds.contains(character.appCardId)) return;
    _groupFile.group.memberAppCardIds.add(character.appCardId);
    unawaited(_saveGroupFile());
    notifyListeners();
  }

  void removeCharacter(String appCardId) {
    if (isDisposed) return;
    _groupFile.group.memberAppCardIds.remove(appCardId);
    _mutedIds.remove(appCardId);
    unawaited(_saveGroupFile());
    _saveSession();
    notifyListeners();
  }

  // --- Lifecycle ---

  @override
  void dispose() {
    isDisposed = true;
    stopGeneration();
    // Flush any pending debounced save so nothing is lost on close.
    unawaited(_groupChatService.flushChat(_groupFile.id, _session));
    scrollController.removeListener(_onScroll);
    scrollController.dispose();
    inputController.dispose();
    focusNode.dispose();
    streamingContent.dispose();
    super.dispose();
  }

  // --- Send / auto-chat ---

  @override
  Future<void> sendMessage() async {
    final text = inputController.text.trim();
    if (text.isEmpty || isGenerating) return;

    stopAutoChat();
    _appendMessage(text: text, role: ChatRoleEnum.user, characterId: null);
    inputController.clear();
    scrollToBottom(force: true);
  }

  Future<void> startAutoChat() async {
    if (characters.isEmpty || _isAutoChatActive) return;
    _isAutoChatActive = true;
    notifyListeners();

    while (_isAutoChatActive && !isDisposed) {
      await _generateNextCharacterTurn();
      final delay = autoChatDelay;
      if (_isAutoChatActive && !isDisposed && delay > Duration.zero) {
        await Future.delayed(delay);
      }
    }
  }

  void stopAutoChat() {
    if (_isAutoChatActive) {
      _isAutoChatActive = false;
      stopGeneration();
      notifyListeners();
    }
  }

  @override
  void stopGeneration() {
    cancelToken?.value = true;
  }

  // --- Speaker selection ---

  Future<void> _generateNextCharacterTurn() async {
    if (isGenerating || isDisposed) return;
    final targetCharacter = selectNextSpeaker(
      characters: characters,
      mutedIds: groupData.mutedMemberAppCardIds,
      strategy: _settingsService.settings.groupActivationStrategy,
      lastSpeakerId: _lastSpeakerId,
      sessionMessages: _session.messages,
    );
    if (targetCharacter == null) return;
    await _generateCharacterTurn(targetCharacter);
  }

  Future<void> _generateCharacterTurn(
    CharacterFile targetCharacter, {
    ChatMessage? existingMessage,
    ChatMessage? injectedMessage,
    String contentPrefix = '',
  }) async {
    if (isGenerating || isDisposed) return;

    // First turn: use the character's greeting directly (no LLM call needed).
    if (existingMessage == null && _session.messages.isEmpty) {
      final greeting = _groupPromptService.getInitialGroupGreeting(
        targetCharacter.card,
        userName: _userName,
      );
      _appendMessage(
        text: greeting.trim(),
        role: ChatRoleEnum.character,
        characterId: targetCharacter.appCardId,
      );
      _lastSpeakerId = targetCharacter.appCardId;
      return;
    }

    isGenerating = true;
    streamingContent.value = '';
    cancelToken = ValueNotifier(false);
    notifyListeners();

    try {
      // For regen/continue, exclude the target message from the LLM history;
      // it's the message being (re)generated, not part of the prior context.
      final historyForPrompt = existingMessage != null
          ? _session.messages.where((m) => m != existingMessage).toList()
          : _session.messages.toList();

      // Name-prefix character/assistant messages so the LLM can attribute
      // them when multiple characters share the assistant role (SWAP mode).
      final prefixedHistory = _groupPromptService.buildPrefixedHistory(
        history: historyForPrompt,
        resolveSpeakerName: (id) {
          if (id == null) return _userName;
          return characters
                  .where((c) => c.appCardId == id)
                  .firstOrNull
                  ?.card
                  .name ??
              id;
        },
      );

      final effectiveSpeaker = _groupPromptService.applyGroupOverrides(
        targetCharacter,
        _session.groupData,
      );

      // Per-turn ChatSession copy: inherits all user-facing flags from
      // _session, but swaps in the prefixed history and the speaker's id.
      final executionSession = ChatSession(
        id: _session.id,
        ownerId: targetCharacter.appCardId,
        modelPresetId: _session.modelPresetId,
        configMedia: _session.configMedia,
        created: _session.created,
        lastActive: DateTime.now().millisecondsSinceEpoch,
        name: _session.name,
        isStreaming: _session.isStreaming,
        isNsfw: _session.isNsfw,
        isScenario: _session.isScenario,
        removeTrailingSentences: _session.removeTrailingSentences,
        personaName: _session.personaName,
        personaDescription: _session.personaDescription,
        activeStickies: _session.activeStickies,
        activeCooldowns: _session.activeCooldowns,
        localVariables: _session.localVariables,
        messages: prefixedHistory,
      );

      final replyMessage =
          existingMessage ??
          _appendMessage(
            text: '',
            role: ChatRoleEnum.character,
            characterId: targetCharacter.appCardId,
          );
      replyMessage.waitingFor = BubbleWaitingForEnum.callingLlm;

      // Target-lock for normal turns; continue/regen passes its own injection.
      final effectiveInjected =
          injectedMessage ??
          ChatMessage(
            role: ChatRoleEnum.user,
            swipes: [
              ChatSwipe(
                content:
                    '[Write the next reply only as ${targetCharacter.card.name}.]',
              ),
            ],
            timestamp: DateTime.now().millisecondsSinceEpoch,
          );

      // Group-members line surfaced via dataContext (<supplemental_data_context>).
      final groupMembersLine =
          '[Group members: ${characters.map((c) => c.card.name).join(', ')}]';

      var bufferedText = '';
      var lastUpdateMs = 0;

      final stream = _executionService.generateChatReply(
        executionSession,
        effectiveSpeaker,
        cancelToken: cancelToken!,
        injectedMessage: effectiveInjected,
        dataContext: groupMembersLine,
        dispatchToolCalls: buildToolDispatch(targetMessage: replyMessage),
      );

      List<ChatToolCallRecord> capturedRecords = const [];
      await for (final event in stream) {
        if (isDisposed || cancelToken?.value == true) break;
        if (event is GenerationTokenEvent) {
          bufferedText += event.token;
          replyMessage.waitingFor = BubbleWaitingForEnum.streamingText;
          // Throttle UI paints to ~4 Hz: LLMs can emit dozens of tokens per
          // second and pushing every one into streamingContent / replyMessage
          // hammers the widget tree with rebuilds and jank-induces autoscroll.
          // The final full content is painted once after the loop exits.
          final now = DateTime.now().millisecondsSinceEpoch;
          if (now - lastUpdateMs > 250) {
            streamingContent.value = contentPrefix + bufferedText;
            replyMessage.content = contentPrefix + bufferedText;
            scrollToBottom(animated: false);
            lastUpdateMs = now;
          }
        } else if (event is GenerationTokenWipeEvent) {
          bufferedText = '';
          replyMessage.content = contentPrefix;
          streamingContent.value = contentPrefix;
        } else if (event is GenerationToolLoopProgressEvent) {
          replyMessage.waitingFor = BubbleWaitingForEnum.runningTool;
          replyMessage.waitingForLabel = event.label;
        } else if (event is GenerationCompleteEvent) {
          bufferedText = event.finalContent;
          capturedRecords = event.toolCallRecords;
        }
      }

      final finalContent = (contentPrefix + bufferedText).trim();
      // Drop the empty placeholder only when the model produced neither
      // prose nor a tool side-effect. With tool dispatch happening
      // mid-stream, attached media (image / video) already live on the
      // message before we get here — keep the reply in that case.
      final hasAttachedSideEffect =
          replyMessage.attachedImages.isNotEmpty ||
          replyMessage.imageCaption != null ||
          replyMessage.videoPath != null;
      if (finalContent.isEmpty &&
          !hasAttachedSideEffect &&
          existingMessage == null) {
        _session.messages.remove(replyMessage);
      } else {
        replyMessage.content = finalContent;
        replyMessage.waitingFor = BubbleWaitingForEnum.complete;
        replyMessage.waitingForLabel = null;
        if (capturedRecords.isNotEmpty && replyMessage.swipes.isNotEmpty) {
          replyMessage.activeSwipe.toolCalls.addAll(capturedRecords);
        }
        streamingContent.value = finalContent;
        _lastSpeakerId = targetCharacter.appCardId;
      }
      _saveSession();
    } on Exception catch (e, stackTrace) {
      if (cancelToken?.value != true) {
        LoggingService().error(
          'group chat: generateReplyFor failed',
          e,
          stackTrace,
        );
        NavigationService().showSnackBar(UtilsLlm.extractUserFriendlyError(e));
        stopAutoChat();
      }
    } finally {
      cancelToken?.dispose();
      cancelToken = null;
      isGenerating = false;
      if (!isDisposed) notifyListeners();
    }
  }

  ChatMessage _appendMessage({
    required String text,
    required ChatRoleEnum role,
    required String? characterId,
  }) {
    final message = ChatMessage(
      role: role,
      swipes: [ChatSwipe(content: text)],
      timestamp: DateTime.now().millisecondsSinceEpoch,
      characterId: characterId,
    );
    _session.messages.add(message);
    _saveSession();
    notifyListeners();
    return message;
  }

  // --- BaseChatViewController actions ---

  @override
  Future<void> deleteMessage(ChatMessage message) async {
    if (isGenerating) stopGeneration();
    _session.messages.remove(message);
    _saveSession();
    for (final path in message.attachedImages) {
      unawaited(AppStorage.instance.deleteFile(StorageDomainEnum.cards, path));
      unawaited(
        AppStorage.instance.deleteFile(
          StorageDomainEnum.cards,
          UtilsImage.thumbnailPathFor(path),
        ),
      );
    }
    await _textToSpeechService.invalidateOnDelete(
      chatsFolder: chatsFolder,
      chatSession: _session,
      message: message,
      settings: _settingsService.settings,
      character: resolveCharacterFile(message),
    );
    notifyListeners();
  }

  @override
  Future<void> updateMessage(ChatMessage message, String newContent) async {
    final previousContent = message.content;
    message.content = newContent;
    message.tokenCount = await UtilsLlm.countTokens(newContent);
    _saveSession();
    if (previousContent != newContent) {
      await _textToSpeechService.invalidateOnEdit(
        chatsFolder: chatsFolder,
        chatSession: _session,
        messageTimestamp: message.timestamp,
        previousContent: previousContent,
        settings: _settingsService.settings,
        character: resolveCharacterFile(message),
      );
    }
    notifyListeners();
  }

  @override
  Future<void> regenerateLastMessage() async {
    if (_session.messages.isEmpty || isGenerating) return;
    final last = _session.messages.last;
    if (last.role != ChatRoleEnum.character) return;
    final speaker = resolveCharacterFile(last);
    if (speaker == null) return;
    last.addSwipe('');
    last.tokenCount = null;
    notifyListeners();
    await _generateCharacterTurn(speaker, existingMessage: last);
  }

  @override
  Future<void> changeSwipe(ChatMessage message) async {
    _saveSession();
    notifyListeners();
  }

  @override
  Future<void> continueChat() async {
    if (_session.messages.isEmpty || isGenerating) return;
    final last = _session.messages.last;
    if (last.role != ChatRoleEnum.character) return;
    final speaker = resolveCharacterFile(last);
    if (speaker == null) return;

    final prefix = last.content.endsWith('\n')
        ? last.content
        : '${last.content}\n\n';

    final tempUserMsg = ChatMessage(
      role: ChatRoleEnum.user,
      swipes: [ChatSwipe(content: _promptRepository.continueChat)],
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    await _generateCharacterTurn(
      speaker,
      existingMessage: last,
      injectedMessage: tempUserMsg,
      contentPrefix: prefix,
    );
  }

  @override
  @protected
  String get userName => _userName;

  @override
  @protected
  String get charName => lastSpeaker?.card.name ?? 'the group';

  @override
  @protected
  ChatExecutionService get executionService => _executionService;

  @override
  @protected
  PromptRepository get promptRepository => _promptRepository;

  @override
  @protected
  String get logTag => 'group chat';

  @override
  ChatSession get chatSession => _session;

  void clearChat() {
    if (isDisposed) return;
    stopAutoChat();
    _session.messages.clear();
    _lastSpeakerId = null;
    streamingContent.value = '';
    _saveSession();
    notifyListeners();
  }

  @override
  Future<void> generateReply() async {
    if (isGenerating || characters.isEmpty) return;
    await _generateNextCharacterTurn();
  }


  /// Forces a specific character to speak next, bypassing the random picker.
  Future<void> generateReplyFor(CharacterFile character) async {
    if (isGenerating) return;
    stopAutoChat();
    await _generateCharacterTurn(character);
  }

  @override
  void jumpToBottom() {
    if (scrollController.hasClients) scrollController.jumpTo(0);
  }

  @override
  void scrollToBottom({bool animated = true, bool force = false}) {
    if (isDisposed || !scrollController.hasClients) return;
    if (!force && _userDetached) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isDisposed || !scrollController.hasClients) return;
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
    if (!isDisposed) notifyListeners();
  }
}
