import 'dart:async';
import 'dart:math';

import 'package:cardwave/character/character.dart';
import 'package:cardwave/chat/chat.dart';
import 'package:cardwave/common/common.dart';
import 'package:cardwave/group/src/models/group_activation_strategy_enum.dart';
import 'package:cardwave/group/src/models/group_data.dart';
import 'package:cardwave/group/src/models/group_file.dart';
import 'package:cardwave/group/src/services/group_chat_service.dart';
import 'package:cardwave/group/src/services/group_file_service.dart';
import 'package:cardwave/group/src/services/group_prompt_service.dart';
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
  final Random _random = Random();

  final GroupFile _groupFile;
  final ChatSession _session;

  bool _isAutoChatActive = false;
  bool _isImproving = false;

  @override
  bool isGenerating = false;
  String? _lastSpeakerId;
  bool _isDisposed = false;
  bool _userDetached = false;
  ValueNotifier<bool>? _cancelToken;

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
    if (_isDisposed) return;
    notifyListeners();
  }

  void _saveSession() {
    if (_isDisposed) return;
    unawaited(_groupChatService.updateChat(_groupFile.id, _session));
  }

  Future<void> _saveGroupFile() async {
    if (_isDisposed) return;
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
  bool get isProcessingInput => _isImproving;

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
    if (_isDisposed) return;
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
    if (_isDisposed) return;
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
    if (!_isDisposed) notifyListeners();
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
    if (_isDisposed) return;
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
    if (_isDisposed) return;
    if (_groupFile.group.memberAppCardIds.contains(character.appCardId)) return;
    _groupFile.group.memberAppCardIds.add(character.appCardId);
    unawaited(_saveGroupFile());
    notifyListeners();
  }

  void removeCharacter(String appCardId) {
    if (_isDisposed) return;
    _groupFile.group.memberAppCardIds.remove(appCardId);
    _mutedIds.remove(appCardId);
    unawaited(_saveGroupFile());
    _saveSession();
    notifyListeners();
  }

  // --- Lifecycle ---

  @override
  void dispose() {
    _isDisposed = true;
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

    while (_isAutoChatActive && !_isDisposed) {
      await _generateNextCharacterTurn();
      final delay = autoChatDelay;
      if (_isAutoChatActive && !_isDisposed && delay > Duration.zero) {
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
    _cancelToken?.value = true;
  }

  // --- Speaker selection ---

  /// Picks the next character based on the active activation strategy.
  /// Muted characters are always excluded.
  CharacterFile? _selectNextCharacter() {
    final unmuted = characters
        .where((c) => !_mutedIds.contains(c.appCardId))
        .toList();
    if (unmuted.isEmpty) return null;

    final strategy = _settingsService.settings.groupActivationStrategy;
    switch (strategy) {
      case GroupActivationStrategyEnum.natural:
        final mentioned = _findMentionedCharacter(unmuted);
        if (mentioned != null) return mentioned;
        return _selectWeightedRandom(unmuted);
      case GroupActivationStrategyEnum.list:
        return _selectRoundRobin(unmuted);
      case GroupActivationStrategyEnum.random:
        return _selectWeightedRandom(unmuted);
    }
  }

  /// NATURAL strategy: scans the last 2 messages (from any speaker) for a
  /// candidate's name as a whole word (not substring). The last speaker is
  /// excluded so characters take turns.
  CharacterFile? _findMentionedCharacter(List<CharacterFile> candidates) {
    if (_session.messages.isEmpty) return null;
    final tail = _session.messages.reversed.take(2).toList();
    for (final msg in tail) {
      for (final c in candidates) {
        if (c.appCardId == _lastSpeakerId) continue;
        if (_mentionsName(msg.content, c.card.name)) return c;
      }
    }
    return null;
  }

  /// Whole-word, case-insensitive name match. Avoids false positives where
  /// a short character name ("Al") would match inside an unrelated word
  /// ("Alice", "although").
  bool _mentionsName(String text, String name) {
    if (name.trim().isEmpty) return false;
    final escaped = RegExp.escape(name);
    final pattern = RegExp(
      '(?<![A-Za-z0-9_])$escaped(?![A-Za-z0-9_])',
      caseSensitive: false,
    );
    return pattern.hasMatch(text);
  }

  /// LIST strategy: round-robin in the order characters were added.
  CharacterFile _selectRoundRobin(List<CharacterFile> candidates) {
    // `candidates` is the non-empty unmuted-character list.
    // ignore: qcheck/avoid_unsafe_collection_methods
    if (_lastSpeakerId == null) return candidates.first;
    final lastIdx = candidates.indexWhere((c) => c.appCardId == _lastSpeakerId);
    // ignore: qcheck/avoid_unsafe_collection_methods
    if (lastIdx == -1) return candidates.first;
    return candidates[(lastIdx + 1) % candidates.length];
  }

  /// RANDOM strategy: talkativeness-weighted, excluding the last speaker.
  CharacterFile _selectWeightedRandom(List<CharacterFile> unmuted) {
    final candidates = unmuted.length > 1
        ? unmuted.where((c) => c.appCardId != _lastSpeakerId).toList()
        : unmuted;

    final totalWeight = candidates.fold<double>(
      0,
      (sum, c) => sum + c.card.cardwaveData.talkativeness,
    );
    if (totalWeight <= 0) {
      return candidates[_random.nextInt(candidates.length)];
    }
    var pick = _random.nextDouble() * totalWeight;
    for (final char in candidates) {
      pick -= char.card.cardwaveData.talkativeness;
      if (pick <= 0) return char;
    }
    // `candidates` is non-empty (it derives from the non-empty unmuted list).
    // ignore: qcheck/avoid_unsafe_collection_methods
    return candidates.last;
  }

  Future<void> _generateNextCharacterTurn() async {
    if (isGenerating || _isDisposed) return;
    final targetCharacter = _selectNextCharacter();
    if (targetCharacter == null) return;
    await _generateCharacterTurn(targetCharacter);
  }

  Future<void> _generateCharacterTurn(
    CharacterFile targetCharacter, {
    ChatMessage? existingMessage,
    ChatMessage? injectedMessage,
    String contentPrefix = '',
  }) async {
    if (isGenerating || _isDisposed) return;

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
    _cancelToken = ValueNotifier(false);
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

      // Apply group overrides (scenario / system_prompt / mes_example) to a
      // JSON-cloned copy of the speaker's CharacterFile. Leaves the shared
      // instance untouched. Non-JSON fields like appCardImagePath are
      // restored post-clone because they're excluded from serialization.
      final effectiveSpeaker = _applyGroupOverrides(targetCharacter);

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
        cancelToken: _cancelToken!,
        injectedMessage: effectiveInjected,
        dataContext: groupMembersLine,
        dispatchToolCalls: buildToolDispatch(targetMessage: replyMessage),
      );

      List<ChatToolCallRecord> capturedRecords = const [];
      await for (final event in stream) {
        if (_isDisposed || _cancelToken?.value == true) break;
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
      if (_cancelToken?.value != true) {
        LoggingService().error(
          'group chat: generateReplyFor failed',
          e,
          stackTrace,
        );
        NavigationService().showSnackBar(UtilsLlm.extractUserFriendlyError(e));
        stopAutoChat();
      }
    } finally {
      _cancelToken?.dispose();
      _cancelToken = null;
      isGenerating = false;
      if (!_isDisposed) notifyListeners();
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
  Future<void> improveInput() async {
    final rawInput = inputController.text.trim();
    if (rawInput.isEmpty || _isDisposed || isGenerating) return;

    final userName = _userName;
    final charName = lastSpeaker?.card.name ?? 'the group';

    var prompt = _promptRepository.improveUserMessagePostHistory;
    prompt = prompt.replaceAll('%CURRENT_USER_MESSAGE%', rawInput);
    prompt = prompt.replaceAll('%USER_NAME%', userName);
    prompt = prompt.replaceAll('%CHAR_NAME%', charName);

    final originalInput = rawInput;
    _cancelToken = ValueNotifier(false);
    isGenerating = true;
    _isImproving = true;
    inputController.clear();
    notifyListeners();

    var bufferedText = '';
    var lastUpdateMs = 0;

    try {
      final stream = _executionService.generateUtilityResponseWithHistory(
        _session,
        cancelToken: _cancelToken!,
        systemPrompt: _promptRepository.improveUserMessagePreHistory,
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
        LoggingService().error(
          'group chat: generation stream failed',
          e,
          stackTrace,
        );
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
      _isImproving = false;
      if (!_isDisposed) notifyListeners();
    }
  }

  void clearChat() {
    if (_isDisposed) return;
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

  /// Returns a JSON-cloned copy of [speaker] with the group's override fields
  /// applied to the card when present. The shared instance is not mutated.
  /// Non-serialized fields (e.g. `appCardImagePath`) are restored post-clone.
  CharacterFile _applyGroupOverrides(CharacterFile speaker) {
    final data = _session.groupData;
    if (data == null) return speaker;
    final hasOverride =
        (data.overrideScenario?.trim().isNotEmpty ?? false) ||
        (data.overrideSystemPrompt?.trim().isNotEmpty ?? false) ||
        (data.overrideMesExample?.trim().isNotEmpty ?? false);
    if (!hasOverride) return speaker;

    final clone = CharacterFile.fromJson(speaker.toJson())
      ..appCardImagePath = speaker.appCardImagePath;

    final scenario = data.overrideScenario;
    if (scenario != null && scenario.trim().isNotEmpty) {
      clone.card.scenario = scenario;
    }
    final sysPrompt = data.overrideSystemPrompt;
    if (sysPrompt != null && sysPrompt.trim().isNotEmpty) {
      clone.card.systemPrompt = sysPrompt;
    }
    final mesExample = data.overrideMesExample;
    if (mesExample != null && mesExample.trim().isNotEmpty) {
      clone.card.mesExample = mesExample;
    }
    return clone;
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
    if (!_isDisposed) notifyListeners();
  }
}
